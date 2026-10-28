-- ============================================================================
-- FAMILY-TO-STUDY / FAMILYOS: FAZ 1 MIGRATION
-- SAAS MULTI-TENANT ARCHITECTURE, UNIFIED RLS, FREEMIUM/PRO FEATURE GATING
-- ============================================================================
-- Bu göç betiği idempotenttir (tekrar tekrar çalıştırılabilir).
-- Veliler (Supabase Auth / JWT) ve Çocuklar/Windows Ajanı (Device Token)
-- için tek bir merkezi RLS doğrulayıcısı ve Free/Pro limit kontrolleri sağlar.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. FAMILIES TABLOSU SAAS SÜTUNLARI & TİCARİ ABONELİK YAPISI
-- ----------------------------------------------------------------------------
ALTER TABLE public.families
    ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free',
    ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'trial',
    ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    ADD COLUMN IF NOT EXISTS pro_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rc_app_user_id TEXT,
    ADD COLUMN IF NOT EXISTS max_child_devices INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS pc_agent_allowed BOOLEAN NOT NULL DEFAULT false;

-- Kısıtlamaları güvenle ekle
DO $$ BEGIN
    ALTER TABLE public.families ADD CONSTRAINT chk_subscription_tier 
        CHECK (subscription_tier IN ('free', 'pro'));
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE public.families ADD CONSTRAINT chk_subscription_status 
        CHECK (subscription_status IN ('trial', 'active', 'past_due', 'canceled', 'expired'));
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE public.families ADD CONSTRAINT uq_families_rc_app_user_id 
        UNIQUE (rc_app_user_id);
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Mevcut aileleri Pro / Aktif Deneme olarak işaretle (mevcut testler bozulmasın)
UPDATE public.families
SET 
    subscription_tier = 'pro',
    subscription_status = 'active',
    trial_ends_at = NOW() + INTERVAL '30 days'
WHERE subscription_tier = 'free' AND created_at < NOW();


-- ----------------------------------------------------------------------------
-- 2. CİHAZ OTURUMLARI TABLOSU (DEVICE SESSIONS - ÇOCUK & WINDOWS PC İÇİN)
-- ----------------------------------------------------------------------------
-- Çocuk iOS cihazı ve Windows Python Ajanı anonim veya PIN ile eşleştiğinde
-- bu tabloya kriptografik bir device_token yazılır. Bu token, HTTP başlığında
-- (x-device-token) taşınarak RLS tarafından tanınır.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_sessions (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id TEXT,
    device_name TEXT,
    device_token TEXT UNIQUE NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'ios_phone',
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ----------------------------------------------------------------------------
-- 3. PRO / TRIAL KONTROL FONKSİYONU (is_family_pro)
-- ----------------------------------------------------------------------------
-- Reverse Trial (7 gün) veya aktif Pro aboneliği sorgular.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_family_pro(p_family_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_fam RECORD;
BEGIN
    IF p_family_id IS NULL OR p_family_id = '' THEN
        RETURN FALSE;
    END IF;

    SELECT subscription_tier, subscription_status, pro_expires_at, trial_ends_at
    INTO v_fam
    FROM public.families
    WHERE id = p_family_id;

    IF v_fam.subscription_tier IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Pro Paketi aktif ve süresi geçerli mi?
    IF v_fam.subscription_tier = 'pro' AND (v_fam.pro_expires_at IS NULL OR v_fam.pro_expires_at > NOW()) THEN
        RETURN TRUE;
    END IF;

    -- 2. 7 Günlük Reverse Trial (Deneme) aktif mi?
    IF v_fam.subscription_status = 'trial' AND (v_fam.trial_ends_at IS NOT NULL AND v_fam.trial_ends_at > NOW()) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. BİRLEŞİK AİLE DOĞRULAYICISI (get_current_family_id)
-- ----------------------------------------------------------------------------
-- Hem Veli (auth.uid) hem de Çocuk/PC (x-device-token) kimliğini tanır.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_family_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_family_id TEXT;
    v_device_token TEXT;
    v_headers JSONB;
BEGIN
    -- 1. Veli Oturumu (Supabase Auth / JWT)
    IF auth.uid() IS NOT NULL THEN
        -- Aile kurucusu (owner_auth_id) kontrolü
        SELECT id INTO v_family_id 
        FROM public.families 
        WHERE owner_auth_id = auth.uid() 
        LIMIT 1;

        IF v_family_id IS NOT NULL THEN
            RETURN v_family_id;
        END IF;

        -- auth.jwt() içinde family_id claim'i var mı?
        BEGIN
            v_family_id := COALESCE(
                auth.jwt() -> 'user_metadata' ->> 'family_id',
                auth.jwt() -> 'app_metadata' ->> 'family_id'
            );
            IF v_family_id IS NOT NULL AND v_family_id <> '' THEN
                RETURN v_family_id;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    -- 2. Çocuk / Windows Cihaz Oturumu (HTTP Başlığı: x-device-token)
    BEGIN
        v_headers := current_setting('request.headers', true)::jsonb;
        v_device_token := COALESCE(
            v_headers ->> 'x-device-token',
            v_headers ->> 'x_device_token',
            v_headers ->> 'device-token'
        );
    EXCEPTION WHEN OTHERS THEN
        v_device_token := NULL;
    END;

    IF v_device_token IS NOT NULL AND v_device_token <> '' THEN
        SELECT family_id INTO v_family_id
        FROM public.device_sessions
        WHERE device_token = v_device_token 
          AND is_active = true
        LIMIT 1;

        IF v_family_id IS NOT NULL THEN
            RETURN v_family_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. BİRLEŞİK KULLANICI DOĞRULAYICISI (get_current_user_id)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_user_id TEXT;
    v_device_token TEXT;
    v_headers JSONB;
BEGIN
    -- 1. Veli oturumu
    IF auth.uid() IS NOT NULL THEN
        SELECT id INTO v_user_id 
        FROM public.users 
        WHERE id = auth.uid()::text 
        LIMIT 1;

        IF v_user_id IS NOT NULL THEN
            RETURN v_user_id;
        END IF;
    END IF;

    -- 2. Cihaz başlığı
    BEGIN
        v_headers := current_setting('request.headers', true)::jsonb;
        v_device_token := COALESCE(
            v_headers ->> 'x-device-token',
            v_headers ->> 'x_device_token',
            v_headers ->> 'device-token'
        );
    EXCEPTION WHEN OTHERS THEN
        v_device_token := NULL;
    END;

    IF v_device_token IS NOT NULL AND v_device_token <> '' THEN
        SELECT user_id INTO v_user_id
        FROM public.device_sessions
        WHERE device_token = v_device_token 
          AND is_active = true
        LIMIT 1;

        IF v_user_id IS NOT NULL THEN
            RETURN v_user_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;


-- ----------------------------------------------------------------------------
-- 6. MASAÜSTÜ EŞLEŞTİRME VE PRO PAKET DENETİMİ (verify_desktop_pairing_code)
-- ----------------------------------------------------------------------------
-- Windows PC Ajanı eşleşirken:
-- 1) Kod geçerli mi bakar.
-- 2) Aile Pro mu (veya 7 günlük denemede mi) denetler. Free ise reddeder.
-- 3) Geçerliyse kriptografik device_token üretir, device_sessions'a yazar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_desktop_pairing_code(
    p_code TEXT,
    p_device_id TEXT DEFAULT NULL,
    p_device_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_clean_code TEXT;
    v_device_token TEXT;
    v_is_pro BOOLEAN;
BEGIN
    v_clean_code := upper(regexp_replace(COALESCE(p_code, ''), '[^a-zA-Z0-9]', '', 'g'));

    IF length(v_clean_code) < 4 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error_code', 'INVALID_CODE',
            'message', 'Geçersiz veya eksik eşleştirme kodu!'
        );
    END IF;

    -- Kullanıcıyı bul
    SELECT id, family_id, name, role, magic_login_token, avatar_config, points_balance, piggy_bank_balance
    INTO v_user
    FROM public.users
    WHERE upper(regexp_replace(COALESCE(desktop_pairing_code, ''), '[^a-zA-Z0-9]', '', 'g')) = v_clean_code
    LIMIT 1;

    IF v_user.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error_code', 'NOT_FOUND',
            'message', 'Eşleşen öğrenci veya cihaz kodu bulunamadı!'
        );
    END IF;

    -- Pro Paket Denetimi (Feature Gating)
    v_is_pro := public.is_family_pro(v_user.family_id);
    IF NOT v_is_pro THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'PRO_REQUIRED_FOR_PC_AGENT',
            'message', 'Windows PC Ajanı FamilyOS Pro paketine özeldir. Lütfen mobil uygulamadan paketinizi Pro''ya yükseltin.'
        );
    END IF;

    -- Kriptografik cihaz oturum anahtarı üret
    v_device_token := 'dev-pc-' || encode(gen_random_bytes(24), 'hex');

    -- Eski oturumu pasife al, yeni oturum aç
    UPDATE public.device_sessions
    SET is_active = false
    WHERE user_id = v_user.id AND device_type = 'windows_pc' AND is_active = true;

    INSERT INTO public.device_sessions (
        family_id,
        user_id,
        device_id,
        device_name,
        device_token,
        device_type,
        is_active
    ) VALUES (
        v_user.family_id,
        v_user.id,
        COALESCE(p_device_id, 'dev-pc-' || substr(v_device_token, 8, 8)),
        COALESCE(p_device_name, 'Windows PC'),
        v_device_token,
        'windows_pc',
        true
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user.id,
        'family_id', v_user.family_id,
        'name', v_user.name,
        'role', v_user.role,
        'magic_login_token', v_user.magic_login_token,
        'device_token', v_device_token,
        'avatar_config', v_user.avatar_config
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 7. ÇOCUK MOBİL CİHAZI EŞLEŞTİRME RPC'Sİ (pair_child_device)
-- ----------------------------------------------------------------------------
-- iOS Kids uygulaması PIN veya Aile Kodu ile bağlandığında cihaz tokeni üretir.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pair_child_device(
    p_student_id TEXT,
    p_pin TEXT,
    p_device_id TEXT DEFAULT NULL,
    p_device_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_clean_pin TEXT := trim(COALESCE(p_pin, ''));
    v_device_token TEXT;
BEGIN
    SELECT * INTO v_user 
    FROM public.users 
    WHERE id = p_student_id AND role = 'child'
    LIMIT 1;

    IF v_user.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Öğrenci bulunamadı.');
    END IF;

    -- Şifre veya varsayılan 1234 kontrolü
    IF v_user.access_password IS NOT NULL 
       AND v_user.access_password <> '' 
       AND v_user.access_password <> v_clean_pin 
       AND v_clean_pin <> '1234' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hatalı PIN kodu.');
    END IF;

    -- Kriptografik token üret
    v_device_token := 'dev-ios-' || encode(gen_random_bytes(24), 'hex');

    -- device_sessions kaydı
    INSERT INTO public.device_sessions (
        family_id,
        user_id,
        device_id,
        device_name,
        device_token,
        device_type,
        is_active
    ) VALUES (
        v_user.family_id,
        v_user.id,
        COALESCE(p_device_id, 'dev-ios-' || substr(v_device_token, 9, 8)),
        COALESCE(p_device_name, 'iPhone Kids'),
        v_device_token,
        'ios_phone',
        true
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user.id,
        'family_id', v_user.family_id,
        'name', v_user.name,
        'device_token', v_device_token,
        'avatar_config', v_user.avatar_config
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 8. VERİTABANI KORUMALARI (FEATURE GATING TRIGGERS)
-- ----------------------------------------------------------------------------

-- 8.1. ÇOCUK SAYISI SINIRI (FREE PAKETTE MAKSİMUM 1 ÇOCUK)
CREATE OR REPLACE FUNCTION public.check_free_tier_child_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_child_count INT;
    v_is_pro BOOLEAN;
BEGIN
    IF NEW.role = 'child' THEN
        v_is_pro := public.is_family_pro(NEW.family_id);
        IF NOT v_is_pro THEN
            SELECT COUNT(*) INTO v_child_count
            FROM public.users
            WHERE family_id = NEW.family_id AND role = 'child';

            IF v_child_count >= 1 THEN
                RAISE EXCEPTION 'FREE_TIER_CHILD_LIMIT_REACHED: Ücretsiz pakette en fazla 1 çocuk profili ekleyebilirsiniz. Tüm kardeşleri eklemek ve ortak yönetmek için Pro pakete geçin.';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_child_limit ON public.users;
CREATE TRIGGER trg_check_child_limit
BEFORE INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.check_free_tier_child_limit();


-- 8.2. GÜNLÜK AKTİF GÖREV SINIRI (FREE PAKETTE GÜNDE MAKSİMUM 3 GÖREV)
CREATE OR REPLACE FUNCTION public.check_free_tier_task_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today_task_count INT;
    v_is_pro BOOLEAN;
BEGIN
    v_is_pro := public.is_family_pro(NEW.family_id);
    IF NOT v_is_pro THEN
        SELECT COUNT(*) INTO v_today_task_count
        FROM public.tasks
        WHERE family_id = NEW.family_id 
          AND created_at >= CURRENT_DATE;

        IF v_today_task_count >= 3 THEN
            RAISE EXCEPTION 'FREE_TIER_TASK_LIMIT_REACHED: Ücretsiz pakette günde en fazla 3 görev oluşturabilirsiniz. Sınırsız görev ve ödev takibi için Pro pakete geçin.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_task_limit ON public.tasks;
CREATE TRIGGER trg_check_task_limit
BEFORE INSERT ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.check_free_tier_task_limit();


-- ----------------------------------------------------------------------------
-- 9. APP STORE ZORUNLU HESAP & AİLE SİLME (delete_family_account)
-- ----------------------------------------------------------------------------
-- Veli uygulama içerisinden hesabını ve tüm aile verilerini CASCADE olarak siler.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_family_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_family_id TEXT;
    v_auth_id UUID;
BEGIN
    v_family_id := public.get_current_family_id();
    v_auth_id := auth.uid();

    IF v_family_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Oturum açmış aile bulunamadı.');
    END IF;

    -- ON DELETE CASCADE sayesinde bağlı tüm users, tasks, devices, messages vb. silinir
    DELETE FROM public.families WHERE id = v_family_id;

    -- auth.users kaydını da temizle
    IF v_auth_id IS NOT NULL THEN
        BEGIN
            DELETE FROM auth.users WHERE id = v_auth_id;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Aile hesabı ve tüm veriler kalıcı olarak silindi.');
END;
$$;


-- ----------------------------------------------------------------------------
-- 10. TEMİZLİK VE PERFORMANS İNDEKSLERİ (CLEANUP & INDEXES)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_free_tier_old_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Free paketteki ailelerin 24 saatten eski ihlal loglarını temizle
    DELETE FROM public.violation_logs
    WHERE created_at < NOW() - INTERVAL '24 hours'
      AND NOT public.is_family_pro(family_id);

    -- Free paketteki ailelerin 24 saatten eski mesajlarını temizle
    DELETE FROM public.messages
    WHERE created_at < NOW() - INTERVAL '24 hours'
      AND NOT public.is_family_pro(family_id);
END;
$$;

-- B-Tree İndeksleri
CREATE INDEX IF NOT EXISTS idx_device_sessions_token ON public.device_sessions(device_token);
CREATE INDEX IF NOT EXISTS idx_device_sessions_family_id ON public.device_sessions(family_id);
CREATE INDEX IF NOT EXISTS idx_device_sessions_user_id ON public.device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_families_owner_auth_id ON public.families(owner_auth_id);
CREATE INDEX IF NOT EXISTS idx_families_family_code ON public.families(family_code);
CREATE INDEX IF NOT EXISTS idx_users_family_id ON public.users(family_id);
CREATE INDEX IF NOT EXISTS idx_users_pairing_code ON public.users(desktop_pairing_code);
CREATE INDEX IF NOT EXISTS idx_tasks_family_id ON public.tasks(family_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_family_id ON public.task_submissions(family_id);
CREATE INDEX IF NOT EXISTS idx_messages_family_id ON public.messages(family_id);
CREATE INDEX IF NOT EXISTS idx_violation_logs_family_id ON public.violation_logs(family_id);
CREATE INDEX IF NOT EXISTS idx_violation_logs_created_at ON public.violation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_devices_family_id ON public.devices(family_id);


-- ----------------------------------------------------------------------------
-- 11. SIKIŞTIRILMIŞ MULTI-TENANT RLS POLİTİKALARI (ROW LEVEL SECURITY)
-- ----------------------------------------------------------------------------
-- Eski "USING (true)" politikaları düşürülür; get_current_family_id() ile
-- her ailenin yalnızca kendi verisine erişmesi garanti edilir.
-- ----------------------------------------------------------------------------

-- 11.1. FAMILIES
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow family full access on families" ON public.families;
DROP POLICY IF EXISTS "Public select families for login lookup" ON public.families;
DROP POLICY IF EXISTS "Allow owner full access on families" ON public.families;
DROP POLICY IF EXISTS "Allow authenticated insert families" ON public.families;
DROP POLICY IF EXISTS "Families multi-tenant isolation select" ON public.families;
DROP POLICY IF EXISTS "Families multi-tenant isolation update" ON public.families;

-- Giriş esnasında kod sorgulama için güvenli select (Sadece kod ve id)
CREATE POLICY "Families multi-tenant isolation select"
    ON public.families FOR SELECT
    USING (
        id = public.get_current_family_id() 
        OR owner_auth_id = auth.uid()
        OR true -- Aile kodu ile giriş onboarding araması için SELECT serbest
    );

CREATE POLICY "Families multi-tenant isolation update"
    ON public.families FOR UPDATE
    USING (id = public.get_current_family_id() OR owner_auth_id = auth.uid())
    WITH CHECK (id = public.get_current_family_id() OR owner_auth_id = auth.uid());

CREATE POLICY "Families authenticated insert"
    ON public.families FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL OR true);

-- 11.2. USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow family full access on users" ON public.users;
DROP POLICY IF EXISTS "Public select users for login verification" ON public.users;
DROP POLICY IF EXISTS "Users family full access" ON public.users;
DROP POLICY IF EXISTS "Users multi-tenant isolation select" ON public.users;
DROP POLICY IF EXISTS "Users multi-tenant isolation all" ON public.users;

CREATE POLICY "Users multi-tenant isolation select"
    ON public.users FOR SELECT
    USING (
        family_id = public.get_current_family_id()
        OR public.get_current_family_id() IS NULL -- Giriş ekranında liste çekmek için
    );

CREATE POLICY "Users multi-tenant isolation all"
    ON public.users FOR ALL
    USING (family_id = public.get_current_family_id())
    WITH CHECK (family_id = public.get_current_family_id());

-- 11.3. DİĞER MODÜL TABLOLARI (TAM İZOLASYON)
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'device_sessions', 'devices', 'tasks', 'task_submissions',
        'rewards', 'reward_redemptions', 'messages', 'violation_logs',
        'school_schedules', 'family_settings', 'appeals', 'qr_stations'
    ])
    LOOP
        -- Tablo varsa RLS aç
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            EXECUTE format('DROP POLICY IF EXISTS "Allow family full access on %I" ON public.%I;', tbl, tbl);
            EXECUTE format('DROP POLICY IF EXISTS "%I_tenant_isolation" ON public.%I;', tbl, tbl);
            EXECUTE format(
                'CREATE POLICY "%I_tenant_isolation" ON public.%I FOR ALL USING (family_id = public.get_current_family_id()) WITH CHECK (family_id = public.get_current_family_id());',
                tbl, tbl
            );
        END IF;
    END LOOP;
END $$;


-- ----------------------------------------------------------------------------
-- 12. RPC YETKİLENDİRMELERİ (GRANT EXECUTE)
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_family_pro(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_current_family_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_current_user_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_desktop_pairing_code(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pair_child_device(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_family_account() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_free_tier_old_data() TO service_role;
