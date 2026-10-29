-- ============================================================================
-- PHASE 11: ZİHİN AÇICI EĞİTİCİ VE MİKRO-ÖĞRENME MODÜLLERİ (PART 1)
-- ============================================================================
-- 7. Günün Sırrı / İlginç Bilgi (Mind-Blowing Fact)
-- 8. Kodla Kilidi Aç (Code-to-Unlock / Algoritma Bulmacası)
-- 9. Aile İçi Sınav Fabrikası (Custom Family Trivia)
-- 10. 1 Dakikalık Münazara (Critical Thinking)
-- 11. Bilim İnsanı Günlüğü (Micro-Experiment)
-- 12. Yerel Tarih ve Keşif Görevleri
-- 13. Geleceğin Meslekleri Rozetleri
-- ============================================================================

-- 1. GÜNÜN SIRRI & BİLİMSEL İLGİNÇ BİLGİLER TABLOSU
CREATE TABLE IF NOT EXISTS public.daily_mind_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    fact TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'science', -- 'science', 'space', 'history', 'nature'
    question TEXT NOT NULL,
    options JSONB NOT NULL DEFAULT '[]'::jsonb,
    correct_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. KODLA KİLİDİ AÇ & ALGORİTMA BULMACALARI TABLOSU
CREATE TABLE IF NOT EXISTS public.code_unlock_puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'blockly', -- 'blockly', 'python', 'scratch'
    code_snippets JSONB NOT NULL DEFAULT '[]'::jsonb, -- sıralanacak bloklar
    correct_order JSONB NOT NULL DEFAULT '[]'::jsonb,
    hint TEXT,
    xp_reward INT NOT NULL DEFAULT 35
);

-- 3. AİLE İÇİ SINAV FABRİKASI (CUSTOM FAMILY TRIVIA)
CREATE TABLE IF NOT EXISTS public.family_trivia_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    title TEXT NOT NULL,
    subject TEXT NOT NULL DEFAULT 'genel',
    questions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 1 DAKİKALIK MÜNAZARA (CRITICAL THINKING)
CREATE TABLE IF NOT EXISTS public.micro_debates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'technology',
    pro_argument TEXT,
    con_argument TEXT,
    active_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS public.student_debate_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debate_id UUID REFERENCES public.micro_debates(id) ON DELETE CASCADE,
    student_user_id TEXT NOT NULL,
    family_id TEXT NOT NULL,
    stance TEXT NOT NULL, -- 'pro', 'con', 'neutral'
    argument_text TEXT NOT NULL,
    ai_feedback TEXT,
    xp_earned INT DEFAULT 25,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. BİLİM İNSANI GÜNLÜĞÜ (MİKRO-DENEYLER)
CREATE TABLE IF NOT EXISTS public.micro_experiments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 5,
    materials JSONB NOT NULL DEFAULT '[]'::jsonb,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    scientific_explanation TEXT NOT NULL,
    safety_warning TEXT,
    xp_reward INT DEFAULT 40
);

-- 6. GELECEĞİN MESLEKLERİ SİMÜLASYONU
CREATE TABLE IF NOT EXISTS public.future_career_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    icon TEXT NOT NULL,
    field TEXT NOT NULL,
    required_subject TEXT NOT NULL,
    required_questions INT NOT NULL DEFAULT 50,
    description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.student_career_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_user_id TEXT NOT NULL,
    badge_id UUID REFERENCES public.future_career_badges(id) ON DELETE CASCADE,
    progress_count INT NOT NULL DEFAULT 0,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    unlocked_at TIMESTAMPTZ,
    CONSTRAINT uq_student_badge UNIQUE (student_user_id, badge_id)
);

-- 7. SEED DATA DOLDURMA (Günün Sırrı, Kod Bulmacası, Münazara, Deneyler, Geleceğin Meslekleri)
INSERT INTO public.daily_mind_facts (title, fact, category, question, options, correct_index) VALUES
('Balinaların Kalbi', 'Mavi balinanın kalbi o kadar büyüktür ki, bir insan atardamarlarının içinde rahatça yüzebilir!', 'nature', 'Mavi balinanın kalbi yaklaşık ne kadardır?', '["Küçük bir araba kadar", "Futbol topu kadar", "Uçak kanadı kadar"]'::jsonb, 0),
('Ahtapotların Kanı', 'Ahtapotların kanı demir yerine bakır bazlı hemosiyanin içerdiği için mavidir!', 'science', 'Ahtapotların kanı neden mavidir?', '["Bakır içerdiği için", "Deniz suyu yuttukları için", "Mürekkep salgıladıkları için"]'::jsonb, 0),
('Venüs''te Bir Gün', 'Venüs kendi ekseni etrafında o kadar yavaş döner ki, bir günü bir yılından daha uzundur!', 'space', 'Venüs gezegeni için hangi bilgi doğrudur?', '["Günü yılından uzundur", "Güneşe en uzak gezegendir", "Üzerinde sıvı su bulunur"]'::jsonb, 0)
ON CONFLICT DO NOTHING;

INSERT INTO public.code_unlock_puzzles (title, description, language, code_snippets, correct_order, hint) VALUES
('Kediye Süt Ver Algoritması', 'Adımları mantıksal sıraya dizerek programı çalıştır!', 'scratch', '["Sütü kaba dök", "Kediyi çağır", "Kabı yere koy", "Afiyet olsun de"]'::jsonb, '[0, 2, 1, 3]'::jsonb, 'Önce sütü doldurmalı, sonra yere bırakmalısın.'),
('Döngü ile 5 Kere Zıpla', 'Python kodunu doğru sıraya yerleştir!', 'python', '["for i in range(5):", "    karakter.zipla()", "print(\"Tebrikler!\")"]'::jsonb, '[0, 1, 2]'::jsonb, 'Döngü başlığı en başta olmalıdır.')
ON CONFLICT DO NOTHING;

INSERT INTO public.micro_debates (topic, category, pro_argument, con_argument) VALUES
('Yapay Zeka Gelecekte İnsanların Tüm Mesleklerini Elinden Alabilir mi?', 'technology', 'Yapay zeka çok hızlı öğreniyor ve tekrarlı işleri kusursuz yapıyor.', 'İnsanların empati, yaratıcılık ve duygusal zekasını makineler asla tam kopyalayamaz.')
ON CONFLICT DO NOTHING;

INSERT INTO public.micro_experiments (title, duration_minutes, materials, steps, scientific_explanation) VALUES
('Dans Eden Mısırlar', 5, '["Bir bardak su", "1 çay kaşığı karbonat", "1 kaşık sirke", "Birkaç mısır tanesi"]'::jsonb, '["Suya karbonatı ekle ve karıştır.", "Mısır tanelerini içine at.", "Sirkeyi yavaşça dök ve kabarcıkları izle!"]'::jsonb, 'Sirke ve karbonat tepkimeye girerek karbondioksit gazı üretir. Gaz kabarcıkları mısırlara yapışıp onları yukarı taşır.')
ON CONFLICT DO NOTHING;

INSERT INTO public.future_career_badges (title, icon, field, required_subject, required_questions, description) VALUES
('Yapay Zeka Etik Uzmanı', '🤖', 'Bilişim & Felsefe', 'matematik', 60, 'Algoritmaların adil ve insan odaklı çalışmasını denetleyen gelecek lideri.'),
('Biyo-Mühendis', '🧬', 'Sağlık & Genetik', 'fen', 50, 'Canlı hücreleri ve genleri insanlık yararına tasarlayan bilim insanı.'),
('Uzay Trafik Kontrolörü', '🚀', 'Havacılık & Astronomi', 'fizik', 50, 'Yörüngedeki uyduların ve roketlerin güvenli rotalarını belirleyen uzman.')
ON CONFLICT DO NOTHING;

-- 8. İZİNLER
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
