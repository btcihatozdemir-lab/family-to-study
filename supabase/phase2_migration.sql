-- ============================================================================
-- FAZ 2 GÜNCELLEMESİ (PHASE 2 FEATURE PACK MIGRATION SQL)
-- Mevcut tabloları ve verileri silmeden/bozmadan yeni modülleri entegre eder.
-- ============================================================================

-- 1. ENUM GÜNCELLEMELERİ (ALTER TYPE ... ADD VALUE IF NOT EXISTS)
ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'COMPUTER_STUDY';
ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'GUEST_MODE';
ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'FROZEN_HOLIDAY';

ALTER TYPE task_verification_type ADD VALUE IF NOT EXISTS 'qr_scan';
ALTER TYPE task_submission_method ADD VALUE IF NOT EXISTS 'qr_scanned';

ALTER TYPE reward_tier ADD VALUE IF NOT EXISTS 'parent_challenge';

ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'unauthorized_app_opened';
ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'clock_tamper_attempt';

-- 2. YENİ TABLOLAR (CREATE TABLE IF NOT EXISTS)

-- 2.1. family_settings (Ortak Aile Hazine Sandığı & Acil Durum Offline PIN Hash)
CREATE TABLE IF NOT EXISTS public.family_settings (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT UNIQUE NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    family_chest_goal INTEGER NOT NULL DEFAULT 1500 CHECK (family_chest_goal > 0),
    family_chest_current INTEGER NOT NULL DEFAULT 355 CHECK (family_chest_current >= 0),
    family_chest_reward_title TEXT NOT NULL DEFAULT '🎡 Hafta Sonu Ailece Macera Parkı & Bowling Turnuvası!',
    offline_master_pin_hash TEXT DEFAULT '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', -- Varsayılan '123456' SHA-256
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2. qr_stations (Fiziksel QR Kod İstasyonları)
CREATE TABLE IF NOT EXISTS public.qr_stations (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    station_code TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    linked_action TEXT NOT NULL CHECK (linked_action IN ('dismiss_wake_up_alarm', 'start_tooth_brushing', 'complete_task')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3. point_transfers (Kardeşler Arası Puan Hediyeleşmesi)
CREATE TABLE IF NOT EXISTS public.point_transfers (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    sender_child_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_child_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL CHECK (amount > 0),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. MEVCUT TABLOLARA SÜTUN EKLEMELERİ (ALTER TABLE ... ADD COLUMN IF NOT EXISTS)

-- 3.1. users tablosu eklemeleri
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS whitelist_config JSONB NOT NULL DEFAULT '{"allowed_exes": ["chrome.exe", "winword.exe", "powerpnt.exe", "code.exe"], "allowed_keywords": ["eba", "ders", "ödev", "morpa", "bilim", "tonguç", "familytostudy"]}'::jsonb;

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS badges JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 3.2. tasks tablosu eklemeleri
ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS created_by TEXT DEFAULT 'parent-mom';

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS proposal_status TEXT NOT NULL DEFAULT 'approved' CHECK (proposal_status IN ('approved', 'pending_parent_approval', 'rejected'));

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS required_qr_station_id TEXT REFERENCES public.qr_stations(id) ON DELETE SET NULL;

-- 3.3. alarms_and_schedules tablosu eklemeleri
ALTER TABLE public.alarms_and_schedules
    ADD COLUMN IF NOT EXISTS require_qr_station_id TEXT REFERENCES public.qr_stations(id) ON DELETE SET NULL;

-- 4. RLS VE REALTIME PUBLICATION AYARLARI
ALTER TABLE public.family_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transfers ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on family_settings" ON public.family_settings FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on qr_stations" ON public.qr_stations FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on point_transfers" ON public.point_transfers FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['family_settings', 'qr_stations', 'point_transfers']
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        EXCEPTION WHEN duplicate_object THEN
            NULL;
        END;
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', tbl);
    END LOOP;
END $$;

-- 5. YENİ VE GÜNCELLENMİŞ POSTGRESQL RPC FONKSİYONLARI

-- 5.1. get_server_time(): Cihaz saat hilesini (Anti-Cheat) önlemek için doğrudan sunucu saatini döndürür
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT NOW();
$$;

-- 5.2. transfer_points_between_siblings(): Atomik Kardeş Puan Hediyeleşmesi & Altın Kalp Rozeti
CREATE OR REPLACE FUNCTION public.transfer_points_between_siblings(
    sender_id TEXT,
    receiver_id TEXT,
    transfer_amount INTEGER,
    note TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender RECORD;
    v_receiver RECORD;
    v_badges JSONB;
    v_badge_awarded BOOLEAN := false;
    v_golden_heart CONSTANT TEXT := '💛 Altın Kalp Rozeti';
BEGIN
    IF transfer_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Transfer miktarı 0''dan büyük olmalıdır.');
    END IF;

    IF sender_id = receiver_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Kendinize puan transfer edemezsiniz.');
    END IF;

    SELECT * INTO v_sender FROM public.users WHERE id = sender_id FOR UPDATE;
    SELECT * INTO v_receiver FROM public.users WHERE id = receiver_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gönderici veya alıcı kardeş bulunamadı.');
    END IF;

    IF v_sender.points_balance < transfer_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Puan bakiyen bu hediye için yeterli değil.');
    END IF;

    v_badges := COALESCE(v_sender.badges, '[]'::jsonb);
    IF NOT (v_badges @> to_jsonb(v_golden_heart)) THEN
        v_badges := v_badges || to_jsonb(v_golden_heart);
        v_badge_awarded := true;
    END IF;

    -- 1. Gönderenin puanını düş ve rozetini güncelle
    UPDATE public.users
    SET points_balance = points_balance - transfer_amount,
        badges = v_badges,
        updated_at = NOW()
    WHERE id = sender_id;

    -- 2. Alıcı kardeşe puanı ekle
    UPDATE public.users
    SET points_balance = points_balance + transfer_amount,
        updated_at = NOW()
    WHERE id = receiver_id;

    -- 3. point_transfers tablosuna kaydet
    INSERT INTO public.point_transfers (family_id, sender_child_id, receiver_child_id, amount, message)
    VALUES (COALESCE(v_sender.family_id, 'fam-ozdemir'), sender_id, receiver_id, transfer_amount, COALESCE(note, 'Kardeşim için hediye puan! 💛'));

    RETURN jsonb_build_object(
        'success', true,
        'badge_awarded', v_badge_awarded,
        'amount', transfer_amount,
        'updated_badges', v_badges
    );
END;
$$;

-- 5.3. Güncellenmiş approve_task_submission(): Çocuk her puan kazandığında aynı miktarı family_settings.family_chest_current'a da ekler
CREATE OR REPLACE FUNCTION public.approve_task_submission(
    p_submission_id TEXT,
    p_parent_id TEXT,
    p_decision approval_status
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_task RECORD;
    v_morning_remaining INTEGER;
    v_bonus_awarded INTEGER := 0;
    v_total_points INTEGER := 0;
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

    UPDATE public.task_submissions
    SET status = p_decision,
        approved_by = p_parent_id
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

        -- 1. Öğrenciye puanını ekle
        UPDATE public.users
        SET points_balance = points_balance + v_total_points,
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
        'morning_combo_bonus', v_bonus_awarded
    );
END;
$$;

-- 6. FAZ 2 BAŞLANGIÇ VERİLERİ (SEED DATA)
INSERT INTO public.family_settings (id, family_id, family_chest_goal, family_chest_current, family_chest_reward_title, offline_master_pin_hash)
VALUES
    ('fset-ozdemir', 'fam-ozdemir', 1500, 480, '🎡 Hafta Sonu Ailece Macera Parkı & Bowling Turnuvası!', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92'),
    ('fset-yilmaz', 'fam-yilmaz', 1200, 310, '🍕 Pazar Akşamı Sinema & Pizza Şöleni!', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92')
ON CONFLICT (family_id) DO NOTHING;

INSERT INTO public.qr_stations (id, family_id, station_code, title, linked_action)
VALUES
    ('qr-bath-01', 'fam-ozdemir', 'STATION_BATHROOM_01', '🪥 Banyo Aynası QR İstasyonu (Sabah Alarmı & Diş Fırçalama)', 'dismiss_wake_up_alarm'),
    ('qr-desk-01', 'fam-ozdemir', 'STATION_DESK_01', '📚 Çalışma Masası QR İstasyonu (Ödev & Masa Düzeni)', 'complete_task'),
    ('qr-library-01', 'fam-ozdemir', 'STATION_LIBRARY_01', '📖 Kitaplık QR İstasyonu (Akşam Kitap Okuma)', 'complete_task'),
    ('qr-yilmaz-bath', 'fam-yilmaz', 'STATION_YILMAZ_BATH_01', '🪥 Banyo Aynası QR İstasyonu', 'dismiss_wake_up_alarm')
ON CONFLICT (station_code) DO NOTHING;

-- Sabah alarmlarını varsayılan olarak Banyo QR istasyonuna bağla
UPDATE public.alarms_and_schedules
SET require_qr_station_id = 'qr-bath-01'
WHERE family_id = 'fam-ozdemir' AND type = 'wake_up' AND require_qr_station_id IS NULL;

-- Ebeveyne Meydan Okuma (parent_challenge) Ödüllerini Markete Ekle
INSERT INTO public.rewards (id, family_id, title, cost_points, tier, auto_action, icon)
VALUES
    ('rew-challenge-dad-arm', 'fam-ozdemir', '💪 Babamla 15 Dk Bilek Güreşi & Kutu Oyunu Düellosu', 90, 'parent_challenge', NULL, 'Swords'),
    ('rew-challenge-mom-cake', 'fam-ozdemir', '🧁 Annemle Birlikte Çikolatalı Kek & Kurabiye Yapma', 110, 'parent_challenge', NULL, 'Sparkles'),
    ('rew-challenge-family-trivia', 'fam-ozdemir', '🎯 Ebeveynlere Karşı Bilgi Yarışması (Kaybeden Bulaşığı Yıkar!)', 130, 'parent_challenge', NULL, 'Trophy')
ON CONFLICT (id) DO NOTHING;
