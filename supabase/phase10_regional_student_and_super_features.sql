-- ============================================================================
-- PHASE 10: ÖĞRENCİ ŞEHİR/İLÇE, BÖLGESEL & ÇEVRE İLLER LİDERLİK SIRALAMASI,
-- ANLAMLI TAKAS PAZARI, HAFTALIK SÖZLEŞME (JOKER GÜN) & AİLE GAZETESİ
-- ============================================================================

-- 1. USERS VE FAMILIES TABLOSUNA ŞEHİR, İLÇE, OKUL VE KADEME EKLEME
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'city') THEN
        ALTER TABLE public.users ADD COLUMN city TEXT DEFAULT 'Düzce';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'district') THEN
        ALTER TABLE public.users ADD COLUMN district TEXT DEFAULT 'Akçakoca';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'school_name') THEN
        ALTER TABLE public.users ADD COLUMN school_name TEXT DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'grade_level') THEN
        ALTER TABLE public.users ADD COLUMN grade_level INT DEFAULT 7;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'families' AND column_name = 'city') THEN
        ALTER TABLE public.families ADD COLUMN city TEXT DEFAULT 'Düzce';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'families' AND column_name = 'district') THEN
        ALTER TABLE public.families ADD COLUMN district TEXT DEFAULT 'Akçakoca';
    END IF;
END $$;

-- 2. BÖLGESEL VE ÇEVRE İLLER KÜMESİ FONKSİYONU
-- Dünya çapında değil; öğrencinin kendi ili veya komşu çevre iller bazında yarışmasını sağlar.
CREATE OR REPLACE FUNCTION public.get_neighbor_cities(p_city TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_norm TEXT := LOWER(TRIM(p_city));
BEGIN
    IF v_norm = 'düzce' OR v_norm = 'duzce' THEN
        RETURN ARRAY['düzce', 'bolu', 'sakarya', 'zonguldak', 'kocaeli'];
    ELSIF v_norm = 'bolu' THEN
        RETURN ARRAY['bolu', 'düzce', 'sakarya', 'ankara', 'karabük', 'çankırı'];
    ELSIF v_norm = 'sakarya' THEN
        RETURN ARRAY['sakarya', 'kocaeli', 'düzce', 'bolu', 'bursa', 'bilecik'];
    ELSIF v_norm = 'ankara' THEN
        RETURN ARRAY['ankara', 'kırıkkale', 'çankırı', 'bolu', 'eskişehir', 'konya', 'kırşehir', 'aksaray'];
    ELSIF v_norm = 'istanbul' THEN
        RETURN ARRAY['istanbul', 'kocaeli', 'tekirdağ'];
    ELSIF v_norm = 'izmir' THEN
        RETURN ARRAY['izmir', 'manisa', 'aydın', 'balıkesir'];
    ELSE
        -- Diğer illerde en azından kendi ili
        RETURN ARRAY[v_norm];
    END IF;
END;
$$;

-- 3. BÖLGESEL VE ŞEHİR BAZLI LİDERLİK SIRALAMASI RPC'Sİ
CREATE OR REPLACE FUNCTION public.get_regional_leaderboard(
    p_student_id TEXT,
    p_subject TEXT DEFAULT 'matematik',
    p_scope TEXT DEFAULT 'city' -- 'school', 'city', 'region' (çevre iller)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student RECORD;
    v_target_cities TEXT[];
    v_subject TEXT := LOWER(TRIM(p_subject));
    v_results JSONB;
BEGIN
    SELECT * INTO v_student FROM public.users WHERE id = p_student_id;
    IF v_student.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Öğrenci bulunamadı.');
    END IF;

    IF p_scope = 'region' THEN
        v_target_cities := public.get_neighbor_cities(COALESCE(v_student.city, 'Düzce'));
    ELSE
        v_target_cities := ARRAY[LOWER(TRIM(COALESCE(v_student.city, 'Düzce')))];
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(ranked)), '[]'::jsonb) INTO v_results
    FROM (
        SELECT 
            ROW_NUMBER() OVER (
                ORDER BY 
                    CASE 
                        WHEN v_subject = 'matematik' OR v_subject = 'fen' THEN COALESCE(SUM(logs.net_score), 0)
                        WHEN v_subject = 'turkce' THEN (COALESCE(SUM(logs.pages_read), 0) * 2 + COALESCE(SUM(logs.idioms_learned), 0) * 5 + COALESCE(SUM(logs.questions_solved), 0))
                        WHEN v_subject = 'ingilizce' THEN (COALESCE(SUM(logs.words_learned), 0) * 3 + COALESCE(SUM(logs.questions_solved), 0))
                        ELSE COALESCE(SUM(logs.questions_solved), 0)
                    END DESC
            ) AS rank,
            u.id AS student_id,
            CASE 
                WHEN u.id = p_student_id THEN u.name
                ELSE SUBSTRING(u.name FROM 1 FOR 1) || '*** ' || COALESCE(SUBSTRING(SPLIT_PART(u.name, ' ', 2) FROM 1 FOR 1) || '.', '')
            END AS display_name,
            u.city,
            u.district,
            u.school_name,
            u.grade_level,
            COALESCE(SUM(logs.questions_solved), 0) AS total_questions,
            COALESCE(SUM(logs.net_score), 0.00) AS total_net,
            COALESCE(SUM(logs.pages_read), 0) AS total_pages_read,
            COALESCE(SUM(logs.words_learned), 0) AS total_words_learned,
            COALESCE(SUM(logs.idioms_learned), 0) AS total_idioms_learned,
            (u.id = p_student_id) AS is_current_student
        FROM public.users u
        LEFT JOIN public.student_subject_logs logs 
            ON logs.student_user_id = u.id 
            AND logs.subject = v_subject
            AND logs.log_date >= (CURRENT_DATE - INTERVAL '30 days')
        WHERE u.role = 'child'
          AND u.grade_level = v_student.grade_level
          AND (
              (p_scope = 'school' AND u.school_name = v_student.school_name AND u.school_name <> '')
              OR (p_scope IN ('city', 'region') AND LOWER(u.city) = ANY(v_target_cities))
          )
        GROUP BY u.id, u.name, u.city, u.district, u.school_name, u.grade_level
        LIMIT 50
    ) ranked;

    RETURN jsonb_build_object(
        'success', true,
        'scope', p_scope,
        'subject', v_subject,
        'grade_level', v_student.grade_level,
        'student_city', v_student.city,
        'leaderboard', v_results
    );
END;
$$;

-- 4. ANLAMLI TAKAS PAZARI (REAL-WORLD BARTER MARKET)
-- Puanları sadece PC süresine değil; bulaşık sırasını devretme, film seçme, hafta sonu kahvaltısı siparişine çevirme.
CREATE TABLE IF NOT EXISTS public.barter_market_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    cost_points INT NOT NULL DEFAULT 50,
    icon TEXT NOT NULL DEFAULT '🎁',
    category TEXT NOT NULL DEFAULT 'privilege', -- 'chore_transfer', 'privilege', 'activity', 'food'
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.barter_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    student_user_id TEXT NOT NULL,
    item_id UUID REFERENCES public.barter_market_items(id) ON DELETE CASCADE,
    cost_points INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'used', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- Varsayılan Takas Ödüllerini Doldurma Yardımcısı
CREATE OR REPLACE FUNCTION public.seed_default_barter_items(p_family_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.barter_market_items WHERE family_id = p_family_id) THEN
        INSERT INTO public.barter_market_items (family_id, title, description, cost_points, icon, category) VALUES
        (p_family_id, '🍽️ Bulaşık Sırasını Devret', 'Bugün sofra toplama veya bulaşık sıranı bir defaya mahsus devret.', 60, '🍽️', 'chore_transfer'),
        (p_family_id, '🎬 Akşam Aile Filmini Seç', 'Bu cuma veya cumartesi akşamı izlenecek aile filmini tek başına belirle.', 80, '🎬', 'privilege'),
        (p_family_id, '🥞 Pazar Kahvaltısı Siparişi', 'Pazar sabahı kahvaltısında en sevdiğin yiyeceği (krep, pişi, börek) sipariş et.', 70, '🥞', 'food'),
        (p_family_id, '🚴 Baba / Anne ile Bisiklet Turu', 'Hafta sonu 1 saat baş başa bisiklet veya doğa yürüyüşü.', 50, '🚴', 'activity'),
        (p_family_id, '🎮 +45 Dk Ekstra PC Oyun Hakkı', 'Zaman kısıtlamasına takılmadan 45 dakika ekstra oyun oynama izni.', 90, '🎮', 'privilege');
    END IF;
END;
$$;

-- Takas Puanı Kullanma RPC'si
CREATE OR REPLACE FUNCTION public.redeem_barter_item(
    p_family_id TEXT,
    p_student_id TEXT,
    p_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_user RECORD;
BEGIN
    SELECT * INTO v_item FROM public.barter_market_items WHERE id = p_item_id AND family_id = p_family_id;
    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Takas ödülü bulunamadı.');
    END IF;

    SELECT * INTO v_user FROM public.users WHERE id = p_student_id;
    IF v_user.points_balance < v_item.cost_points THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yetersiz puan! Gereken: ' || v_item.cost_points || ', Mevcut: ' || v_user.points_balance);
    END IF;

    -- Puanı düş
    UPDATE public.users 
    SET points_balance = points_balance - v_item.cost_points
    WHERE id = p_student_id;

    -- Talep kaydı oluştur
    INSERT INTO public.barter_redemptions (family_id, student_user_id, item_id, cost_points, status)
    VALUES (p_family_id, p_student_id, p_item_id, v_item.cost_points, 'pending');

    RETURN jsonb_build_object(
        'success', true,
        'item_title', v_item.title,
        'remaining_points', (v_user.points_balance - v_item.cost_points),
        'message', v_item.title || ' hakkı talep edildi! Anne/babana onay bildirimi iletildi.'
    );
END;
$$;

-- 5. HAFTALIK SÖZLEŞME VE JOKER GÜN (FAMILY WEEKLY CONTRACTS)
CREATE TABLE IF NOT EXISTS public.family_weekly_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    student_user_id TEXT NOT NULL,
    week_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    target_questions INT NOT NULL DEFAULT 150,
    target_reading_pages INT NOT NULL DEFAULT 100,
    target_net_average NUMERIC(5,2) DEFAULT 25.00,
    reward_joker_day BOOLEAN NOT NULL DEFAULT true,
    reward_extra_game_hours INT NOT NULL DEFAULT 2,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    joker_day_claimed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_family_student_week UNIQUE (student_user_id, week_start_date)
);

-- Haftalık Sözleşme Tamamlama ve Joker Gün Kontrolü
CREATE OR REPLACE FUNCTION public.check_and_claim_weekly_contract(
    p_family_id TEXT,
    p_student_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_contract RECORD;
    v_total_questions INT := 0;
    v_total_pages INT := 0;
BEGIN
    SELECT * INTO v_contract 
    FROM public.family_weekly_contracts
    WHERE student_user_id = p_student_id 
      AND family_id = p_family_id
    ORDER BY created_at DESC 
    LIMIT 1;

    IF v_contract.id IS NULL THEN
        -- Eğer sözleşme yoksa bu hafta için otomatik başlat
        INSERT INTO public.family_weekly_contracts (family_id, student_user_id, target_questions, target_reading_pages)
        VALUES (p_family_id, p_student_id, 150, 100)
        RETURNING * INTO v_contract;
    END IF;

    -- Son 7 günün toplam soru ve kitap sayfasını çek
    SELECT 
        COALESCE(SUM(questions_solved), 0),
        COALESCE(SUM(pages_read), 0)
    INTO v_total_questions, v_total_pages
    FROM public.student_subject_logs
    WHERE student_user_id = p_student_id
      AND log_date >= (CURRENT_DATE - INTERVAL '7 days');

    IF v_total_questions >= v_contract.target_questions AND v_total_pages >= v_contract.target_reading_pages THEN
        UPDATE public.family_weekly_contracts
        SET is_completed = true, joker_day_claimed = true
        WHERE id = v_contract.id;

        RETURN jsonb_build_object(
            'success', true,
            'is_completed', true,
            'total_questions', v_total_questions,
            'total_pages', v_total_pages,
            'joker_day_earned', true,
            'extra_hours', v_contract.reward_extra_game_hours,
            'message', 'Tebrikler! Haftalık sözleşmeni erkenden tamamladın. 🎉 Joker Gün ve +' || v_contract.reward_extra_game_hours || ' saat ekstra oyun hakkı kazandın!'
        );
    ELSE
        RETURN jsonb_build_object(
            'success', true,
            'is_completed', false,
            'total_questions', v_total_questions,
            'target_questions', v_contract.target_questions,
            'total_pages', v_total_pages,
            'target_pages', v_contract.target_reading_pages,
            'remaining_questions', GREATEST(0, v_contract.target_questions - v_total_questions),
            'remaining_pages', GREATEST(0, v_contract.target_reading_pages - v_total_pages),
            'message', 'Haftalık hedefe az kaldı! Devam et.'
        );
    END IF;
END;
$$;

-- 6. HAFTALIK BAŞARI VİTRİNİ / AİLE GAZETESİ (THE FAMILY NEWSPAPER)
CREATE TABLE IF NOT EXISTS public.family_weekly_newspapers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    edition_date DATE NOT NULL DEFAULT CURRENT_DATE,
    headline TEXT NOT NULL,
    subheadline TEXT,
    stories JSONB NOT NULL DEFAULT '[]'::jsonb,
    star_student_name TEXT,
    total_questions INT DEFAULT 0,
    total_pages_read INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.get_or_generate_weekly_newspaper(p_family_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_paper RECORD;
    v_total_questions INT;
    v_total_pages INT;
    v_top_student TEXT;
    v_headline TEXT;
BEGIN
    SELECT * INTO v_paper 
    FROM public.family_weekly_newspapers
    WHERE family_id = p_family_id 
      AND edition_date >= (CURRENT_DATE - INTERVAL '7 days')
    ORDER BY created_at DESC 
    LIMIT 1;

    IF v_paper.id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'headline', v_paper.headline,
            'subheadline', v_paper.subheadline,
            'edition_date', v_paper.edition_date,
            'stories', v_paper.stories,
            'star_student_name', v_paper.star_student_name,
            'total_questions', v_paper.total_questions,
            'total_pages_read', v_paper.total_pages_read
        );
    END IF;

    -- Yeni Aile Gazetesi Üret
    SELECT COALESCE(SUM(questions_solved), 0), COALESCE(SUM(pages_read), 0)
    INTO v_total_questions, v_total_pages
    FROM public.student_subject_logs
    WHERE family_id = p_family_id AND log_date >= (CURRENT_DATE - INTERVAL '7 days');

    SELECT u.name INTO v_top_student
    FROM public.users u
    WHERE u.family_id = p_family_id AND u.role = 'child'
    ORDER BY u.points_balance DESC LIMIT 1;

    v_headline := 'Haftanın Şampiyonu: ' || COALESCE(v_top_student, 'Öğrencimiz') || ' Rekor Kırdı!';

    INSERT INTO public.family_weekly_newspapers (
        family_id, edition_date, headline, subheadline, star_student_name, total_questions, total_pages_read, stories
    ) VALUES (
        p_family_id,
        CURRENT_DATE,
        v_headline,
        'Bu hafta ailemiz toplam ' || v_total_questions || ' soru çözdü ve ' || v_total_pages || ' sayfa kitap devirdi!',
        COALESCE(v_top_student, 'Öğrencimiz'),
        v_total_questions,
        v_total_pages,
        jsonb_build_array(
            jsonb_build_object('title', 'Matematikte Büyük Atılım', 'body', 'Yeni nesil LGS sorularında netler tavan yaptı.'),
            jsonb_build_object('title', 'Kitap Kurdu Seferberliği', 'body', 'Akşam kitap okuma saatlerinde sessizlik rekoru kırıldı.'),
            jsonb_build_object('title', 'Sıfır Ekran Kavgası', 'body', 'Zaman Bankası ve Joker Gün sayesinde evde huzur rüzgarları esti.')
        )
    ) RETURNING * INTO v_paper;

    RETURN jsonb_build_object(
        'success', true,
        'headline', v_paper.headline,
        'subheadline', v_paper.subheadline,
        'edition_date', v_paper.edition_date,
        'stories', v_paper.stories,
        'star_student_name', v_paper.star_student_name,
        'total_questions', v_paper.total_questions,
        'total_pages_read', v_paper.total_pages_read
    );
END;
$$;

-- 7. İZİNLER
GRANT EXECUTE ON FUNCTION public.get_neighbor_cities(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_regional_leaderboard(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.seed_default_barter_items(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_barter_item(TEXT, TEXT, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_and_claim_weekly_contract(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_or_generate_weekly_newspaper(TEXT) TO anon, authenticated, service_role;
