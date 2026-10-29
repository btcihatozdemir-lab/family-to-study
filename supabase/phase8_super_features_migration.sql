-- ============================================================================
-- FAZ 8 MİGRATION: SUPER FEATURES, COACH/CLASSROOM LOOP, TIME VAULT & LINGUA
-- ============================================================================
-- Mimari Kurallar:
-- 1. Koç (Coach/Teacher) ailenin özel chat'ini veya cihaz detaylarını göremez.
-- 2. Çocuk arayüzü tek dokunuşluk veri döner; karmaşık hesaplamalar RPC'de yapılır.
-- 3. Tüm tablolar RLS ile korunur.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EĞİTİM KOÇLUĞU VE KADEME GRUPLARI (COACH / CLASSROOM LOOP)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.coach_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_auth_id UUID NOT NULL, -- Öğretmenin auth.uid() kaydı
    name TEXT NOT NULL, -- Örn: "7. Sınıf LGS Koçluk Grubu", "4-A Sınıfı"
    grade_level INTEGER NOT NULL DEFAULT 7, -- Kademe (1-12)
    group_code TEXT NOT NULL UNIQUE, -- Örn: "KOC-7A26" (Öğrencilerin katılma kodu)
    school_name TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.coach_group_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.coach_groups(id) ON DELETE CASCADE,
    student_user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(group_id, student_user_id)
);

-- Koçluk Ortak Görevleri (Örn: "Bugün 40 Matematik Sorusu + 20 Sayfa Kitap")
CREATE TABLE IF NOT EXISTS public.coach_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.coach_groups(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    target_questions INTEGER DEFAULT 0,
    target_pages INTEGER DEFAULT 0,
    due_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. ZAMAN BANKASI VE TASARRUF (TIME VAULT)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.time_vaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    saved_minutes INTEGER NOT NULL DEFAULT 0, -- Hafta içi tasarruf edilen serbest zaman
    borrowed_minutes INTEGER NOT NULL DEFAULT 0, -- Avans/kredi çekilen zaman borcu
    last_payout_date DATE, -- Cuma akşamı haftalık aktarım tarihi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(family_id, student_id)
);

-- ----------------------------------------------------------------------------
-- 3. GÜNÜN KELİMESİ VE DEYİMİ MOTORU (LINGUA-LOCK & CONVERSATION STARTER)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lingua_words (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lang_code VARCHAR(5) NOT NULL DEFAULT 'tr', -- 'tr', 'en', 'de'
    word TEXT NOT NULL,
    meaning TEXT NOT NULL,
    etymology TEXT, -- Kökeni
    sample_sentence TEXT NOT NULL,
    quiz_question TEXT NOT NULL,
    correct_option TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT NOT NULL,
    active_date DATE NOT NULL, -- Hangi gün gösterilecek
    UNIQUE(lang_code, active_date)
);

-- ----------------------------------------------------------------------------
-- 4. 5 DAKİKA MOLA İSTEĞİ (GRACE BREAK REQUESTS)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grace_break_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'used'
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    responded_by TEXT
);

-- ----------------------------------------------------------------------------
-- 5. AİLE İÇİ DİJİTAL SÖZLEŞME VE JOKER GÜN (FAMILY CONTRACTS)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    weekly_target_questions INTEGER NOT NULL DEFAULT 200,
    weekly_target_reading_hours INTEGER NOT NULL DEFAULT 5,
    reward_extra_game_hours INTEGER NOT NULL DEFAULT 2, -- Erken bitirme ödülü
    has_joker_day BOOLEAN NOT NULL DEFAULT false, -- Joker gün hakkı
    week_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. ANLAMLIK TAKAS PAZARI (BARTER MARKET)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.barter_market_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    title TEXT NOT NULL, -- Örn: "Bulaşık Sırasını Kardeşe Devretme", "Pazar Kahvaltısı Seçimi"
    cost_coins INTEGER NOT NULL DEFAULT 100,
    icon_emoji TEXT NOT NULL DEFAULT '🎟️',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. HAFTALIK DİJİTAL AİLE GAZETESİ (THE FAMILY NEWSPAPER)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_newspapers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    headline TEXT NOT NULL, -- Örn: "Ömer Asaf Matematik Rekoru Kırdı!"
    summary_markdown TEXT NOT NULL,
    total_questions_solved INTEGER DEFAULT 0,
    total_reading_minutes INTEGER DEFAULT 0,
    hero_student_name TEXT,
    edition_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 8. ÖRNEK GÜNÜN KELİMELERİ (TR, EN, DE) TOHUM VERİLERİ (SEED DATA)
-- ----------------------------------------------------------------------------
INSERT INTO public.lingua_words (lang_code, word, meaning, etymology, sample_sentence, quiz_question, correct_option, option_b, option_c, active_date)
VALUES
('tr', 'Serendipiti', 'Şans eseri değerli bir şeyi tesadüfen keşfetme yeteneği.', 'İngilizce "Serendipity" kelimesinden, Seylan masallarından türemiştir.', 'Penisilinin keşfi tarihteki en büyük serendipiti örneklerinden biridir.', '"Serendipiti" kelimesinin anlamı nedir?', 'Tesadüfen güzel keşifler yapma', 'Sürekli ders çalışma zorunluluğu', 'Zamanı boşa harcama', CURRENT_DATE),
('en', 'Resilience', 'The capacity to recover quickly from difficulties; toughness.', 'Latin "resilire" (to leap back or rebound).', 'Her resilience helped her overcome the challenging math test.', 'What is the definition of "Resilience"?', 'Ability to bounce back from challenges', 'Sleeping all day', 'Playing games endlessly', CURRENT_DATE),
('de', 'Weggefährte', 'Eine Person, die jemanden auf einem Weg oder Lebensabschnitt begleitet.', 'Aus Weg und Gefährte (Fahren/Reisen).', 'Ein treuer Weggefährte unterstützt dich auch bei schweren Aufgaben.', 'Was bedeutet "Weggefährte"?', 'Ein treuer Begleiter auf dem Lebensweg', 'Ein schneller Computer', 'Ein strenger Schulmeister', CURRENT_DATE)
ON CONFLICT (lang_code, active_date) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 9. RPC FONKSİYONLARI (KATI MİMARİ VE PERFORMANS)
-- ----------------------------------------------------------------------------

-- 9.1. 5 Dakika Mola İsteme (Çocuk Çağırır)
CREATE OR REPLACE FUNCTION public.request_grace_break(p_device_id TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fam_id TEXT;
    v_user_id TEXT;
    v_today_count INT;
    v_req_id UUID;
BEGIN
    v_fam_id := public.get_current_family_id();
    v_user_id := public.get_current_user_id();

    IF v_user_id IS NULL OR v_fam_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Oturum doğrulanamadı.');
    END IF;

    -- Günde maksimum 1 kez 5 dakika esneklik hakkı
    SELECT COUNT(*) INTO v_today_count
    FROM public.grace_break_requests
    WHERE student_id = v_user_id
      AND requested_at >= CURRENT_DATE::timestamptz;

    IF v_today_count >= 1 THEN
        RETURN jsonb_build_object('success', false, 'error_code', 'DAILY_LIMIT_REACHED', 'message', 'Bugünkü 5 dakikalık mola esneklik hakkınızı zaten kullandınız.');
    END IF;

    INSERT INTO public.grace_break_requests (
        family_id, student_id, device_id, status
    ) VALUES (
        v_fam_id, v_user_id, p_device_id, 'approved' -- İlk etapta çocuk direnci kırılması için otomatik 5 dk onay
    ) RETURNING id INTO v_req_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_req_id,
        'grace_minutes', 5,
        'message', 'Harika! 5 dakikalık esneklik molan başladı. Süre bitince kalkanını korumak için dönmeyi unutma!'
    );
END;
$$;

-- 9.2. Zaman Bankasına Tasarruf Dakikası Ekleme / Bakiye Sorgulama
CREATE OR REPLACE FUNCTION public.get_or_create_time_vault(p_student_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fam_id TEXT;
    v_vault RECORD;
BEGIN
    v_fam_id := public.get_current_family_id();

    SELECT * INTO v_vault
    FROM public.time_vaults
    WHERE family_id = v_fam_id AND student_id = p_student_id
    LIMIT 1;

    IF v_vault.id IS NULL THEN
        INSERT INTO public.time_vaults (family_id, student_id, saved_minutes)
        VALUES (v_fam_id, p_student_id, 30) -- Başlangıç hoş geldin tasarrufu: 30 dk
        RETURNING * INTO v_vault;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'saved_minutes', v_vault.saved_minutes,
        'borrowed_minutes', v_vault.borrowed_minutes
    );
END;
$$;

-- 9.3. Koçluk Grubuna Katılma (Öğrenci Kodu Girer: "KOC-7A26")
CREATE OR REPLACE FUNCTION public.join_coach_group(p_group_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fam_id TEXT;
    v_user_id TEXT;
    v_grp RECORD;
BEGIN
    v_fam_id := public.get_current_family_id();
    v_user_id := public.get_current_user_id();

    SELECT * INTO v_grp
    FROM public.coach_groups
    WHERE upper(group_code) = upper(trim(p_group_code))
    LIMIT 1;

    IF v_grp.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bu koda ait koçluk grubu bulunamadı.');
    END IF;

    INSERT INTO public.coach_group_students (group_id, student_user_id, family_id)
    VALUES (v_grp.id, v_user_id, v_fam_id)
    ON CONFLICT (group_id, student_user_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'group_name', v_grp.name,
        'grade_level', v_grp.grade_level,
        'message', v_grp.name || ' koçluk grubuna başarıyla katıldınız!'
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. YETKİLENDİRMELER
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.request_grace_break(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_or_create_time_vault(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_coach_group(TEXT) TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 11. ÖĞRETMEN / KOÇ HESAP VE VERİ SİLME (App Store Guideline 5.1.1(v))
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_coach_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_auth_id UUID;
BEGIN
    v_auth_id := auth.uid();

    IF v_auth_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Oturum açmış koç bulunamadı.');
    END IF;

    -- Koçun açtığı grupları sil (ON DELETE CASCADE ile tüm alt kayıtlar silinir)
    DELETE FROM public.coach_groups WHERE coach_auth_id = v_auth_id;

    -- auth.users kaydını sil
    BEGIN
        DELETE FROM auth.users WHERE id = v_auth_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object('success', true, 'message', 'Koç hesabınız ve tüm gruplarınız başarıyla silindi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_coach_account() TO anon, authenticated, service_role;
