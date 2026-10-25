-- ==============================================================================
-- PHASE 5 MIGRATION: WATCHDOG, OTA AUTO-UPDATER, CO-STUDY & RECURRING TASKS
-- ==============================================================================

-- 1. ENUM GÜNCELLEMELERİ
ALTER TYPE student_state ADD VALUE IF NOT EXISTS 'CO_STUDY_MODE';
ALTER TYPE shield_violation_type ADD VALUE IF NOT EXISTS 'watchdog_agent_restarted';

-- 2. FAMILY_SETTINGS SÜTUN EKLEMELERİ (OTA Versiyon & İndirme Bilgileri)
ALTER TABLE public.family_settings
ADD COLUMN IF NOT EXISTS latest_agent_version TEXT DEFAULT '1.0.0';

ALTER TABLE public.family_settings
ADD COLUMN IF NOT EXISTS agent_download_url TEXT;

ALTER TABLE public.family_settings
ADD COLUMN IF NOT EXISTS agent_release_notes TEXT;

-- 3. GÜNLÜK OTOMATİK GÖREV VE KALKAN ÜRETİMİ (spawn_daily_recurring_tasks RPC)
CREATE OR REPLACE FUNCTION public.spawn_daily_recurring_tasks(
    p_family_id TEXT DEFAULT 'fam-ozdemir'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today_str TEXT := TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD');
    v_tasks_created INT := 0;
    v_user RECORD;
BEGIN
    -- 1. Tüm çocukların günlük kalkanlarını (3) ve jokerlerini (uzatma/itiraz) sıfırla
    UPDATE public.users
    SET 
        daily_shields = 3,
        grace_used_today = false,
        appeal_used_today = false
    WHERE family_id = p_family_id AND role = 'child';

    -- 2. Her çocuk için günlük temel rutin görevlerin aktif ve mevcut olduğundan emin ol
    FOR v_user IN 
        SELECT id, name FROM public.users WHERE family_id = p_family_id AND role = 'child'
    LOOP
        -- Diş Fırçalama (Sabah)
        IF NOT EXISTS (
            SELECT 1 FROM public.tasks 
            WHERE family_id = p_family_id 
              AND (assigned_to = v_user.id OR assigned_to = 'both')
              AND title ILIKE '%Diş Fırçalama%'
              AND is_active = true
        ) THEN
            INSERT INTO public.tasks (
                id, family_id, assigned_to, title, description, category,
                points, verification_type, requires_photo, duration_minutes, is_active
            ) VALUES (
                'task-daily-tooth-' || v_user.id || '-' || v_today_str,
                p_family_id,
                v_user.id,
                '🪥 Sabah Diş Fırçalama & Yüz Yıkama',
                'Güne taze ve temiz başla! En az 2 dakika dişlerini fırçala.',
                'routine_morning',
                15,
                'photo_optional',
                false,
                5,
                true
            );
            v_tasks_created := v_tasks_created + 1;
        END IF;

        -- Yatak Toplama & Oda Düzeni
        IF NOT EXISTS (
            SELECT 1 FROM public.tasks 
            WHERE family_id = p_family_id 
              AND (assigned_to = v_user.id OR assigned_to = 'both')
              AND title ILIKE '%Yatak Toplama%'
              AND is_active = true
        ) THEN
            INSERT INTO public.tasks (
                id, family_id, assigned_to, title, description, category,
                points, verification_type, requires_photo, duration_minutes, is_active
            ) VALUES (
                'task-daily-bed-' || v_user.id || '-' || v_today_str,
                p_family_id,
                v_user.id,
                '🛏️ Yatak Toplama & Odayı Havalandırma',
                'Yatağını düzelt ve odanın penceresini 5 dakika aç.',
                'routine_morning',
                15,
                'photo_optional',
                false,
                5,
                true
            );
            v_tasks_created := v_tasks_created + 1;
        END IF;

        -- Günlük Kitap Okuma
        IF NOT EXISTS (
            SELECT 1 FROM public.tasks 
            WHERE family_id = p_family_id 
              AND (assigned_to = v_user.id OR assigned_to = 'both')
              AND title ILIKE '%Kitap Okuma%'
              AND is_active = true
        ) THEN
            INSERT INTO public.tasks (
                id, family_id, assigned_to, title, description, category,
                points, verification_type, requires_photo, duration_minutes, is_active
            ) VALUES (
                'task-daily-book-' || v_user.id || '-' || v_today_str,
                p_family_id,
                v_user.id,
                '📚 25 Sayfa Kitap Okuma',
                'Sessiz bir köşede sevdiğin kitaptan 25 sayfa oku.',
                'academic',
                30,
                'physical_check',
                false,
                25,
                true
            );
            v_tasks_created := v_tasks_created + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'family_id', p_family_id,
        'date', v_today_str,
        'tasks_created', v_tasks_created,
        'message', 'Günlük rutin görevler ve 3 kalkan başarıyla üretildi/doğrulandı.'
    );
END;
$$;
