export type UserRole = 'parent' | 'child';

export type UserMood = 'happy' | 'tired' | 'excited' | 'angry';

export type StudentState =
  | 'FREE_TIME'
  | 'STUDY_TIME'
  | 'BREAK_TIME'
  | 'ROUTINE_TIME'
  | 'SLEEP_TIME'
  | 'WAKE_UP_ALARM'
  | 'COMPUTER_STUDY'
  | 'GUEST_MODE'
  | 'FROZEN_HOLIDAY'
  | 'CO_STUDY_MODE';

export type DevicePlatform = 'windows_pc' | 'ios_phone' | 'tablet';

export type TaskCategory =
  | 'routine_morning'
  | 'routine_evening'
  | 'academic'
  | 'chore'
  | 'flash_quest'
  | 'coop';

export type TaskVerificationType =
  | 'photo_optional'
  | 'physical_check'
  | 'direct_submit'
  | 'qr_scan';

export type TaskSubmissionMethod =
  | 'photo_uploaded'
  | 'called_parent_for_check'
  | 'just_marked_done'
  | 'qr_scanned';

export type TaskProposalStatus =
  | 'approved'
  | 'pending_parent_approval'
  | 'rejected';

export type ApprovalStatus = 'pending' | 'approved' | 'rejected';

export type AppealStatus = 'pending' | 'accepted' | 'rejected';

export interface AppealRecord {
  id: string;
  family_id: string;
  user_id: string;
  violation_id?: string | null;
  submission_id?: string | null;
  reason_text: string;
  audio_url?: string | null;
  status: AppealStatus;
  reviewed_by?: string | null;
  created_at: string;
}

export interface WeeklyInterviewRecord {
  id: string;
  family_id: string;
  user_id: string;
  week_start_date: string;
  question_text: string;
  audio_url?: string | null;
  answer_note?: string | null;
  created_at: string;
}

export type RewardTier = 'micro' | 'medium' | 'large' | 'parent_challenge';

export type MessageType = 'text' | 'audio' | 'quick_request';

export type ViolationType =
  | 'pc_mouse_move'
  | 'pc_key_press'
  | 'ios_touch_detected'
  | 'ios_app_minimized'
  | 'agent_offline'
  | 'unauthorized_app_opened'
  | 'clock_tamper_attempt'
  | 'high_noise_detected'
  | 'watchdog_agent_restarted';

export type CompanionType = 'dragon' | 'robot' | 'cat' | 'alien';

export interface CompanionConfig {
  type: CompanionType;
  name: string;
  xp: number;
  level: number;
  evolution_stage: number; // 1: Yumurta, 2: Bebek, 3: Genç, 4: Efsanevi Evrim
  hunger: number; // 0-100
  energy: number; // 0-100
}

export interface SchoolScheduleLesson {
  period: number; // 1-8
  name: string; // e.g. "Matematik", "Türkçe"
  room?: string;
}

export interface SchoolScheduleItem {
  id: string;
  family_id: string;
  user_id: string;
  day_of_week: number; // 1: Pazartesi ... 7: Pazar
  lessons?: SchoolScheduleLesson[];
  extra_materials?: string[];
  has_pe_class?: boolean;
  has_art_class?: boolean;
  custom_items_to_pack?: string[];
  reminder_note?: string;
  updated_at?: string;
}

export type AlarmScheduleType =
  | 'wake_up'
  | 'study_start'
  | 'break_start'
  | 'break_end'
  | 'sleep';

export type QRStationLinkedAction =
  | 'dismiss_wake_up_alarm'
  | 'start_tooth_brushing'
  | 'complete_task';

export interface WhitelistConfig {
  allowed_exes: string[];
  allowed_keywords: string[];
}

export interface FamilyAccount {
  id: string;
  name: string;
  family_name?: string;
  owner_auth_id?: string | null;
  family_invite_token?: string;
  family_code: string;
  parent_pin: string;
  subscription_tier: 'free' | 'pro';
  created_at?: string;
}

export interface FamilySettings {
  id: string;
  family_id: string;
  family_chest_goal: number;
  family_chest_current: number;
  family_chest_reward_title: string;
  offline_master_pin_hash: string;
  city_lat?: number;
  city_lon?: number;
  noise_threshold_db?: number;
  autopilot_until?: string | null;
  happy_hour_discount_percent?: number;
  happy_hour_ends_at?: string | null;
  tts_announcements_enabled?: boolean;
  latest_agent_version?: string;
  agent_download_url?: string;
  agent_release_notes?: string;
  updated_at?: string;
}

export interface QRStation {
  id: string;
  family_id: string;
  station_code: string;
  title: string;
  linked_action: QRStationLinkedAction;
  created_at?: string;
}

export interface PointTransfer {
  id: string;
  family_id: string;
  sender_child_id: string;
  receiver_child_id: string;
  amount: number;
  message: string;
  created_at: string;
}

export interface AvatarConfig {
  emoji: string;
  bg: string;
  ageGroup: 'kid' | 'preteen' | 'teen' | 'adult';
  grade?: string;
  accentColor?: string;
}

export interface UserProfile {
  id: string;
  family_id: string;
  name: string;
  role: UserRole;
  username?: string;
  access_password?: string;
  magic_login_token?: string;
  desktop_pairing_code?: string;
  avatar_config: AvatarConfig;
  theme: 'cosmic-explorer' | 'candy-pop' | 'cyber-academy' | 'parent-command';
  points_balance: number;
  piggy_bank_balance: number;
  daily_shields: number; // Default 3
  streak_days: number;
  wheel_spins_available: number;
  current_mood: UserMood;
  current_state: StudentState;
  state_ends_at: string | null;
  whitelist_config?: WhitelistConfig;
  badges?: string[];
  companion_config?: CompanionConfig;
  grace_used_today?: boolean;
  appeal_used_today?: boolean;
}

export interface DeviceRecord {
  id: string;
  family_id: string;
  user_id: string;
  device_name: string;
  device_type: DevicePlatform;
  is_online: boolean;
  last_heartbeat: string;
  last_activity_at: string;
  active_window_title: string;
}

export interface TaskItem {
  id: string;
  family_id: string;
  assigned_to: string; // user_id or 'both'
  title: string;
  description: string;
  category: TaskCategory;
  points: number;
  verification_type: TaskVerificationType;
  requires_photo?: boolean;
  duration_minutes: number;
  is_active: boolean;
  due_time: string;
  created_by?: string;
  proposal_status?: TaskProposalStatus;
  required_qr_station_id?: string | null;
  is_first_come_race?: boolean;
  claimed_by?: string | null;
  claimed_at?: string | null;
}

export interface TaskSubmission {
  id: string;
  family_id: string;
  task_id: string;
  user_id: string;
  submission_method: TaskSubmissionMethod;
  status: ApprovalStatus;
  photo_urls: string[];
  approved_by: string | null;
  is_featured_in_album?: boolean;
  parent_praise_note?: string | null;
  is_optimistic_approved?: boolean;
  created_at: string;
}

export interface RewardAutoAction {
  type: 'unlock_screen' | 'custom_perk';
  minutes?: number;
}

export interface RewardItem {
  id: string;
  family_id: string;
  title: string;
  cost_points: number;
  tier: RewardTier;
  auto_action: RewardAutoAction | null;
  icon: string;
}

export interface RewardRedemption {
  id: string;
  family_id: string;
  reward_id: string;
  user_id: string;
  status: ApprovalStatus;
  approved_by: string | null;
  created_at: string;
}

export interface DirectMessage {
  id: string;
  family_id: string;
  sender_id: string;
  receiver_id: string;
  message_type: MessageType;
  content: string;
  audio_url?: string | null;
  is_read: boolean;
  created_at: string;
}

export interface ViolationLog {
  id: string;
  family_id: string;
  user_id: string;
  device_id: string;
  violation_type: ViolationType;
  created_at: string;
}

export interface AlarmSchedule {
  id: string;
  family_id: string;
  user_id: string;
  type: AlarmScheduleType;
  time: string; // HH:mm
  days_of_week: number[];
  sound_theme: string;
  is_enabled: boolean;
  require_qr_station_id?: string | null;
}
