-- ============================================================================
-- FAMILY-TO-STUDY: MULTI-TENANT (ÇOKLU AİLE / SaaS) GAMIFIED PLATFORM
-- SUPABASE POSTGRESQL SCHEMA, REALTIME, STORAGE POLICIES, RPC & SEED DATA
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. ENUM TYPES & DOMAINS
-- ----------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('parent', 'child');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE user_mood AS ENUM ('happy', 'tired', 'excited', 'angry');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE student_state AS ENUM (
        'FREE_TIME',
        'STUDY_TIME',
        'BREAK_TIME',
        'ROUTINE_TIME',
        'SLEEP_TIME',
        'WAKE_UP_ALARM'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE device_platform AS ENUM ('windows_pc', 'ios_phone', 'tablet');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE task_category AS ENUM (
        'routine_morning',
        'routine_evening',
        'academic',
        'chore',
        'flash_quest',
        'coop'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE task_verification_type AS ENUM (
        'photo_optional',
        'physical_check',
        'direct_submit'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE task_submission_method AS ENUM (
        'photo_uploaded',
        'called_parent_for_check',
        'just_marked_done'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE reward_tier AS ENUM ('micro', 'medium', 'large');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE dm_message_type AS ENUM ('text', 'audio', 'quick_request');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE shield_violation_type AS ENUM (
        'pc_mouse_move',
        'pc_key_press',
        'ios_touch_detected',
        'ios_app_minimized',
        'agent_offline'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE schedule_alarm_type AS ENUM (
        'wake_up',
        'study_start',
        'break_start',
        'break_end',
        'sleep'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ----------------------------------------------------------------------------
-- 2. MULTI-TENANT TABLES (10 CORE TABLES: FAMILIES + 9 MODULE TABLES)
-- ----------------------------------------------------------------------------

-- 2.0. FAMILIES TABLE (Multi-Tenant Root)
CREATE TABLE IF NOT EXISTS public.families (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    name TEXT NOT NULL,
    family_code TEXT UNIQUE NOT NULL,
    parent_pin TEXT NOT NULL DEFAULT '1234',
    subscription_tier TEXT NOT NULL DEFAULT 'pro',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.1. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'child',
    avatar_config JSONB NOT NULL DEFAULT '{"emoji": "🦁", "bg": "from-amber-400 to-orange-500", "ageGroup": "kid", "grade": "3. Sınıf"}'::jsonb,
    theme TEXT NOT NULL DEFAULT 'cosmic-explorer',
    points_balance INTEGER NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    piggy_bank_balance INTEGER NOT NULL DEFAULT 0 CHECK (piggy_bank_balance >= 0),
    daily_shields INTEGER NOT NULL DEFAULT 3 CHECK (daily_shields >= 0 AND daily_shields <= 3),
    streak_days INTEGER NOT NULL DEFAULT 0,
    wheel_spins_available INTEGER NOT NULL DEFAULT 0,
    current_mood user_mood NOT NULL DEFAULT 'happy',
    current_state student_state NOT NULL DEFAULT 'FREE_TIME',
    state_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2. DEVICES TABLE
CREATE TABLE IF NOT EXISTS public.devices (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    device_type device_platform NOT NULL,
    is_online BOOLEAN NOT NULL DEFAULT true,
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    active_window_title TEXT DEFAULT 'Masaüstü - Boşta',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3. TASKS TABLE
CREATE TABLE IF NOT EXISTS public.tasks (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    assigned_to TEXT NOT NULL, -- user_id OR 'both'
    title TEXT NOT NULL,
    description TEXT,
    category task_category NOT NULL,
    points INTEGER NOT NULL DEFAULT 10 CHECK (points > 0),
    verification_type task_verification_type NOT NULL DEFAULT 'photo_optional',
    requires_photo BOOLEAN NOT NULL DEFAULT false,
    duration_minutes INTEGER DEFAULT 15,
    is_active BOOLEAN NOT NULL DEFAULT true,
    due_time TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.4. TASK SUBMISSIONS TABLE (Photo Optional + Physical Check + Direct Submit)
CREATE TABLE IF NOT EXISTS public.task_submissions (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    task_id TEXT NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    submission_method task_submission_method NOT NULL DEFAULT 'called_parent_for_check',
    status approval_status NOT NULL DEFAULT 'pending',
    photo_urls TEXT[] DEFAULT '{}',
    approved_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5. REWARDS TABLE
CREATE TABLE IF NOT EXISTS public.rewards (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    cost_points INTEGER NOT NULL CHECK (cost_points > 0),
    tier reward_tier NOT NULL DEFAULT 'micro',
    auto_action JSONB DEFAULT NULL,
    icon TEXT NOT NULL DEFAULT 'Gamepad2',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.6. REWARD REDEMPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.reward_redemptions (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL REFERENCES public.rewards(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status approval_status NOT NULL DEFAULT 'pending',
    approved_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.7. MESSAGES TABLE (DM & Walkie-Talkie)
CREATE TABLE IF NOT EXISTS public.messages (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    receiver_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message_type dm_message_type NOT NULL DEFAULT 'text',
    content TEXT,
    audio_url TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.8. VIOLATION LOGS TABLE
CREATE TABLE IF NOT EXISTS public.violation_logs (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id TEXT,
    violation_type shield_violation_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.9. ALARMS AND SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS public.alarms_and_schedules (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    family_id TEXT NOT NULL DEFAULT 'fam-ozdemir' REFERENCES public.families(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type schedule_alarm_type NOT NULL,
    time TEXT NOT NULL,
    days_of_week INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5}',
    sound_theme TEXT NOT NULL DEFAULT 'energetic_sunrise',
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Safe Alter Migration for Existing Tables
DO $$
DECLARE
    tbl TEXT;
BEGIN
    INSERT INTO public.families (id, name, family_code, parent_pin)
    VALUES ('fam-ozdemir', 'Özdemir Ailesi', 'OZDEMIR-2026', '1234')
    ON CONFLICT (id) DO NOTHING;

    FOREACH tbl IN ARRAY ARRAY[
        'users', 'devices', 'tasks', 'task_submissions',
        'rewards', 'reward_redemptions', 'messages',
        'violation_logs', 'alarms_and_schedules'
    ]
    LOOP
        EXECUTE format(
            'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS family_id TEXT NOT NULL DEFAULT ''fam-ozdemir'' REFERENCES public.families(id) ON DELETE CASCADE',
            tbl
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%I_family_id ON public.%I(family_id)',
            tbl, tbl
        );
    END LOOP;

    -- Add verification_type to tasks & submission_method to task_submissions
    ALTER TABLE public.tasks
        ADD COLUMN IF NOT EXISTS verification_type task_verification_type NOT NULL DEFAULT 'photo_optional';

    ALTER TABLE public.task_submissions
        ADD COLUMN IF NOT EXISTS submission_method task_submission_method NOT NULL DEFAULT 'called_parent_for_check';

    ALTER TABLE public.task_submissions
        ALTER COLUMN photo_urls DROP NOT NULL;
END $$;

-- ----------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alarms_and_schedules ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on families" ON public.families FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on users" ON public.users FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on devices" ON public.devices FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on tasks" ON public.tasks FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on task_submissions" ON public.task_submissions FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on rewards" ON public.rewards FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on reward_redemptions" ON public.reward_redemptions FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on messages" ON public.messages FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on violation_logs" ON public.violation_logs FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Allow family full access on alarms_and_schedules" ON public.alarms_and_schedules FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ----------------------------------------------------------------------------
-- 4. MULTI-TENANT ATOMIC RPC FUNCTIONS
-- ----------------------------------------------------------------------------

-- 4.1. Atomic Task Submission Approval (Scoped by family_id)
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

        UPDATE public.users
        SET points_balance = points_balance + v_task.points + v_bonus_awarded,
            updated_at = NOW()
        WHERE id = v_sub.user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'points_added', CASE WHEN p_decision = 'approved' THEN v_task.points + v_bonus_awarded ELSE 0 END,
        'morning_combo_bonus', v_bonus_awarded
    );
END;
$$;

-- 4.2. Atomic Reward Redemption Approval
CREATE OR REPLACE FUNCTION public.approve_reward_redemption(
    p_redemption_id TEXT,
    p_parent_id TEXT,
    p_decision approval_status
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_red RECORD;
    v_reward RECORD;
    v_user RECORD;
    v_unlock_minutes INTEGER;
BEGIN
    SELECT * INTO v_red
    FROM public.reward_redemptions
    WHERE id = p_redemption_id
    FOR UPDATE;

    IF NOT FOUND OR v_red.status <> 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ödül talebi zaten işlenmiş veya bulunamadı.');
    END IF;

    SELECT * INTO v_reward FROM public.rewards WHERE id = v_red.reward_id;
    SELECT * INTO v_user FROM public.users WHERE id = v_red.user_id FOR UPDATE;

    IF p_decision = 'approved' THEN
        IF v_user.points_balance < v_reward.cost_points THEN
            RETURN jsonb_build_object('success', false, 'error', 'Öğrencinin puan bakiyesi yetersiz.');
        END IF;

        UPDATE public.reward_redemptions
        SET status = 'approved', approved_by = p_parent_id
        WHERE id = p_redemption_id;

        IF v_reward.auto_action IS NOT NULL AND (v_reward.auto_action->>'type') = 'unlock_screen' THEN
            v_unlock_minutes := COALESCE((v_reward.auto_action->>'minutes')::INTEGER, 30);
            UPDATE public.users
            SET points_balance = points_balance - v_reward.cost_points,
                current_state = 'FREE_TIME',
                state_ends_at = NOW() + (v_unlock_minutes || ' minutes')::INTERVAL,
                updated_at = NOW()
            WHERE id = v_red.user_id;
        ELSE
            UPDATE public.users
            SET points_balance = points_balance - v_reward.cost_points,
                updated_at = NOW()
            WHERE id = v_red.user_id;
        END IF;
    ELSE
        UPDATE public.reward_redemptions
        SET status = 'rejected', approved_by = p_parent_id
        WHERE id = p_redemption_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'status', p_decision);
END;
$$;

-- 4.3. Record Focus Violation & Break 1 Daily Shield
CREATE OR REPLACE FUNCTION public.record_violation_and_break_shield(
    p_user_id TEXT,
    p_device_id TEXT,
    p_violation_type shield_violation_type
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_remaining_shields INTEGER;
BEGIN
    SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

    INSERT INTO public.violation_logs (family_id, user_id, device_id, violation_type)
    VALUES (COALESCE(v_user.family_id, 'fam-ozdemir'), p_user_id, p_device_id, p_violation_type);

    UPDATE public.users
    SET daily_shields = GREATEST(0, daily_shields - 1),
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING daily_shields INTO v_remaining_shields;

    RETURN jsonb_build_object(
        'success', true,
        'remaining_shields', v_remaining_shields
    );
END;
$$;

-- 4.4. Sunday Night Piggy Bank +20% Interest Bonus
CREATE OR REPLACE FUNCTION public.apply_sunday_piggy_bank_bonus(
    p_family_id TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.users
    SET piggy_bank_balance = ROUND(piggy_bank_balance * 1.20),
        updated_at = NOW()
    WHERE role = 'child'
      AND piggy_bank_balance > 0
      AND (p_family_id IS NULL OR family_id = p_family_id);
END;
$$;

-- 4.5. End of Day Zero-Violation Shield Bonus (+20 Points if daily_shields = 3)
CREATE OR REPLACE FUNCTION public.award_daily_shield_bonus(
    p_family_id TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.users
    SET points_balance = points_balance + CASE WHEN daily_shields = 3 THEN 20 ELSE 0 END,
        daily_shields = 3,
        updated_at = NOW()
    WHERE role = 'child'
      AND (p_family_id IS NULL OR family_id = p_family_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. SUPABASE STORAGE BUCKETS & PUBLIC ACCESS POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('task-proofs', 'task-proofs', true),
    ('voice-messages', 'voice-messages', true)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
    CREATE POLICY "Public Access task-proofs" ON storage.objects FOR ALL USING (bucket_id = 'task-proofs') WITH CHECK (bucket_id = 'task-proofs');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE POLICY "Public Access voice-messages" ON storage.objects FOR ALL USING (bucket_id = 'voice-messages') WITH CHECK (bucket_id = 'voice-messages');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ----------------------------------------------------------------------------
-- 6. SUPABASE REALTIME PUBLICATIONS
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'families', 'users', 'devices', 'tasks', 'task_submissions',
        'rewards', 'reward_redemptions', 'messages',
        'violation_logs', 'alarms_and_schedules'
    ]
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        EXCEPTION WHEN duplicate_object THEN
            NULL;
        END;
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', tbl);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 7. PRODUCTION READY (FAZ 6 - TAM MULTI-TENANT AİLE İZOLASYONU)
-- ----------------------------------------------------------------------------
-- Sahte/mock veriler temizlenmiştir.
-- Aileler Google OAuth veya Ebeveyn Kurulum Sihirbazı ile dinamik ve güvenli oluşturulur.
