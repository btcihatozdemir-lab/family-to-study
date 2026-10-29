-- ============================================================================
-- PHASE 12: AİLE BAĞI, AKRAN ODALARI, QR PAIRING, AI KOÇ & BİLATERAL BÜYÜME (PART 2)
-- ============================================================================
-- 15. Ebeveyn Dijital İkizi (AI Family Mediator)
-- 16. Hafıza Çemberi (Digital Family Time Capsule)
-- 17. Tersine Mentorluk (Kid-to-Parent Siber Güvenlik Görevleri)
-- 18. Zaman Çizelgesi ve Gelecek Mektubu (Future Letter)
-- 21. Akran Çalışma Odaları (Safe Social Study Rooms)
-- 22. Haftalık Pozitif Ebeveynlik Karnesi
-- 24. Sihirli Bağlantı (Kamera ile QR Pairing)
-- 25. Ebeveyn Koçu (AI Destekli Haftalık Özet)
-- 26. Bilateral Trial (Referral ile +14 Gün Pro Hediye)
-- ============================================================================

-- 1. EBEVEYN DİJİTAL İKİZİ (AI MEDIATOR)
CREATE TABLE IF NOT EXISTS public.family_ai_mediation_cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    student_user_id TEXT NOT NULL,
    issue_type TEXT NOT NULL, -- 'screen_time_appeal', 'bedtime_debate', 'task_dispute'
    student_request TEXT NOT NULL,
    ai_recommendation TEXT NOT NULL,
    compromise_offered TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'proposed', -- 'proposed', 'accepted', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- 2. HAFIZA ÇEMBERİ (FAMILY TIME CAPSULE)
CREATE TABLE IF NOT EXISTS public.family_time_capsules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    author_user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    note TEXT NOT NULL,
    memory_type TEXT NOT NULL DEFAULT 'funny_moment', -- 'funny_moment', 'book_quote', 'achievement'
    unlock_date DATE NOT NULL,
    is_opened BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TERSİNE MENTORLUK (KID-TO-PARENT CYBER SECURITY)
CREATE TABLE IF NOT EXISTS public.reverse_mentoring_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    concept TEXT NOT NULL, -- 'phishing', 'strong_password', 'two_factor_auth', 'digital_footprint'
    instruction_for_child TEXT NOT NULL,
    parent_quiz_question TEXT NOT NULL,
    parent_quiz_options JSONB NOT NULL DEFAULT '[]'::jsonb,
    correct_option_index INT NOT NULL DEFAULT 0,
    xp_reward INT NOT NULL DEFAULT 50
);

-- 4. GELECEK MEKTUBU (FUTURE LETTER)
CREATE TABLE IF NOT EXISTS public.student_future_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_user_id TEXT NOT NULL,
    family_id TEXT NOT NULL,
    letter_text TEXT NOT NULL,
    target_date DATE NOT NULL, -- örn 1 yıl sonraki karne günü
    is_delivered BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. AKRAN ÇALIŞMA ODALARI (SAFE SOCIAL STUDY ROOMS)
-- Çocukların mesajlaşmadan sadece avatarları ve canlı kronometreleriyle birlikte ders çalıştığı sessiz oda.
CREATE TABLE IF NOT EXISTS public.study_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    grade_level INT NOT NULL DEFAULT 7,
    subject TEXT NOT NULL DEFAULT 'matematik',
    active_participant_count INT DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.study_room_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES public.study_rooms(id) ON DELETE CASCADE,
    student_user_id TEXT NOT NULL,
    avatar_emoji TEXT NOT NULL DEFAULT '🦁',
    student_name TEXT NOT NULL DEFAULT 'Öğrenci',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    duration_minutes INT DEFAULT 0
);

-- 6. SİHİRLİ BAĞLANTI (QR PAIRING)
CREATE TABLE IF NOT EXISTS public.device_pairing_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    pairing_code TEXT NOT NULL UNIQUE,
    qr_payload TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_consumed BOOLEAN NOT NULL DEFAULT false,
    consumed_by_device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. BİLATERAL TRİAL (+14 GÜN PRO BÜYÜME DÖNGÜSÜ)
CREATE TABLE IF NOT EXISTS public.bilateral_referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_family_id TEXT NOT NULL,
    referred_family_id TEXT,
    referral_code TEXT NOT NULL UNIQUE,
    reward_days_granted INT DEFAULT 14,
    is_rewarded BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. SEED DATA (Tersine Mentorluk & Çalışma Odaları)
INSERT INTO public.reverse_mentoring_missions (title, concept, instruction_for_child, parent_quiz_question, parent_quiz_options, correct_option_index) VALUES
('Annene Oltalama (Phishing) Tuzağını Anlat', 'phishing', 'Annene veya babana bilmedikleri kişilerden gelen "Hediye kazandınız tıkla" linklerine neden basmamaları gerektiğini anlat.', 'Güvenmediğiniz bir SMS veya e-postadan gelen linke tıklandığında ne olabilir?', '["Bilgileriniz veya şifreniz çalınabilir", "Bilgisayar otomatik hızlanır", "Hiçbir şey olmaz"]'::jsonb, 0),
('Babanın Parola Güvenliğini Denetle', 'strong_password', 'Babana 123456 veya doğum tarihi gibi şifrelerin 1 saniyede kırıldığını, büyük harf ve sembol kullanması gerektiğini öğret.', 'Güçlü bir parola hangisidir?', '["123456Aa", "K@r4b4k_2026!#", "akcakoca"]'::jsonb, 1)
ON CONFLICT DO NOTHING;

INSERT INTO public.study_rooms (title, grade_level, subject) VALUES
('7. Sınıf Sessiz LGS Odak Odası', 7, 'matematik'),
('8. Sınıf Paragraf & Kitap Okuma Kulübü', 8, 'turkce'),
('Ortaokul Gece Baykuşları Çalışma Odası', 7, 'genel')
ON CONFLICT DO NOTHING;

-- 9. İZİNLER
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
