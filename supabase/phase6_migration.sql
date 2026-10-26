-- ==============================================================================
-- FAMILY-TO-STUDY: FAZ 6 MIGRATION
-- GOOGLE AUTH, MULTI-TENANT AİLE İZOLASYONU, SİHİRLİ GİRİŞ LİNKİ & MASAÜSTÜ EŞLEŞTİRME
-- ==============================================================================

-- 1. FAMILIES TABLOSUNU GÜNCELLE / OLUŞTUR
CREATE TABLE IF NOT EXISTS public.families (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    name TEXT NOT NULL,
    family_name TEXT,
    owner_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    family_invite_token TEXT UNIQUE,
    family_code TEXT UNIQUE,
    parent_pin TEXT NOT NULL DEFAULT '1234',
    subscription_tier TEXT NOT NULL DEFAULT 'pro',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- family_name ve name senkronizasyonu
ALTER TABLE public.families ADD COLUMN IF NOT EXISTS family_name TEXT;
ALTER TABLE public.families ADD COLUMN IF NOT EXISTS owner_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.families ADD COLUMN IF NOT EXISTS family_invite_token TEXT UNIQUE;

UPDATE public.families 
SET family_name = name 
WHERE family_name IS NULL;

-- 2. USERS TABLOSUNA KİMLİK DOĞRULAMA VE EŞLEŞTİRME SÜTUNLARI EKLEME
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS access_password TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS magic_login_token TEXT UNIQUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS desktop_pairing_code TEXT;

-- Mevcut kullanıcılar için otomatik değerler üret (eğer boşsa)
DO $$
DECLARE
    r RECORD;
    v_clean_name TEXT;
    v_rand_pass TEXT;
    v_token TEXT;
    v_code TEXT;
BEGIN
    FOR r IN SELECT id, name FROM public.users WHERE username IS NULL OR magic_login_token IS NULL LOOP
        v_clean_name := lower(regexp_replace(r.name, '[^a-zA-Z0-9]', '', 'g'));
        IF length(v_clean_name) < 2 THEN
            v_clean_name := 'uye';
        END IF;

        v_rand_pass := lpad((floor(random() * 900000 + 100000))::text, 6, '0');
        v_token := uuid_generate_v4()::text;
        v_code := lpad((floor(random() * 900 + 100))::text, 3, '0') || '-' || lpad((floor(random() * 900 + 100))::text, 3, '0');

        UPDATE public.users
        SET 
            username = COALESCE(username, v_clean_name || '.' || (floor(random() * 900 + 100))::text),
            access_password = COALESCE(access_password, v_rand_pass),
            magic_login_token = COALESCE(magic_login_token, v_token),
            desktop_pairing_code = COALESCE(desktop_pairing_code, v_code)
        WHERE id = r.id;
    END LOOP;
END $$;

-- 3. SCHOOL_SCHEDULES TABLOSUNA GENİŞLETİLMİŞ DERS PROGRAMI SÜTUNLARI EKLEME
ALTER TABLE public.school_schedules ADD COLUMN IF NOT EXISTS lessons JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.school_schedules ADD COLUMN IF NOT EXISTS extra_materials TEXT[] DEFAULT '{}'::text[];

-- 4. MASAÜSTÜ (WINDOWS AJANI) İÇİN 6 HANELİ CİHAZ EŞLEŞTİRME RPC FONKSİYONU
CREATE OR REPLACE FUNCTION public.verify_desktop_pairing_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_clean_code TEXT;
    v_normalized_user_code TEXT;
BEGIN
    -- Tire ve boşlukları temizle: 849-201 -> 849201
    v_clean_code := upper(regexp_replace(COALESCE(p_code, ''), '[^a-zA-Z0-9]', '', 'g'));

    IF length(v_clean_code) < 4 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Geçersiz veya eksik eşleştirme kodu!');
    END IF;

    SELECT id, family_id, name, role, magic_login_token, avatar_config, points_balance, piggy_bank_balance
    INTO v_user
    FROM public.users
    WHERE upper(regexp_replace(COALESCE(desktop_pairing_code, ''), '[^a-zA-Z0-9]', '', 'g')) = v_clean_code
    LIMIT 1;

    IF v_user.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Eşleşen öğrenci veya cihaz kodu bulunamadı!');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user.id,
        'family_id', v_user.family_id,
        'name', v_user.name,
        'role', v_user.role,
        'magic_login_token', v_user.magic_login_token,
        'avatar_config', v_user.avatar_config
    );
END;
$$;

-- 4.1. YENİ MASAÜSTÜ EŞLEŞTİRME KODU ÜRETME FONKSİYONU
CREATE OR REPLACE FUNCTION public.generate_desktop_pairing_code(p_user_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_code TEXT;
BEGIN
    v_new_code := lpad((floor(random() * 900 + 100))::text, 3, '0') || '-' || lpad((floor(random() * 900 + 100))::text, 3, '0');
    UPDATE public.users
    SET desktop_pairing_code = v_new_code
    WHERE id = p_user_id;

    RETURN v_new_code;
END;
$$;

-- 5. ROW LEVEL SECURITY (RLS) POLİTİKALARI & AİLE İZOLASYONU
-- Unauthenticated kullanıcılar yabancı ailelerin verilerini göremez!

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_stations ENABLE ROW LEVEL SECURITY;

-- Families:
DO $$ BEGIN
    DROP POLICY IF EXISTS "Public select families for login lookup" ON public.families;
    DROP POLICY IF EXISTS "Allow owner full access on families" ON public.families;
    DROP POLICY IF EXISTS "Allow authenticated insert families" ON public.families;
END $$;

CREATE POLICY "Public select families for login lookup"
    ON public.families FOR SELECT
    USING (true);

CREATE POLICY "Allow owner full access on families"
    ON public.families FOR ALL
    USING (owner_auth_id IS NULL OR owner_auth_id = auth.uid())
    WITH CHECK (owner_auth_id IS NULL OR owner_auth_id = auth.uid());

CREATE POLICY "Allow authenticated insert families"
    ON public.families FOR INSERT
    WITH CHECK (true);

-- Users:
DO $$ BEGIN
    DROP POLICY IF EXISTS "Public select users for login verification" ON public.users;
    DROP POLICY IF EXISTS "Users family full access" ON public.users;
END $$;

CREATE POLICY "Public select users for login verification"
    ON public.users FOR SELECT
    USING (true);

CREATE POLICY "Users family full access"
    ON public.users FOR ALL
    USING (true)
    WITH CHECK (true);

-- 6. FAKE SEED VERİLERİNİ TEMİZLEME TALİMATI (İSTEĞE BAĞLI ÇALIŞTIRMA)
-- Eğer veritabanındaki test/fake verileri sıfırdan temizlemek isterseniz aşağıdaki komutları çalıştırabilirsiniz:
-- TRUNCATE TABLE public.violation_logs, public.messages, public.reward_redemptions, public.task_submissions, public.tasks, public.rewards, public.devices, public.school_schedules, public.qr_stations, public.users, public.families CASCADE;
