-- ============================================================================
-- FAZ 4 GÜNCELLEMESİ (PHASE 4: AUTOPILOT, COURT OF APPEALS, DYNAMIC ECONOMY,
-- TTS ANNOUNCER & WEEKLY AUDIO TIME CAPSULE)
-- Mevcut Faz 1, Faz 2 ve Faz 3 tablolarını/verilerini silmeden/bozmadan genişletir.
-- ============================================================================

-- 1. MEVCUT TABLOLARA SÜTUN EKLEMELERİ (ALTER TABLE ... ADD COLUMN IF NOT EXISTS)

-- 1.1. family_settings tablosuna Faz 4 sütunları:
ALTER TABLE public.family_settings
    ADD COLUMN IF NOT EXISTS autopilot_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS happy_hour_discount_percent INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS happy_hour_ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS tts_announcements_enabled BOOLEAN NOT NULL DEFAULT true;

-- 1.2. users tablosuna Faz 4 sütunu:
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS appeal_used_today BOOLEAN NOT NULL DEFAULT false;

-- 1.3. tasks tablosuna Faz 4 sütunları (Kardeşler Arası "İlk Kapar" Görev Yarışı):
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS is_first_come_race BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS claimed_by TEXT REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

-- 1.4. task_submissions tablosuna Faz 4 sütunu (Otomatik Pilot Ön-Onay):
ALTER TABLE public.task_submissions
    ADD COLUMN IF NOT EXISTS is_optimistic_approved BOOLEAN NOT NULL DEFAULT false;

-- 2. YENİ TABLO: appeals (Adalet Divanı / İtiraz ve Savunma Sistemi)
CREATE TABLE IF NOT EXISTS public.appeals (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    violation_id TEXT REFERENCES public.violation_logs(id) ON DELETE SET NULL,
    submission_id TEXT REFERENCES public.task_submissions(id) ON DELETE SET NULL,
    reason_text TEXT NOT NULL,
    audio_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    reviewed_by TEXT REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. YENİ TABLO: weekly_interviews (Pazar Röportajı & Sesli Anı Kapsülü)
CREATE TABLE IF NOT EXISTS public.weekly_interviews (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    question_text TEXT NOT NULL,
    audio_url TEXT,
    answer_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. RLS VE REALTIME PUBLICATION AYARLARI
ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_interviews ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on appeals" ON public.appeals FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on weekly_interviews" ON public.weekly_interviews FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$
DECLARE
    tbl text;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['appeals', 'weekly_interviews']
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', tbl);
        EXCEPTION WHEN duplicate_object THEN
            NULL;
        END;
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL;', tbl);
    END LOOP;
END $$;

-- 5. FAZ 4 ATOMİK POSTGRESQL RPC FONKSİYONLARI

-- 5.1. claim_race_task_atomic(p_task_id TEXT, p_user_id TEXT):
-- Eğer görev is_first_come_race = true ise ve claimed_by IS NULL ise,
-- görevi anında o öğrenciye kilitler (claimed_by = p_user_id, claimed_at = NOW()).
-- Diğer kardeş milisaniye farkla basarsa "Kardeşin senden önce davrandı!" döner.
CREATE OR REPLACE FUNCTION public.claim_race_task_atomic(
    p_task_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_task RECORD;
    v_claimer_name TEXT;
BEGIN
    SELECT * INTO v_task
    FROM public.tasks
    WHERE id = p_task_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Yarış görevi bulunamadı.');
    END IF;

    IF v_task.is_first_come_race = false THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu görev bir İlk Kapar yarışı değil.');
    END IF;

    IF v_task.claimed_by IS NOT NULL THEN
        IF v_task.claimed_by = p_user_id THEN
            RETURN jsonb_build_object(
                'success', true,
                'already_claimed_by_you', true,
                'message', 'Bu yarış görevini zaten sen kaptın! 15 dakika içinde tamamla!'
            );
        END IF;

        SELECT name INTO v_claimer_name FROM public.users WHERE id = v_task.claimed_by;
        RETURN jsonb_build_object(
            'success', false,
            'error', format('⚡ Kardeşin (%s) senden milisaniyeler önce davrandı ve görevi kaptı!', COALESCE(v_claimer_name, 'Kardeşin'))
        );
    END IF;

    UPDATE public.tasks
    SET claimed_by = p_user_id,
        claimed_at = NOW()
    WHERE id = p_task_id;

    RETURN jsonb_build_object(
        'success', true,
        'claimed_by', p_user_id,
        'claimed_at', NOW(),
        'message', '🏃‍♂️ Harika! Yarış görevini ilk sen kaptın! 15 dakika içinde bitirip ödül puanını kazan!'
    );
END;
$$;

-- 5.2. resolve_appeal(p_appeal_id TEXT, p_parent_id TEXT, p_decision TEXT):
-- Ebeveyn 'accepted' derse öğrencinin kırılan kalkanını geri verir (daily_shields = LEAST(daily_shields + 1, 3))
-- veya reddedilen görev itirazıysa görevi onaylar, itiraz durumunu günceller.
CREATE OR REPLACE FUNCTION public.resolve_appeal(
    p_appeal_id TEXT,
    p_parent_id TEXT,
    p_decision TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_appeal RECORD;
    v_user RECORD;
    v_new_shields INTEGER;
BEGIN
    IF p_decision NOT IN ('accepted', 'rejected') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Geçersiz karar türü.');
    END IF;

    SELECT * INTO v_appeal
    FROM public.appeals
    WHERE id = p_appeal_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'İtiraz kaydı bulunamadı.');
    END IF;

    IF v_appeal.status <> 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu itiraz zaten sonuçlandırılmış.');
    END IF;

    SELECT * INTO v_user
    FROM public.users
    WHERE id = v_appeal.user_id
    FOR UPDATE;

    UPDATE public.appeals
    SET status = p_decision,
        reviewed_by = p_parent_id
    WHERE id = p_appeal_id;

    v_new_shields := COALESCE(v_user.daily_shields, 3);

    IF p_decision = 'accepted' THEN
        v_new_shields := LEAST(COALESCE(v_user.daily_shields, 0) + 1, 3);
        UPDATE public.users
        SET daily_shields = v_new_shields,
            updated_at = NOW()
        WHERE id = v_appeal.user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'decision', p_decision,
        'user_id', v_appeal.user_id,
        'new_daily_shields', v_new_shields
    );
END;
$$;

-- 5.3. submit_task_with_autopilot_check():
-- Görev gönderildiğinde eğer family_settings.autopilot_until > NOW() ise,
-- görevi status = 'approved', is_optimistic_approved = true olarak işaretler
-- ve puanı + Dijital Yoldaş XP'sini öğrenciye bekletmeden tanımlar.
CREATE OR REPLACE FUNCTION public.submit_task_with_autopilot_check(
    p_submission_id TEXT,
    p_family_id TEXT,
    p_task_id TEXT,
    p_user_id TEXT,
    p_submission_method task_submission_method,
    p_photo_urls TEXT[] DEFAULT '{}'::text[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settings RECORD;
    v_task RECORD;
    v_user RECORD;
    v_is_autopilot BOOLEAN := false;
    v_status approval_status := 'pending';
    v_comp JSONB;
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_new_stage INTEGER;
BEGIN
    SELECT * INTO v_settings
    FROM public.family_settings
    WHERE family_id = p_family_id
    LIMIT 1;

    SELECT * INTO v_task FROM public.tasks WHERE id = p_task_id;
    SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Öğrenci veya görev bulunamadı.');
    END IF;

    IF v_settings.autopilot_until IS NOT NULL AND v_settings.autopilot_until > NOW() THEN
        v_is_autopilot := true;
        v_status := 'approved';
    END IF;

    INSERT INTO public.task_submissions (
        id,
        family_id,
        task_id,
        user_id,
        submission_method,
        status,
        photo_urls,
        approved_by,
        is_optimistic_approved,
        created_at
    ) VALUES (
        p_submission_id,
        p_family_id,
        p_task_id,
        p_user_id,
        p_submission_method,
        v_status,
        COALESCE(p_photo_urls, '{}'::text[]),
        CASE WHEN v_is_autopilot THEN 'autopilot-trust' ELSE NULL END,
        v_is_autopilot,
        NOW()
    );

    IF v_is_autopilot THEN
        v_comp := COALESCE(
            v_user.companion_config,
            '{"type": "dragon", "name": "Ateş", "xp": 0, "level": 1, "evolution_stage": 1, "hunger": 80, "energy": 100}'::jsonb
        );
        v_new_xp := COALESCE((v_comp->>'xp')::integer, 0) + 20;
        v_new_level := 1 + (v_new_xp / 100);
        IF v_new_level >= 5 THEN
            v_new_stage := 4;
        ELSIF v_new_level >= 3 THEN
            v_new_stage := 3;
        ELSIF v_new_level >= 2 THEN
            v_new_stage := 2;
        ELSE
            v_new_stage := 1;
        END IF;

        v_comp := jsonb_set(v_comp, '{xp}', to_jsonb(v_new_xp), true);
        v_comp := jsonb_set(v_comp, '{level}', to_jsonb(v_new_level), true);
        v_comp := jsonb_set(v_comp, '{evolution_stage}', to_jsonb(v_new_stage), true);
        v_comp := jsonb_set(v_comp, '{hunger}', to_jsonb(100), true);
        v_comp := jsonb_set(v_comp, '{energy}', to_jsonb(100), true);

        UPDATE public.users
        SET points_balance = points_balance + COALESCE(v_task.points, 30),
            companion_config = v_comp,
            updated_at = NOW()
        WHERE id = p_user_id;

        UPDATE public.family_settings
        SET family_chest_current = family_chest_current + COALESCE(v_task.points, 30),
            updated_at = NOW()
        WHERE family_id = p_family_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_optimistic_approved', v_is_autopilot,
        'status', v_status,
        'points_awarded', CASE WHEN v_is_autopilot THEN COALESCE(v_task.points, 30) ELSE 0 END
    );
END;
$$;

-- 5.4. revert_optimistic_approval(p_submission_id TEXT):
-- Ebeveyn akşam kontrolünde ön-onaylı görevi hileli/eksik bulursa verilen puanı geri çeker
-- ve görevi 'rejected' durumuna alır.
CREATE OR REPLACE FUNCTION public.revert_optimistic_approval(
    p_submission_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_task RECORD;
    v_deduct INTEGER;
BEGIN
    SELECT * INTO v_sub
    FROM public.task_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Görev gönderimi bulunamadı.');
    END IF;

    IF v_sub.is_optimistic_approved = false OR v_sub.status <> 'approved' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu görev otomatik pilot ön-onaylı durumda değil.');
    END IF;

    SELECT * INTO v_task FROM public.tasks WHERE id = v_sub.task_id;
    v_deduct := COALESCE(v_task.points, 30);

    UPDATE public.task_submissions
    SET status = 'rejected',
        is_optimistic_approved = false
    WHERE id = p_submission_id;

    UPDATE public.users
    SET points_balance = GREATEST(0, points_balance - v_deduct),
        updated_at = NOW()
    WHERE id = v_sub.user_id;

    UPDATE public.family_settings
    SET family_chest_current = GREATEST(0, family_chest_current - v_deduct),
        updated_at = NOW()
    WHERE family_id = COALESCE(v_sub.family_id, 'fam-ozdemir');

    RETURN jsonb_build_object(
        'success', true,
        'points_reverted', v_deduct,
        'user_id', v_sub.user_id
    );
END;
$$;

-- 6. FAZ 4 BAŞLANGIÇ VERİLERİ (SEED DATA)

-- 6.1. Örnek bir "İlk Kapar" (is_first_come_race) kardeş yarış görevi:
INSERT INTO public.tasks (
    id, family_id, assigned_to, title, description, category, points,
    verification_type, requires_photo, duration_minutes, is_active, due_time,
    proposal_status, is_first_come_race, claimed_by, claimed_at
) VALUES (
    'task-race-livingroom-01',
    'fam-ozdemir',
    'both',
    '⚡ İlk Kapar Yarışı: Salondaki Kitaplığı ve Sehpayı Düzenle!',
    'Kardeşlerden ilk "🏃‍♂️ Ben Yaparım!" butonuna basan bu görevi kapar ve 15 dakika içinde bitirirse +55 Altın Puan kazanır!',
    'flash_quest',
    55,
    'photo_optional',
    true,
    15,
    true,
    '20:30',
    'approved',
    true,
    NULL,
    NULL
) ON CONFLICT (id) DO NOTHING;

-- 6.2. Örnek Pazar Röportajı & Sesli Anı Kapsülü (weekly_interviews) kaydı:
INSERT INTO public.weekly_interviews (
    id, family_id, user_id, week_start_date, question_text, audio_url, answer_note
) VALUES (
    'wi-omer-seed-01',
    'fam-ozdemir',
    'child-omer',
    CURRENT_DATE - INTERVAL '7 days',
    'Bu hafta başardığın en zor şey neydi ve nasıl üstesinden geldin?',
    NULL,
    'Kesirlerle bölme işlemini ilk başta karıştırıyordum ama babamla kağıt üzerinde şekil çizerek çalıştık ve sınavdan 95 aldım!'
), (
    'wi-elif-seed-01',
    'fam-ozdemir',
    'child-elif',
    CURRENT_DATE - INTERVAL '7 days',
    'Bu hafta seni en çok ne güldürdü?',
    NULL,
    'Sabah alarmı çalınca abimle banyodaki QR kodu okutmak için yarışırken ikimizin de terlikleri karıştı, çok güldük!'
) ON CONFLICT (id) DO NOTHING;
