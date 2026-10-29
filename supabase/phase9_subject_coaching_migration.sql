-- ============================================================================
-- PHASE 9: BRANŞ KOÇLUĞU, TERSİNE KEŞİF, DERS BAZLI İSTATİSTİKLER & VELİ DENETİMİ
-- ============================================================================
-- Branşlar: Matematik (Soru/Net), Türkçe (Kitap/Kelime/Deyim/Atasözü), İngilizce (Soru/Kelime)
-- Akış: Öğrenci Keşif -> Veli/Koç Onayı -> Günlük İstatistik Kaydı -> Grup Ligi Sıralaması
-- ============================================================================

-- 1. COACH_GROUPS TABLOSUNU BRANŞ VE BİYOGRAFİ İLE GENİŞLETME
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_groups' AND column_name = 'subject') THEN
        ALTER TABLE public.coach_groups ADD COLUMN subject TEXT NOT NULL DEFAULT 'matematik';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_groups' AND column_name = 'city') THEN
        ALTER TABLE public.coach_groups ADD COLUMN city TEXT DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_groups' AND column_name = 'district') THEN
        ALTER TABLE public.coach_groups ADD COLUMN district TEXT DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_groups' AND column_name = 'bio') THEN
        ALTER TABLE public.coach_groups ADD COLUMN bio TEXT DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_groups' AND column_name = 'is_public') THEN
        ALTER TABLE public.coach_groups ADD COLUMN is_public BOOLEAN DEFAULT true;
    END IF;
END $$;

-- 2. COACH_GROUP_STUDENTS TABLOSUNA ONAY VE DURUM ALANLARI
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_group_students' AND column_name = 'status') THEN
        ALTER TABLE public.coach_group_students ADD COLUMN status TEXT NOT NULL DEFAULT 'approved';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_group_students' AND column_name = 'applied_at') THEN
        ALTER TABLE public.coach_group_students ADD COLUMN applied_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'coach_group_students' AND column_name = 'approved_at') THEN
        ALTER TABLE public.coach_group_students ADD COLUMN approved_at TIMESTAMPTZ;
    END IF;
END $$;

-- 3. DERS BAZLI GÜNLÜK İSTATİSTİK TABLOSU (STUDENT_SUBJECT_LOGS)
CREATE TABLE IF NOT EXISTS public.student_subject_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_user_id TEXT NOT NULL,
    family_id TEXT NOT NULL,
    subject TEXT NOT NULL, -- 'matematik', 'turkce', 'ingilizce', 'fen', 'sosyal', 'lgs_genel'
    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Sayısal ve LGS Metrikleri (Matematik / Fen / Sosyal)
    questions_solved INT DEFAULT 0,
    correct_count INT DEFAULT 0,
    wrong_count INT DEFAULT 0,
    net_score NUMERIC(6,2) DEFAULT 0.00,
    
    -- Sözel & Dil Metrikleri (Türkçe / Edebiyat)
    pages_read INT DEFAULT 0,
    idioms_learned INT DEFAULT 0,  -- Yeni Deyim & Atasözü
    
    -- Dil & Kelime Metrikleri (İngilizce / Türkçe)
    words_learned INT DEFAULT 0,   -- Yeni Kelime (Vocabulary)
    
    -- Masaüstü & Mobil Süre Telemetrisi (Dakika)
    study_duration_minutes INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_student_subject_date UNIQUE (student_user_id, subject, log_date)
);

CREATE INDEX IF NOT EXISTS idx_student_subject_logs_lookup 
ON public.student_subject_logs(student_user_id, subject, log_date);

-- 4. GÜNLÜK DERS VE AKTİVİTE GİRİŞİ (UPSERT RPC)
CREATE OR REPLACE FUNCTION public.log_subject_activity(
    p_student_user_id TEXT,
    p_family_id TEXT,
    p_subject TEXT,
    p_questions INT DEFAULT 0,
    p_correct INT DEFAULT 0,
    p_wrong INT DEFAULT 0,
    p_pages_read INT DEFAULT 0,
    p_words_learned INT DEFAULT 0,
    p_idioms_learned INT DEFAULT 0,
    p_duration_minutes INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_net NUMERIC(6,2);
    v_record RECORD;
BEGIN
    -- LGS / Ortaokul kuralı: 3 Yanlış 1 Doğruyu götürür (Net = Doğru - Yanlış/3)
    IF p_correct > 0 OR p_wrong > 0 THEN
        v_net := ROUND((p_correct - (p_wrong::numeric / 3.0)), 2);
        IF v_net < 0 THEN v_net := 0.00; END IF;
    ELSE
        v_net := 0.00;
    END IF;

    INSERT INTO public.student_subject_logs (
        student_user_id, family_id, subject, log_date,
        questions_solved, correct_count, wrong_count, net_score,
        pages_read, words_learned, idioms_learned, study_duration_minutes,
        updated_at
    )
    VALUES (
        p_student_user_id, p_family_id, LOWER(p_subject), CURRENT_DATE,
        GREATEST(p_questions, 0), GREATEST(p_correct, 0), GREATEST(p_wrong, 0), v_net,
        GREATEST(p_pages_read, 0), GREATEST(p_words_learned, 0), GREATEST(p_idioms_learned, 0), GREATEST(p_duration_minutes, 0),
        NOW()
    )
    ON CONFLICT (student_user_id, subject, log_date) DO UPDATE
    SET 
        questions_solved = public.student_subject_logs.questions_solved + EXCLUDED.questions_solved,
        correct_count = public.student_subject_logs.correct_count + EXCLUDED.correct_count,
        wrong_count = public.student_subject_logs.wrong_count + EXCLUDED.wrong_count,
        net_score = ROUND(( (public.student_subject_logs.correct_count + EXCLUDED.correct_count) - ((public.student_subject_logs.wrong_count + EXCLUDED.wrong_count)::numeric / 3.0) ), 2),
        pages_read = public.student_subject_logs.pages_read + EXCLUDED.pages_read,
        words_learned = public.student_subject_logs.words_learned + EXCLUDED.words_learned,
        idioms_learned = public.student_subject_logs.idioms_learned + EXCLUDED.idioms_learned,
        study_duration_minutes = public.student_subject_logs.study_duration_minutes + EXCLUDED.study_duration_minutes,
        updated_at = NOW()
    RETURNING * INTO v_record;

    RETURN jsonb_build_object(
        'success', true,
        'subject', v_record.subject,
        'net_score', v_record.net_score,
        'total_questions', v_record.questions_solved,
        'pages_read', v_record.pages_read,
        'words_learned', v_record.words_learned,
        'idioms_learned', v_record.idioms_learned,
        'study_duration_minutes', v_record.study_duration_minutes
    );
END;
$$;

-- 5. TERSİNE KEŞİF: YAKIN KONUM VE DERS BAZLI KOÇLARI LİSTELEME
CREATE OR REPLACE FUNCTION public.discover_coach_groups(
    p_grade_level INT DEFAULT NULL,
    p_subject TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_results
    FROM (
        SELECT 
            cg.id,
            cg.name,
            cg.grade_level,
            cg.subject,
            cg.group_code,
            cg.school_name,
            cg.city,
            cg.district,
            cg.bio,
            cg.created_at,
            COUNT(cgs.student_user_id) FILTER (WHERE cgs.status = 'approved') AS active_students_count
        FROM public.coach_groups cg
        LEFT JOIN public.coach_group_students cgs ON cg.id = cgs.group_id
        WHERE cg.is_public = true
          AND (p_grade_level IS NULL OR cg.grade_level = p_grade_level)
          AND (p_subject IS NULL OR p_subject = '' OR cg.subject = LOWER(p_subject))
          AND (p_city IS NULL OR p_city = '' OR LOWER(cg.city) LIKE '%' || LOWER(p_city) || '%')
        GROUP BY cg.id
        ORDER BY active_students_count DESC, cg.created_at DESC
        LIMIT 50
    ) sub;

    RETURN v_results;
END;
$$;

-- 6. ÖĞRENCİNİN KOÇ GRUBUNA BAŞVURUSU (Veli/Koç Onay Döngüsü)
CREATE OR REPLACE FUNCTION public.apply_to_coach_group(
    p_group_code TEXT,
    p_student_user_id TEXT,
    p_family_id TEXT,
    p_requires_parent_approval BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_group RECORD;
    v_initial_status TEXT;
BEGIN
    SELECT * INTO v_group FROM public.coach_groups WHERE UPPER(group_code) = UPPER(TRIM(p_group_code));
    IF v_group.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Geçersiz koçluk grubu kodu.');
    END IF;

    -- Eğer veli onayı şartsa 'pending_parent', değilse doğrudan koç onayına 'pending_coach'
    v_initial_status := CASE WHEN p_requires_parent_approval THEN 'pending_parent' ELSE 'pending_coach' END;

    INSERT INTO public.coach_group_students (
        group_id, student_user_id, family_id, status, applied_at
    )
    VALUES (
        v_group.id, p_student_user_id, p_family_id, v_initial_status, NOW()
    )
    ON CONFLICT (group_id, student_user_id) DO UPDATE
    SET status = EXCLUDED.status, applied_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'group_id', v_group.id,
        'group_name', v_group.name,
        'subject', v_group.subject,
        'status', v_initial_status,
        'message', CASE 
            WHEN v_initial_status = 'pending_parent' THEN 'Başvurunuz alındı. Veli onayı bekleniyor.'
            ELSE 'Başvurunuz koçun onayına gönderildi.'
        END
    );
END;
$$;

-- 7. KOÇ VE VELİ ONAY / RET / ÇIKARMA MEKANİZMASI
CREATE OR REPLACE FUNCTION public.respond_coach_group_application(
    p_group_id UUID,
    p_student_user_id TEXT,
    p_action TEXT -- 'parent_approve', 'coach_approve', 'reject', 'remove'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_status TEXT;
BEGIN
    IF p_action = 'parent_approve' THEN
        v_new_status := 'pending_coach';
    ELSIF p_action = 'coach_approve' THEN
        v_new_status := 'approved';
    ELSIF p_action = 'reject' THEN
        v_new_status := 'rejected';
    ELSIF p_action = 'remove' THEN
        DELETE FROM public.coach_group_students 
        WHERE group_id = p_group_id AND student_user_id = p_student_user_id;
        RETURN jsonb_build_object('success', true, 'message', 'Öğrenci gruptan çıkarıldı.');
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Geçersiz aksiyon.');
    END IF;

    UPDATE public.coach_group_students
    SET 
        status = v_new_status,
        approved_at = CASE WHEN v_new_status = 'approved' THEN NOW() ELSE approved_at END
    WHERE group_id = p_group_id AND student_user_id = p_student_user_id;

    RETURN jsonb_build_object('success', true, 'status', v_new_status, 'message', 'Durum güncellendi: ' || v_new_status);
END;
$$;

-- 8. GRUP İÇİ BRANŞ LİDERLİK TABLOSU (LEADERBOARD)
CREATE OR REPLACE FUNCTION public.get_coach_group_leaderboard(p_group_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subject TEXT;
    v_results JSONB;
BEGIN
    SELECT subject INTO v_subject FROM public.coach_groups WHERE id = p_group_id;
    IF v_subject IS NULL THEN
        RETURN '[]'::jsonb;
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
            cgs.student_user_id,
            COALESCE(u.name, 'Öğrenci') AS student_name,
            cgs.status,
            COALESCE(SUM(logs.questions_solved), 0) AS total_questions,
            COALESCE(SUM(logs.correct_count), 0) AS total_correct,
            COALESCE(SUM(logs.wrong_count), 0) AS total_wrong,
            COALESCE(SUM(logs.net_score), 0.00) AS total_net,
            COALESCE(SUM(logs.pages_read), 0) AS total_pages_read,
            COALESCE(SUM(logs.words_learned), 0) AS total_words_learned,
            COALESCE(SUM(logs.idioms_learned), 0) AS total_idioms_learned,
            COALESCE(SUM(logs.study_duration_minutes), 0) AS total_study_minutes
        FROM public.coach_group_students cgs
        LEFT JOIN public.users u ON u.id = cgs.student_user_id
        LEFT JOIN public.student_subject_logs logs 
            ON logs.student_user_id = cgs.student_user_id 
            AND logs.subject = v_subject
            AND logs.log_date >= (CURRENT_DATE - INTERVAL '30 days')
        WHERE cgs.group_id = p_group_id
        GROUP BY cgs.student_user_id, u.name, cgs.status
    ) ranked;

    RETURN v_results;
END;
$$;

-- 9. VELİ İÇİN ÇOCUK BRANŞ KARNESİ
CREATE OR REPLACE FUNCTION public.get_student_subject_summary(
    p_student_user_id TEXT,
    p_family_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(sub)), '[]'::jsonb) INTO v_results
    FROM (
        SELECT 
            subject,
            SUM(questions_solved) AS total_questions,
            SUM(correct_count) AS total_correct,
            SUM(wrong_count) AS total_wrong,
            SUM(net_score) AS total_net,
            SUM(pages_read) AS total_pages_read,
            SUM(words_learned) AS total_words_learned,
            SUM(idioms_learned) AS total_idioms_learned,
            SUM(study_duration_minutes) AS total_study_minutes,
            MAX(log_date) AS last_activity_date
        FROM public.student_subject_logs
        WHERE student_user_id = p_student_user_id 
          AND family_id = p_family_id
          AND log_date >= (CURRENT_DATE - INTERVAL '30 days')
        GROUP BY subject
    ) sub;

    RETURN v_results;
END;
$$;

-- 10. İZİNLER
GRANT EXECUTE ON FUNCTION public.log_subject_activity(TEXT, TEXT, TEXT, INT, INT, INT, INT, INT, INT, INT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.discover_coach_groups(INT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.apply_to_coach_group(TEXT, TEXT, TEXT, BOOLEAN) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.respond_coach_group_application(UUID, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_coach_group_leaderboard(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_student_subject_summary(TEXT, TEXT) TO anon, authenticated, service_role;
