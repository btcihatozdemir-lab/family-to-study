-- ============================================================================
-- FAZ 3 GÜNCELLEMESİ (PHASE 3: HEALTH, SMART CONTEXT, COMPANION & CRISIS PREVENTION)
-- Mevcut Faz 1 ve Faz 2 tablolarını/verilerini silmeden/bozmadan genişletir.
-- ============================================================================

-- 1. ENUM GÜNCELLEMELERİ
ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'high_noise_detected';

-- 2. MEVCUT TABLOLARA SÜTUN EKLEMELERİ (ALTER TABLE ... ADD COLUMN IF NOT EXISTS)

-- 2.1. family_settings tablosu eklemeleri (Hava durumu koordinatları & Gürültü eşiği)
ALTER TABLE public.family_settings
    ADD COLUMN IF NOT EXISTS city_lat DOUBLE PRECISION NOT NULL DEFAULT 41.08,
    ADD COLUMN IF NOT EXISTS city_lon DOUBLE PRECISION NOT NULL DEFAULT 31.12,
    ADD COLUMN IF NOT EXISTS noise_threshold_db INTEGER NOT NULL DEFAULT 75;

-- 2.2. users tablosu eklemeleri (Dijital Yoldaş & Günlük +3 dk Uzatma Jokeri)
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS companion_config JSONB NOT NULL DEFAULT '{"type": "dragon", "name": "Ateş", "xp": 0, "level": 1, "evolution_stage": 1, "hunger": 80, "energy": 100}'::jsonb,
    ADD COLUMN IF NOT EXISTS grace_used_today BOOLEAN NOT NULL DEFAULT false;

-- 2.3. task_submissions tablosu eklemeleri (Başarı Albümü & Ebeveyn Övgü Notu)
ALTER TABLE public.task_submissions
    ADD COLUMN IF NOT EXISTS is_featured_in_album BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS parent_praise_note TEXT;

-- 3. YENİ TABLO: school_schedules (Okul & Kurs Ders Programı ve Akıllı Çanta Asistanı)
CREATE TABLE IF NOT EXISTS public.school_schedules (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    has_pe_class BOOLEAN NOT NULL DEFAULT false,
    has_art_class BOOLEAN NOT NULL DEFAULT false,
    custom_items_to_pack TEXT[] NOT NULL DEFAULT '{}'::text[],
    reminder_note TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, day_of_week)
);

-- 4. RLS VE REALTIME PUBLICATION AYARLARI
ALTER TABLE public.school_schedules ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on school_schedules" ON public.school_schedules FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.school_schedules;
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;
    ALTER TABLE public.school_schedules REPLICA IDENTITY FULL;
END $$;

-- 5. YENİ VE GÜNCELLENMİŞ POSTGRESQL RPC FONKSİYONLARI

-- 5.1. use_grace_period_extension(p_user_id TEXT):
-- Öğrencinin grace_used_today değeri false ise ve en az 10 puanı varsa;
-- puanından 10 düşer, state_ends_at zamanına +3 dakika ekler ve grace_used_today = true yapar.
CREATE OR REPLACE FUNCTION public.use_grace_period_extension(
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_new_ends_at TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_user
    FROM public.users
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Öğrenci bulunamadı.');
    END IF;

    IF v_user.grace_used_today = true THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bugünkü +3 dakika uzatma jokerini zaten kullandın.');
    END IF;

    IF v_user.points_balance < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', '+3 dakika uzatma jokeri için en az 10 puan gereklidir.');
    END IF;

    IF v_user.state_ends_at IS NOT NULL AND v_user.state_ends_at > NOW() THEN
        v_new_ends_at := v_user.state_ends_at + INTERVAL '3 minutes';
    ELSE
        v_new_ends_at := NOW() + INTERVAL '3 minutes';
    END IF;

    UPDATE public.users
    SET points_balance = points_balance - 10,
        grace_used_today = true,
        state_ends_at = v_new_ends_at,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'points_deducted', 10,
        'new_points_balance', v_user.points_balance - 10,
        'new_state_ends_at', v_new_ends_at
    );
END;
$$;

-- 5.2. voluntary_early_lock_refund(p_user_id TEXT):
-- Öğrenci +3 dakikalık uzatma süresi bitmeden kendi rızasıyla "Oyunu Kaydettim, Şimdi Kilitle"
-- butonuna basarsa; kestiği 10 puanı + 5 irade bonusu puanını (toplam +15 puan) iade eder
-- ve cihazı STUDY_TIME kilit moduna alır.
CREATE OR REPLACE FUNCTION public.voluntary_early_lock_refund(
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_lock_ends_at TIMESTAMPTZ := NOW() + INTERVAL '40 minutes';
BEGIN
    SELECT * INTO v_user
    FROM public.users
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Öğrenci bulunamadı.');
    END IF;

    UPDATE public.users
    SET points_balance = points_balance + 15,
        current_state = 'STUDY_TIME',
        state_ends_at = v_lock_ends_at,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- İrade bonusunu ortak aile hazine sandığına da +5 olarak yansıt
    UPDATE public.family_settings
    SET family_chest_current = family_chest_current + 5,
        updated_at = NOW()
    WHERE family_id = COALESCE(v_user.family_id, 'fam-ozdemir');

    RETURN jsonb_build_object(
        'success', true,
        'points_refunded_and_bonus', 15,
        'new_points_balance', v_user.points_balance + 15,
        'new_state', 'STUDY_TIME',
        'state_ends_at', v_lock_ends_at
    );
END;
$$;

-- 5.3. Güncellenmiş approve_task_submission():
-- 1) Atomik tekil onay + Sabah Combo Bonusu (+15 Puan)
-- 2) Ortak Aile Hazine Sandığı (family_chest_current) artışı
-- 3) Faz 3: Dijital Yoldaş (companion_config) XP (+20), hunger = 100, energy = 100 ve her 100 XP'de Level/Evrim artışı!
-- 4) Faz 3: Başarı Albümü (is_featured_in_album & parent_praise_note) kaydı
CREATE OR REPLACE FUNCTION public.approve_task_submission(
    p_submission_id TEXT,
    p_parent_id TEXT,
    p_decision approval_status,
    p_feature_in_album BOOLEAN DEFAULT false,
    p_praise_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_task RECORD;
    v_user RECORD;
    v_morning_remaining INTEGER;
    v_bonus_awarded INTEGER := 0;
    v_total_points INTEGER := 0;
    v_comp JSONB;
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_new_stage INTEGER;
BEGIN
    SELECT * INTO v_sub
    FROM public.task_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Görev gönderimi bulunamadı.');
    END IF;

    IF v_sub.status <> 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Bu görev zaten diğer ebeveyn tarafından işlem gördü.');
    END IF;

    SELECT * INTO v_task FROM public.tasks WHERE id = v_sub.task_id;
    SELECT * INTO v_user FROM public.users WHERE id = v_sub.user_id FOR UPDATE;

    UPDATE public.task_submissions
    SET status = p_decision,
        approved_by = p_parent_id,
        is_featured_in_album = CASE WHEN p_decision = 'approved' THEN COALESCE(p_feature_in_album, is_featured_in_album, false) ELSE false END,
        parent_praise_note = CASE WHEN p_decision = 'approved' THEN COALESCE(p_praise_note, parent_praise_note) ELSE parent_praise_note END
    WHERE id = p_submission_id;

    IF p_decision = 'approved' THEN
        IF v_task.category = 'routine_morning' THEN
            SELECT COUNT(*) INTO v_morning_remaining
            FROM public.tasks t
            WHERE t.family_id = v_sub.family_id
              AND t.category = 'routine_morning'
              AND t.is_active = true
              AND (t.assigned_to = v_sub.user_id OR t.assigned_to = 'both')
              AND NOT EXISTS (
                  SELECT 1 FROM public.task_submissions ts
                  WHERE ts.task_id = t.id
                    AND ts.user_id = v_sub.user_id
                    AND ts.status = 'approved'
                    AND ts.created_at::date = CURRENT_DATE
              );

            IF v_morning_remaining = 0 THEN
                v_bonus_awarded := 15;
            END IF;
        END IF;

        v_total_points := v_task.points + v_bonus_awarded;

        -- Dijital Yoldaş (companion_config) XP, Level ve Evrim Hesaplama
        v_comp := COALESCE(
            v_user.companion_config,
            '{"type": "dragon", "name": "Ateş", "xp": 0, "level": 1, "evolution_stage": 1, "hunger": 80, "energy": 100}'::jsonb
        );
        v_new_xp := COALESCE((v_comp->>'xp')::integer, 0) + 20;
        v_new_level := 1 + (v_new_xp / 100);

        IF v_new_level >= 5 THEN
            v_new_stage := 4; -- Level 5+: Efsanevi Evrim
        ELSIF v_new_level >= 3 THEN
            v_new_stage := 3; -- Level 3-4: Genç
        ELSIF v_new_level >= 2 THEN
            v_new_stage := 2; -- Level 2: Bebek
        ELSE
            v_new_stage := 1; -- Level 1: Yumurta
        END IF;

        v_comp := jsonb_set(v_comp, '{xp}', to_jsonb(v_new_xp), true);
        v_comp := jsonb_set(v_comp, '{level}', to_jsonb(v_new_level), true);
        v_comp := jsonb_set(v_comp, '{evolution_stage}', to_jsonb(v_new_stage), true);
        v_comp := jsonb_set(v_comp, '{hunger}', to_jsonb(100), true);
        v_comp := jsonb_set(v_comp, '{energy}', to_jsonb(100), true);

        -- 1. Öğrenciye puanını ve güncellenmiş Dijital Yoldaş verisini kaydet
        UPDATE public.users
        SET points_balance = points_balance + v_total_points,
            companion_config = v_comp,
            updated_at = NOW()
        WHERE id = v_sub.user_id;

        -- 2. Ortak Aile Hazine Sandığına (family_settings.family_chest_current) aynı miktarı ekle!
        UPDATE public.family_settings
        SET family_chest_current = family_chest_current + v_total_points,
            updated_at = NOW()
        WHERE family_id = COALESCE(v_sub.family_id, 'fam-ozdemir');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'points_added', v_total_points,
        'morning_combo_bonus', v_bonus_awarded,
        'companion_config', v_comp
    );
END;
$$;

-- 6. FAZ 3 BAŞLANGIÇ VERİLERİ (SEED DATA)

-- 6.1. Çocukların Dijital Yoldaşlarını (companion_config) özelleştir
UPDATE public.users
SET companion_config = '{"type": "dragon", "name": "Ateş Kanat", "xp": 140, "level": 2, "evolution_stage": 2, "hunger": 90, "energy": 95}'::jsonb
WHERE id = 'child-omer';

UPDATE public.users
SET companion_config = '{"type": "cat", "name": "Pati Yıldızı", "xp": 220, "level": 3, "evolution_stage": 3, "hunger": 100, "energy": 100}'::jsonb
WHERE id = 'child-elif';

UPDATE public.users
SET companion_config = '{"type": "robot", "name": "Robo-X", "xp": 110, "level": 2, "evolution_stage": 2, "hunger": 85, "energy": 90}'::jsonb
WHERE id = 'child-kaan';

-- 6.2. Haftalık Okul & Kurs Ders Programı (school_schedules) başlangıç verileri
INSERT INTO public.school_schedules (id, family_id, user_id, day_of_week, has_pe_class, has_art_class, custom_items_to_pack, reminder_note)
VALUES
    ('sch-omer-1', 'fam-ozdemir', 'child-omer', 1, true, false, ARRAY['Eşofman Takımı', 'Spor Ayakkabı', 'Suluk'], 'Pazartesi Beden Eğitimi ve Matematik Kursu var!'),
    ('sch-omer-2', 'fam-ozdemir', 'child-omer', 2, false, true, ARRAY['Resim Çantası', 'Pastel Boya', 'Suluk'], 'Salı Görsel Sanatlar dersi var!'),
    ('sch-omer-3', 'fam-ozdemir', 'child-omer', 3, true, false, ARRAY['Eşofman Takımı', 'Suluk', 'Fen Defteri'], 'Çarşamba Beden Eğitimi ve Fen Laboratuvarı!'),
    ('sch-omer-4', 'fam-ozdemir', 'child-omer', 4, false, true, ARRAY['Müzik Defteri', 'Flüt / Melodika', 'Suluk'], 'Perşembe Müzik ve İngilizce Etüt!'),
    ('sch-omer-5', 'fam-ozdemir', 'child-omer', 5, true, true, ARRAY['Eşofman Takımı', 'Resim Çantası', 'Suluk'], 'Cuma Kulüp Etkinliği ve Spor Saati!'),
    ('sch-elif-1', 'fam-ozdemir', 'child-elif', 1, false, true, ARRAY['Resim Çantası', 'Sulu Boya', 'Suluk', 'Beslenme Çantası'], 'Pazartesi Resim ve Oyun Etkinliği!'),
    ('sch-elif-2', 'fam-ozdemir', 'child-elif', 2, true, false, ARRAY['Eşofman Takımı', 'Spor Ayakkabı', 'Suluk'], 'Salı Beden Eğitimi ve Cimnastik!'),
    ('sch-elif-3', 'fam-ozdemir', 'child-elif', 3, false, true, ARRAY['Hikaye Kitabı', 'Boyama Kalemleri', 'Suluk'], 'Çarşamba Masal ve Resim Saati!'),
    ('sch-elif-4', 'fam-ozdemir', 'child-elif', 4, true, false, ARRAY['Eşofman Takımı', 'Suluk', 'Fen Laboratuvar Önlüğü'], 'Perşembe Oyun ve Fiziksel Etkinlikler!'),
    ('sch-elif-5', 'fam-ozdemir', 'child-elif', 5, false, true, ARRAY['Resim Çantası', 'Müzik Defteri', 'Suluk'], 'Cuma Sanat ve Müzik Şenliği!')
ON CONFLICT (user_id, day_of_week) DO NOTHING;

-- 6.3. Örnek Başarı Albümü Kaydı
INSERT INTO public.task_submissions (id, family_id, task_id, user_id, photo_urls, submission_method, status, approved_by, is_featured_in_album, parent_praise_note)
VALUES
    (
        'sub-album-demo-1',
        'fam-ozdemir',
        'task-omer-math-proof',
        'child-omer',
        ARRAY['https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=900&q=80'],
        'photo_uploaded',
        'approved',
        'parent-mom',
        true,
        '🌟 Ömer kesirler konusundaki tüm soruları tertemiz ve adım adım çözmüş, seninle gurur duyuyoruz!'
    ),
    (
        'sub-album-demo-2',
        'fam-ozdemir',
        'task-elif-science-proof',
        'child-elif',
        ARRAY['https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=900&q=80'],
        'photo_uploaded',
        'approved',
        'parent-dad',
        true,
        '💖 Elif bu hafta Fen Bilimleri ve okuma çalışmasını harika tamamladı! Şampiyonumuz!'
    )
ON CONFLICT (id) DO NOTHING;
