'use client';

import React, {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  useRef,
  useMemo,
} from 'react';
import {
  FamilyAccount,
  FamilySettings,
  QRStation,
  QRStationLinkedAction,
  PointTransfer,
  SchoolScheduleItem,
  AppealRecord,
  WeeklyInterviewRecord,
  CompanionConfig,
  WhitelistConfig,
  UserProfile,
  DeviceRecord,
  TaskItem,
  TaskSubmission,
  RewardItem,
  RewardRedemption,
  DirectMessage,
  ViolationLog,
  AlarmSchedule,
  StudentState,
  UserMood,
  ViolationType,
  DevicePlatform,
  TaskCategory,
  TaskVerificationType,
  TaskSubmissionMethod,
  RewardTier,
} from '@/types/database';
import {
  INITIAL_FAMILIES,
  INITIAL_FAMILY_SETTINGS,
  INITIAL_QR_STATIONS,
  INITIAL_POINT_TRANSFERS,
  INITIAL_SCHOOL_SCHEDULES,
  INITIAL_APPEALS,
  INITIAL_WEEKLY_INTERVIEWS,
  INITIAL_USERS,
  INITIAL_DEVICES,
  INITIAL_TASKS,
  INITIAL_REWARDS,
  INITIAL_SUBMISSIONS,
  INITIAL_REDEMPTIONS,
  INITIAL_MESSAGES,
  INITIAL_VIOLATIONS,
  INITIAL_ALARMS,
} from '@/lib/seedData';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';
import { soundEngine } from '@/lib/soundEngine';
import { useServerTime, computeSha256Hex } from '@/hooks/useServerTime';
import { speakTurkishAnnouncement } from '@/lib/ttsAnnouncer';
import {
  getPersistentSession,
  sealPersistentSession,
  clearPersistentSession,
} from '@/lib/sessionStorage';

export interface LiveAlertBanner {
  id: string;
  family_id: string;
  type: 'violation' | 'wakeup' | 'approval' | 'flash_quest' | 'info';
  title: string;
  message: string;
  timestamp: string;
}

interface SharedMultiTenantState {
  families: FamilyAccount[];
  familySettings: FamilySettings[];
  qrStations: QRStation[];
  pointTransfers: PointTransfer[];
  schoolSchedules: SchoolScheduleItem[];
  appeals: AppealRecord[];
  weeklyInterviews: WeeklyInterviewRecord[];
  users: UserProfile[];
  devices: DeviceRecord[];
  tasks: TaskItem[];
  submissions: TaskSubmission[];
  rewards: RewardItem[];
  redemptions: RewardRedemption[];
  messages: DirectMessage[];
  violations: ViolationLog[];
  alarms: AlarmSchedule[];
}

interface FamilyRealtimeContextValue {
  isAuthenticated: boolean;
  sessionLoading: boolean;
  wizardOpen: boolean;
  wizardOwnerEmail: string | null;
  setWizardOpen: (open: boolean) => void;
  createFamilyWizard: (params: {
    familyName: string;
    parentPin: string;
    members: Array<{
      name: string;
      role: 'parent' | 'child';
      grade: string;
      ageGroup: 'kid' | 'preteen' | 'teen' | 'adult';
      emoji: string;
    }>;
  }) => Promise<{ success: boolean; message: string }>;
  regenerateDesktopPairingCode: (userId: string) => Promise<string>;
  logout: () => Promise<void>;
  loginSuccessWithUser: (userId: string, familyId: string) => Promise<void>;

  families: FamilyAccount[];
  activeFamily: FamilyAccount;
  familySettings: FamilySettings;
  qrStations: QRStation[];
  pointTransfers: PointTransfer[];
  schoolSchedules: SchoolScheduleItem[];
  appeals: AppealRecord[];
  weeklyInterviews: WeeklyInterviewRecord[];
  activeHappyHourDiscountPercent: number;
  lastRestoredShieldStudentId: string | null;
  clearRestoredShieldCelebration: () => void;
  serverTimeOffset: number;
  switchFamilyById: (familyId: string) => void;
  switchFamilyByCode: (familyCode: string) => { success: boolean; message: string };
  createNewFamily: (params: {
    name: string;
    familyCode: string;
    parentPin: string;
    momName: string;
    dadName: string;
  }) => Promise<{ success: boolean; message: string }>;

  users: UserProfile[];
  devices: DeviceRecord[];
  tasks: TaskItem[];
  submissions: TaskSubmission[];
  rewards: RewardItem[];
  redemptions: RewardRedemption[];
  messages: DirectMessage[];
  violations: ViolationLog[];
  alarms: AlarmSchedule[];

  activeUser: UserProfile;
  activeDeviceType: DevicePlatform;
  setActiveUserById: (userId: string) => void;
  setActiveDeviceType: (platform: DevicePlatform) => void;
  remainingSecondsByUser: Record<string, number>;
  liveAlerts: LiveAlertBanner[];
  dismissAlert: (id: string) => void;
  isLiveSupabase: boolean;

  addChildToFamily: (params: {
    name: string;
    grade: string;
    ageGroup: 'kid' | 'preteen' | 'teen';
    emoji: string;
  }) => Promise<void>;
  addParentToFamily: (params: {
    name: string;
    roleTitle?: string;
  }) => Promise<{ success: boolean; user?: UserProfile; message: string }>;
  updateFamilyMember: (params: {
    userId: string;
    name: string;
    grade?: string;
    ageGroup?: 'kid' | 'preteen' | 'teen';
    emoji?: string;
    accessPassword?: string;
  }) => Promise<{ success: boolean; message: string }>;
  deleteFamilyMember: (
    userId: string
  ) => Promise<{ success: boolean; message: string }>;
  regenerateMemberCredentials: (userId: string) => Promise<{
    success: boolean;
    newPassword?: string;
    newMagicToken?: string;
    newPairingCode?: string;
    message: string;
  }>;
  addTaskToFamily: (params: {
    assignedTo: string;
    title: string;
    description: string;
    category: TaskCategory;
    points: number;
    verificationType: TaskVerificationType;
    dueTime: string;
    requiredQrStationId?: string | null;
    isFirstComeRace?: boolean;
  }) => Promise<void>;
  addRewardToFamily: (params: {
    title: string;
    costPoints: number;
    tier: RewardTier;
    unlockMinutes?: number | null;
  }) => Promise<void>;

  proposeTaskByStudent: (params: {
    studentId: string;
    title: string;
    description: string;
    requestedPoints: number;
  }) => Promise<void>;
  reviewTaskProposal: (
    taskId: string,
    decision: 'approved' | 'rejected'
  ) => Promise<void>;

  transferPointsBetweenSiblings: (
    senderId: string,
    receiverId: string,
    amount: number,
    message: string
  ) => Promise<{
    success: boolean;
    message: string;
    awardedGoldenHeart: boolean;
  }>;

  addQRStation: (params: {
    stationCode: string;
    title: string;
    linkedAction: QRStationLinkedAction;
  }) => Promise<void>;

  updateStudentWhitelist: (
    studentId: string,
    whitelistConfig: WhitelistConfig
  ) => Promise<void>;

  updateFamilyChestConfig: (params: {
    goal: number;
    rewardTitle: string;
  }) => Promise<void>;

  updateOfflineMasterPin: (rawSixDigitPin: string) => Promise<void>;
  unlockWithOfflineMasterPin: (
    studentId: string,
    enteredSixDigitPin: string
  ) => Promise<{ success: boolean; message: string }>;

  // Phase 3 Methods
  useGracePeriodExtension: (
    studentId: string
  ) => Promise<{ success: boolean; message: string }>;
  voluntaryEarlyLockRefund: (
    studentId: string
  ) => Promise<{ success: boolean; message: string }>;
  awardHealthPoints: (
    studentId: string,
    points: number,
    reason: string
  ) => Promise<void>;
  updateCompanionConfig: (
    studentId: string,
    updates: Partial<CompanionConfig>
  ) => Promise<void>;
  upsertSchoolSchedule: (
    schedule: Omit<SchoolScheduleItem, 'id' | 'family_id'>
  ) => Promise<void>;
  updateFamilyWeatherAndNoiseConfig: (params: {
    cityLat: number;
    cityLon: number;
    noiseThresholdDb: number;
  }) => Promise<void>;

  // Phase 4 Methods (Autopilot, Court of Appeals, Dynamic Economy, Active Break & Weekly Interview)
  submitAppeal: (params: {
    studentId: string;
    violationId?: string | null;
    submissionId?: string | null;
    reasonText: string;
    audioUrl?: string | null;
  }) => Promise<{ success: boolean; message: string }>;
  resolveAppeal: (
    appealId: string,
    parentId: string,
    decision: 'accepted' | 'rejected'
  ) => Promise<{
    success: boolean;
    message: string;
    shieldRestored: boolean;
  }>;
  claimRaceTaskAtomic: (
    taskId: string,
    studentId: string
  ) => Promise<{ success: boolean; message: string }>;
  setParentAutopilot: (hours: number | null) => Promise<void>;
  finalizeAllOptimisticApprovals: () => Promise<void>;
  revertOptimisticApproval: (
    submissionId: string
  ) => Promise<{ success: boolean; message: string }>;
  startHappyHourDiscount: (
    discountPercent: number,
    durationMinutes?: number
  ) => Promise<void>;
  toggleTTSAnnouncements: (enabled: boolean) => Promise<void>;
  completeActiveBreakChallenge: (
    studentId: string,
    challengeTitle: string
  ) => Promise<void>;
  saveWeeklyInterview: (params: {
    studentId: string;
    questionText: string;
    audioUrl?: string | null;
    answerNote?: string | null;
  }) => Promise<{ success: boolean; message: string }>;

  setStudentState: (
    studentId: string,
    newState: StudentState,
    durationMinutes?: number | null
  ) => Promise<void>;
  addBonusTimeMinutes: (studentId: string, extraMinutes: number) => Promise<void>;
  updateStudentMood: (studentId: string, mood: UserMood) => Promise<void>;

  submitTaskCompletion: (
    taskId: string,
    studentId: string,
    photoUrls: string[],
    submissionMethod?: TaskSubmissionMethod
  ) => Promise<{
    autoApproved: boolean;
    morningComboBonus: number;
    submissionId: string;
  }>;
  approveOrRejectSubmission: (
    submissionId: string,
    parentId: string,
    decision: 'approved' | 'rejected',
    options?: {
      featureInAlbum?: boolean;
      praiseNote?: string | null;
    }
  ) => Promise<{ success: boolean; message: string }>;
  approveTaskOnSpotWithPin: (
    submissionId: string,
    enteredPin: string
  ) => Promise<{ success: boolean; message: string }>;
  createFlashQuest: (
    assignedTo: string,
    title: string,
    points: number,
    durationMinutes: number,
    verificationType?: TaskVerificationType,
    isFirstComeRace?: boolean
  ) => Promise<void>;

  requestRewardRedemption: (
    rewardId: string,
    studentId: string
  ) => Promise<{ success: boolean; message: string }>;
  approveOrRejectRedemption: (
    redemptionId: string,
    parentId: string,
    decision: 'approved' | 'rejected'
  ) => Promise<{ success: boolean; message: string }>;
  depositToPiggyBank: (studentId: string, amount: number) => Promise<void>;
  triggerSundayPiggyBonus: () => Promise<void>;
  triggerDailyZeroViolationBonus: () => Promise<void>;
  spinLuckyWheel: (studentId: string) => Promise<{ label: string; bonusPoints: number }>;

  recordViolation: (
    studentId: string,
    violationType: ViolationType,
    customDeviceName?: string
  ) => Promise<void>;

  triggerWakeUpAlarm: (studentId: string) => Promise<void>;
  completeWakeUpChallenge: (studentId: string) => Promise<void>;

  sendDirectMessage: (
    senderId: string,
    receiverId: string,
    messageType: 'text' | 'audio' | 'quick_request',
    content: string,
    audioUrl?: string | null
  ) => Promise<void>;

  updateDeviceWindowTitle: (deviceId: string, windowTitle: string) => Promise<void>;
}

const STORAGE_KEY = 'family_to_study_multitenant_state_v3';
const ACTIVE_FAMILY_KEY = 'family_to_study_active_family_id_v3';
const BROADCAST_CHANNEL_NAME = 'family_to_study_realtime_sync_v3';

const FamilyRealtimeContext = createContext<FamilyRealtimeContextValue | null>(null);

export const FamilyRealtimeProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [state, setState] = useState<SharedMultiTenantState>({
    families: INITIAL_FAMILIES,
    familySettings: INITIAL_FAMILY_SETTINGS,
    qrStations: INITIAL_QR_STATIONS,
    pointTransfers: INITIAL_POINT_TRANSFERS,
    schoolSchedules: INITIAL_SCHOOL_SCHEDULES,
    appeals: INITIAL_APPEALS,
    weeklyInterviews: INITIAL_WEEKLY_INTERVIEWS,
    users: INITIAL_USERS,
    devices: INITIAL_DEVICES,
    tasks: INITIAL_TASKS,
    submissions: INITIAL_SUBMISSIONS,
    rewards: INITIAL_REWARDS,
    redemptions: INITIAL_REDEMPTIONS,
    messages: INITIAL_MESSAGES,
    violations: INITIAL_VIOLATIONS,
    alarms: INITIAL_ALARMS,
  });

  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [sessionLoading, setSessionLoading] = useState<boolean>(true);
  const [wizardOpen, setWizardOpen] = useState<boolean>(false);
  const [wizardOwnerEmail, setWizardOwnerEmail] = useState<string | null>(null);

  const [activeFamilyId, setActiveFamilyId] = useState<string>('');
  const [activeUserId, setActiveUserId] = useState<string>('');
  const [activeDeviceType, setActiveDeviceType] = useState<DevicePlatform>('tablet');
  const [remainingSecondsByUser, setRemainingSecondsByUser] = useState<Record<string, number>>({});
  const [liveAlerts, setLiveAlerts] = useState<LiveAlertBanner[]>([]);
  const [lastRestoredShieldStudentId, setLastRestoredShieldStudentId] =
    useState<string | null>(null);

  const clearRestoredShieldCelebration = useCallback(() => {
    setLastRestoredShieldStudentId(null);
  }, []);

  const broadcastRef = useRef<BroadcastChannel | null>(null);
  const stateRef = useRef<SharedMultiTenantState>(state);
  stateRef.current = state;

  const activeFamilyRef = useRef<string>(activeFamilyId);
  activeFamilyRef.current = activeFamilyId;

  const defaultEmptyFamily: FamilyAccount = useMemo(
    () => ({
      id: '',
      name: 'Aile Portalı',
      family_name: 'Aile Portalı',
      family_code: '',
      parent_pin: '1234',
      subscription_tier: 'pro',
    }),
    []
  );

  const defaultEmptySettings: FamilySettings = useMemo(
    () => ({
      id: 'fset-default',
      family_id: '',
      family_chest_goal: 1000,
      family_chest_current: 0,
      family_chest_reward_title: 'Aile Ödülü',
      offline_master_pin_hash:
        '8154e6b1b7e76c0155248914635c86b29a19a6136b110924b4ef7e2310293572',
      city_lat: 41.01,
      city_lon: 28.97,
      noise_threshold_db: 75,
      autopilot_until: null,
      happy_hour_discount_percent: 0,
      happy_hour_ends_at: null,
      tts_announcements_enabled: true,
    }),
    []
  );

  const defaultEmptyUser: UserProfile = useMemo(
    () => ({
      id: '',
      family_id: '',
      name: 'Giriş Yapılmadı',
      role: 'child',
      avatar_config: { emoji: '👤', bg: 'from-slate-700 to-slate-900', ageGroup: 'kid' },
      theme: 'cosmic-explorer',
      points_balance: 0,
      piggy_bank_balance: 0,
      daily_shields: 3,
      streak_days: 0,
      wheel_spins_available: 0,
      current_mood: 'happy',
      current_state: 'FREE_TIME',
      state_ends_at: null,
    }),
    []
  );

  const activeFamily = useMemo(
    () =>
      state.families.find((f) => f.id === activeFamilyId) ||
      state.families[0] ||
      defaultEmptyFamily,
    [state.families, activeFamilyId, defaultEmptyFamily]
  );

  // Scoped slices for the active family (Multi-Tenant Isolation)
  const familySettings = useMemo(() => {
    const found = (state.familySettings || []).find(
      (fs) => fs.family_id === activeFamily.id
    );
    return found || defaultEmptySettings;
  }, [state.familySettings, activeFamily.id, defaultEmptySettings]);

  const familyQrStations = useMemo(
    () =>
      (state.qrStations || []).filter(
        (q) => (q.family_id || 'fam-ozdemir') === activeFamily.id
      ),
    [state.qrStations, activeFamily.id]
  );

  const familyPointTransfers = useMemo(
    () =>
      (state.pointTransfers || []).filter(
        (pt) => (pt.family_id || 'fam-ozdemir') === activeFamily.id
      ),
    [state.pointTransfers, activeFamily.id]
  );

  const familySchoolSchedules = useMemo(
    () =>
      (state.schoolSchedules || INITIAL_SCHOOL_SCHEDULES).filter(
        (s) => (s.family_id || 'fam-ozdemir') === activeFamily.id
      ),
    [state.schoolSchedules, activeFamily.id]
  );

  const familyAppeals = useMemo(
    () =>
      (state.appeals || INITIAL_APPEALS).filter(
        (ap) => (ap.family_id || 'fam-ozdemir') === activeFamily.id
      ),
    [state.appeals, activeFamily.id]
  );

  const familyWeeklyInterviews = useMemo(
    () =>
      (state.weeklyInterviews || INITIAL_WEEKLY_INTERVIEWS).filter(
        (wi) => (wi.family_id || 'fam-ozdemir') === activeFamily.id
      ),
    [state.weeklyInterviews, activeFamily.id]
  );

  const activeHappyHourDiscountPercent = useMemo(() => {
    const manualDiscount = familySettings.happy_hour_discount_percent || 0;
    const endsAt = familySettings.happy_hour_ends_at;
    if (manualDiscount > 0 && (!endsAt || new Date(endsAt).getTime() > Date.now())) {
      return manualDiscount;
    }
    // Otomatik Cuma İndirim Saati (Her Cuma 18:00 - 20:00 arası %30 indirim)
    const now = new Date();
    const isFriday = now.getDay() === 5;
    const hour = now.getHours();
    if (isFriday && hour >= 18 && hour < 20) {
      return 30;
    }
    return 0;
  }, [familySettings.happy_hour_discount_percent, familySettings.happy_hour_ends_at]);

  const familyUsers = useMemo(
    () => state.users.filter((u) => (u.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.users, activeFamily.id]
  );
  const familyDevices = useMemo(
    () => state.devices.filter((d) => (d.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.devices, activeFamily.id]
  );
  const familyTasks = useMemo(
    () => state.tasks.filter((t) => (t.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.tasks, activeFamily.id]
  );
  const familySubmissions = useMemo(
    () => state.submissions.filter((s) => (s.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.submissions, activeFamily.id]
  );
  const familyRewards = useMemo(
    () => state.rewards.filter((r) => (r.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.rewards, activeFamily.id]
  );
  const familyRedemptions = useMemo(
    () => state.redemptions.filter((r) => (r.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.redemptions, activeFamily.id]
  );
  const familyMessages = useMemo(
    () => state.messages.filter((m) => (m.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.messages, activeFamily.id]
  );
  const familyViolations = useMemo(
    () => state.violations.filter((v) => (v.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.violations, activeFamily.id]
  );
  const familyAlarms = useMemo(
    () => state.alarms.filter((a) => (a.family_id || 'fam-ozdemir') === activeFamily.id),
    [state.alarms, activeFamily.id]
  );
  const familyAlerts = useMemo(
    () => liveAlerts.filter((a) => a.family_id === activeFamily.id),
    [liveAlerts, activeFamily.id]
  );

  const activeUser = useMemo(() => {
    const found = familyUsers.find((u) => u.id === activeUserId);
    if (found) return found;
    const firstChild = familyUsers.find((u) => u.role === 'child');
    return firstChild || familyUsers[0] || defaultEmptyUser;
  }, [familyUsers, activeUserId, defaultEmptyUser]);

  const pushAlert = useCallback(
    (
      familyId: string,
      type: LiveAlertBanner['type'],
      title: string,
      message: string
    ) => {
      try {
        const newAlert: LiveAlertBanner = {
          id: `alert-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          family_id: familyId,
          type,
          title,
          message,
          timestamp: new Date().toLocaleTimeString('tr-TR', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
          }),
        };
        setLiveAlerts((prev) => [newAlert, ...prev.slice(0, 8)]);
      } catch (err) {
        console.error('[pushAlert] Hata:', err);
      }
    },
    []
  );

  const dismissAlert = useCallback((id: string) => {
    setLiveAlerts((prev) => prev.filter((a) => a.id !== id));
  }, []);

  const commitAndBroadcast = useCallback(
    (
      updater: (prev: SharedMultiTenantState) => SharedMultiTenantState,
      eventMeta?: {
        familyId?: string;
        sound?: 'victory' | 'break' | 'study' | 'violation' | 'flash' | 'walkie' | 'wakeup';
        alert?: { type: LiveAlertBanner['type']; title: string; message: string };
      }
    ) => {
      const targetFamilyId = eventMeta?.familyId || activeFamilyRef.current;

      setState((prev) => {
        const next = updater(prev);
        if (typeof window !== 'undefined') {
          try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
          } catch {}
          try {
            if (broadcastRef.current) {
              broadcastRef.current.postMessage({
                type: 'STATE_SYNC',
                payload: next,
                eventMeta: { ...eventMeta, familyId: targetFamilyId },
              });
            }
          } catch {}
        }
        return next;
      });

      if (targetFamilyId === activeFamilyRef.current) {
        try {
          if (eventMeta?.sound) {
            switch (eventMeta.sound) {
              case 'victory':
                soundEngine.playVictoryFanfare();
                break;
              case 'break':
                soundEngine.playBreakStartBell();
                break;
              case 'study':
                soundEngine.playStudyStartChime();
                break;
              case 'violation':
                soundEngine.playViolationSiren();
                break;
              case 'flash':
                soundEngine.playFlashQuestAlert();
                break;
              case 'walkie':
                soundEngine.playWalkieTalkieBeep();
                break;
              case 'wakeup':
                soundEngine.startWakeUpAlarmLoop();
                break;
            }
          }
          if (eventMeta?.alert) {
            pushAlert(
              targetFamilyId,
              eventMeta.alert.type,
              eventMeta.alert.title,
              eventMeta.alert.message
            );
          }
        } catch (err) {
          console.error('[commitAndBroadcast] Ses/Bildirim hatası:', err);
        }
      }
    },
    [pushAlert]
  );

  // Initialize from localStorage + BroadcastChannel
  useEffect(() => {
    if (typeof window === 'undefined') return;

    try {
      const savedFamId = localStorage.getItem(ACTIVE_FAMILY_KEY);
      if (savedFamId) {
        setActiveFamilyId(savedFamId);
      }

      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && Array.isArray(parsed.users) && Array.isArray(parsed.families)) {
          setState(parsed);
        }
      }
    } catch {}

    if ('BroadcastChannel' in window) {
      try {
        const bc = new BroadcastChannel(BROADCAST_CHANNEL_NAME);
        bc.onmessage = (event) => {
          try {
            if (event.data?.type === 'STATE_SYNC' && event.data.payload) {
              setState(event.data.payload);
              const meta = event.data.eventMeta;
              if (!meta?.familyId || meta.familyId === activeFamilyRef.current) {
                if (meta?.sound) {
                  if (meta.sound === 'victory') soundEngine.playVictoryFanfare();
                  if (meta.sound === 'break') soundEngine.playBreakStartBell();
                  if (meta.sound === 'study') soundEngine.playStudyStartChime();
                  if (meta.sound === 'violation') soundEngine.playViolationSiren();
                  if (meta.sound === 'flash') soundEngine.playFlashQuestAlert();
                  if (meta.sound === 'walkie') soundEngine.playWalkieTalkieBeep();
                }
                if (meta?.alert) {
                  pushAlert(
                    meta.familyId || activeFamilyRef.current,
                    meta.alert.type,
                    meta.alert.title,
                    meta.alert.message
                  );
                }
              }
            }
          } catch {}
        };
        broadcastRef.current = bc;
      } catch {}
    }

    const handleStorage = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY && e.newValue) {
        try {
          setState(JSON.parse(e.newValue));
        } catch {}
      }
    };
    window.addEventListener('storage', handleStorage);

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }

    return () => {
      window.removeEventListener('storage', handleStorage);
      try {
        broadcastRef.current?.close();
      } catch {}
    };
  }, [pushAlert]);

  // 1. Core Multi-Tenant Isolated Data Fetcher
  const loadFamilyData = useCallback(async (targetFamId: string) => {
    if (!supabase || !targetFamId) return;
    try {
      const [fam, fset, qr, pt, ss, ap, wi, u, d, t, s, r, rr, m, v, a] = await Promise.all([
        supabase.from('families').select('*').eq('id', targetFamId),
        supabase.from('family_settings').select('*').eq('family_id', targetFamId),
        supabase.from('qr_stations').select('*').eq('family_id', targetFamId),
        supabase.from('point_transfers').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('school_schedules').select('*').eq('family_id', targetFamId),
        supabase.from('appeals').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('weekly_interviews').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('users').select('*').eq('family_id', targetFamId),
        supabase.from('devices').select('*').eq('family_id', targetFamId),
        supabase.from('tasks').select('*').eq('family_id', targetFamId),
        supabase.from('task_submissions').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('rewards').select('*').eq('family_id', targetFamId),
        supabase.from('reward_redemptions').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('messages').select('*').eq('family_id', targetFamId).order('created_at', { ascending: true }),
        supabase.from('violation_logs').select('*').eq('family_id', targetFamId).order('created_at', { ascending: false }),
        supabase.from('alarms_and_schedules').select('*').eq('family_id', targetFamId),
      ]);

      if (typeof window !== 'undefined' && fset.data?.length) {
        fset.data.forEach((row: FamilySettings) => {
          if (row.offline_master_pin_hash) {
            localStorage.setItem(
              `family_to_study_offline_pin_${row.family_id}`,
              row.offline_master_pin_hash
            );
          }
        });
      }

      setState({
        families: (fam.data as FamilyAccount[]) || [],
        familySettings: (fset.data as FamilySettings[]) || [],
        qrStations: (qr.data as QRStation[]) || [],
        pointTransfers: (pt.data as PointTransfer[]) || [],
        schoolSchedules: (ss.data as SchoolScheduleItem[]) || [],
        appeals: (ap.data as AppealRecord[]) || [],
        weeklyInterviews: (wi.data as WeeklyInterviewRecord[]) || [],
        users: (u.data as UserProfile[]) || [],
        devices: (d.data as DeviceRecord[]) || [],
        tasks: ((t.data as TaskItem[]) || []).map((task) => ({
          ...task,
          verification_type:
            task.verification_type ||
            (task.category === 'routine_morning' && !task.requires_photo
              ? 'direct_submit'
              : 'photo_optional'),
        })),
        submissions: ((s.data as TaskSubmission[]) || []).map((sub) => ({
          ...sub,
          submission_method:
            sub.submission_method ||
            (sub.photo_urls?.length ? 'photo_uploaded' : 'called_parent_for_check'),
          photo_urls: sub.photo_urls || [],
        })),
        rewards: (r.data as RewardItem[]) || [],
        redemptions: (rr.data as RewardRedemption[]) || [],
        messages: (m.data as DirectMessage[]) || [],
        violations: (v.data as ViolationLog[]) || [],
        alarms: (a.data as AlarmSchedule[]) || [],
      });
    } catch (err) {
      console.error('[loadFamilyData] Supabase veri yükleme hatası:', err);
    }
  }, []);

  // Persistent session + Google auth lifecycle initialization
  useEffect(() => {
    let isCancelled = false;

    const initAuth = async () => {
      try {
        // 1. First check local persistent sealed session
        const stored = await getPersistentSession();
        if (stored && stored.familyId && stored.userId) {
          if (isCancelled) return;
          setIsAuthenticated(true);
          setActiveFamilyId(stored.familyId);
          setActiveUserId(stored.userId);
          await loadFamilyData(stored.familyId);
          setSessionLoading(false);
          return;
        }

        // 2. Check Supabase Google auth session
        if (supabase) {
          const { data: sessionData } = await supabase.auth.getSession();
          const authUser = sessionData?.session?.user;
          if (authUser) {
            const { data: userFamilies } = await supabase
              .from('families')
              .select('*')
              .eq('owner_auth_id', authUser.id);

            if (userFamilies && userFamilies.length > 0) {
              const myFam = userFamilies[0] as FamilyAccount;
              const { data: famUsers } = await supabase
                .from('users')
                .select('*')
                .eq('family_id', myFam.id);

              const pUser =
                (famUsers as UserProfile[])?.find((u) => u.role === 'parent') ||
                (famUsers as UserProfile[])?.[0];

              if (pUser) {
                await sealPersistentSession({
                  userId: pUser.id,
                  familyId: myFam.id,
                  sessionToken: sessionData?.session?.access_token || pUser.id,
                  role: pUser.role,
                  name: pUser.name,
                  savedAt: Date.now(),
                });
                if (isCancelled) return;
                setIsAuthenticated(true);
                setActiveFamilyId(myFam.id);
                setActiveUserId(pUser.id);
                await loadFamilyData(myFam.id);
                setSessionLoading(false);
                return;
              }
            } else {
              // First time entering with Google -> Show Family Setup Wizard
              if (isCancelled) return;
              setWizardOwnerEmail(authUser.email || null);
              setWizardOpen(true);
              setSessionLoading(false);
              return;
            }
          }
        }
      } catch (err) {
        console.warn('[initAuth] Oturum başlatma hatası:', err);
      } finally {
        if (!isCancelled) {
          setSessionLoading(false);
        }
      }
    };

    initAuth();

    const { data: authSub } = supabase
      ? supabase.auth.onAuthStateChange((event, session) => {
          if (session?.user && (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED')) {
            initAuth();
          }
        })
      : { data: null };

    return () => {
      isCancelled = true;
      authSub?.subscription?.unsubscribe();
    };
  }, [loadFamilyData]);

  // Supabase Realtime Synchronization with Auto-Recovery (Isolated per Family)
  useEffect(() => {
    if (!isSupabaseConfigured || !supabase || !activeFamilyId) return;

    const channel = supabase
      .channel(`family-tenant-${activeFamilyId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'families' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'task_submissions' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'reward_redemptions' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'messages' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'violation_logs' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'tasks' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'rewards' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'family_settings' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'qr_stations' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'point_transfers' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'appeals' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'weekly_interviews' }, () => {
        loadFamilyData(activeFamilyId);
      })
      .subscribe();

    return () => {
      try {
        supabase?.removeChannel(channel);
      } catch {}
    };
  }, [activeFamilyId, loadFamilyData]);

  // Anti-Cheat: Sunucu Saati Senkronizasyonu (`useServerTime` Hook)
  const { serverTimeOffset, getServerNow } = useServerTime({
    onClockTamperDetected: () => {
      try {
        const currentChild =
          stateRef.current.users.find(
            (u) => u.id === activeUser.id && u.role === 'child'
          ) ||
          stateRef.current.users.find(
            (u) => u.family_id === activeFamilyRef.current && u.role === 'child'
          );
        if (currentChild && currentChild.current_state !== 'FROZEN_HOLIDAY') {
          const dev = stateRef.current.devices.find(
            (d) => d.user_id === currentChild.id
          );
          const tamperLog: ViolationLog = {
            id: `viol-tamper-${Date.now()}`,
            family_id: currentChild.family_id,
            user_id: currentChild.id,
            device_id: dev?.id || 'web-client',
            violation_type: 'clock_tamper_attempt',
            created_at: new Date().toISOString(),
          };
          commitAndBroadcast(
            (prev) => ({
              ...prev,
              violations: [tamperLog, ...prev.violations],
              users: prev.users.map((u) =>
                u.id === currentChild.id
                  ? { ...u, daily_shields: Math.max(0, u.daily_shields - 1) }
                  : u
              ),
            }),
            {
              familyId: currentChild.family_id,
              sound: 'violation',
              alert: {
                type: 'violation',
                title: `🚨 SAAT HİLESİ TESPİT EDİLDİ! (${currentChild.name})`,
                message: `${currentChild.name} cihaz saatini >2 dakika değiştirmeyi denedi (clock_tamper_attempt)! Sunucu saati korundu ve 1 Kalkan kırıldı.`,
              },
            }
          );
          if (isSupabaseConfigured && supabase && dev) {
            supabase
              .rpc('record_violation_and_break_shield', {
                p_user_id: currentChild.id,
                p_device_id: dev.id,
                p_violation_type: 'clock_tamper_attempt',
              })
              .then(() => {});
          }
        }
      } catch (err) {
        console.error('[onClockTamperDetected] Hata:', err);
      }
    },
  });

  // Synchronized Countdown Engine (Powered by Server Time: Date.now() + serverTimeOffset)
  useEffect(() => {
    const timer = setInterval(() => {
      try {
        const now = getServerNow();
        const nextRemaining: Record<string, number> = {};

        stateRef.current.users.forEach((user) => {
          if (user.role === 'child' && user.state_ends_at) {
            const endMs = new Date(user.state_ends_at).getTime();
            const diffSec = Math.max(0, Math.ceil((endMs - now) / 1000));
            nextRemaining[user.id] = diffSec;

            if (
              diffSec === 0 &&
              user.current_state !== 'FREE_TIME' &&
              user.current_state !== 'WAKE_UP_ALARM' &&
              user.current_state !== 'FROZEN_HOLIDAY'
            ) {
              if (
                user.current_state === 'STUDY_TIME' ||
                user.current_state === 'COMPUTER_STUDY'
              ) {
                const breakEnd = new Date(
                  getServerNow() + 10 * 60 * 1000
                ).toISOString();
                commitAndBroadcast(
                  (prev) => ({
                    ...prev,
                    users: prev.users.map((u) =>
                      u.id === user.id
                        ? { ...u, current_state: 'BREAK_TIME', state_ends_at: breakEnd }
                        : u
                    ),
                  }),
                  {
                    familyId: user.family_id,
                    sound: 'break',
                    alert: {
                      type: 'info',
                      title: `🔔 Teneffüs Zili Çaldı! (${user.name})`,
                      message: `${user.name} odaklanma süresini tamamladı! 10 dakika mola başladı.`,
                    },
                  }
                );
              } else {
                commitAndBroadcast(
                  (prev) => ({
                    ...prev,
                    users: prev.users.map((u) =>
                      u.id === user.id
                        ? { ...u, current_state: 'FREE_TIME', state_ends_at: null }
                        : u
                    ),
                  }),
                  { familyId: user.family_id, sound: 'study' }
                );
              }
            }
          } else {
            nextRemaining[user.id] = 0;
          }
        });

        setRemainingSecondsByUser(nextRemaining);

        // Phase 4 Module D: Ebeveyn 10 dakikadır yanıt vermediyse (600.000 ms),
        // bekleyen görevi güvene dayalı ön-onay (`status = 'approved'`, `is_optimistic_approved = true`)
        // olarak işaretle ve puanı/süreyi öğrenciye bekletmeden tanımla.
        const stalePendingSub = stateRef.current.submissions.find(
          (s) =>
            s.status === 'pending' &&
            now - new Date(s.created_at).getTime() >= 10 * 60 * 1000
        );
        if (stalePendingSub) {
          const task = stateRef.current.tasks.find(
            (t) => t.id === stalePendingSub.task_id
          );
          const student = stateRef.current.users.find(
            (u) => u.id === stalePendingSub.user_id
          );
          const earnedPoints = task?.points || 25;

          commitAndBroadcast(
            (prev) => ({
              ...prev,
              submissions: prev.submissions.map((s) =>
                s.id === stalePendingSub.id
                  ? {
                      ...s,
                      status: 'approved',
                      is_optimistic_approved: true,
                      approved_by: 'autopilot-10min-timeout',
                    }
                  : s
              ),
              users: prev.users.map((u) =>
                u.id === stalePendingSub.user_id
                  ? { ...u, points_balance: u.points_balance + earnedPoints }
                  : u
              ),
            }),
            {
              familyId: stalePendingSub.family_id,
              sound: 'victory',
              alert: {
                type: 'approval',
                title: `🤝 Güven Ön-Onayı (10 Dk): ${student?.name || 'Öğrenci'} (+${earnedPoints} Puan)`,
                message:
                  '🤝 Anne/Baban şu an meşgul ama sana güveniyoruz! Puanın ve ödülün ön-onay ile hemen yüklendi!',
              },
            }
          );

          if (isSupabaseConfigured && supabase) {
            supabase
              .from('task_submissions')
              .update({
                status: 'approved',
                is_optimistic_approved: true,
                approved_by: 'autopilot-10min-timeout',
              })
              .eq('id', stalePendingSub.id)
              .then(() => {});
            if (student) {
              supabase
                .from('users')
                .update({
                  points_balance: student.points_balance + earnedPoints,
                })
                .eq('id', student.id)
                .then(() => {});
            }
          }
        }
      } catch (err) {
        console.error('[CountdownEngine] Hata:', err);
      }
    }, 500);

    return () => clearInterval(timer);
  }, [commitAndBroadcast, getServerNow]);

  useEffect(() => {
    try {
      if (activeUser.role === 'child' && activeUser.current_state === 'WAKE_UP_ALARM') {
        soundEngine.startWakeUpAlarmLoop();
      } else {
        soundEngine.stopWakeUpAlarmLoop();
      }
    } catch {}
  }, [activeUser.id, activeUser.role, activeUser.current_state]);

  const setActiveUserById = useCallback((userId: string) => {
    setActiveUserId(userId);
  }, []);

  const switchFamilyById = useCallback((familyId: string) => {
    setActiveFamilyId(familyId);
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(ACTIVE_FAMILY_KEY, familyId);
      } catch {}
    }
    const famUsers = stateRef.current.users.filter(
      (u) => (u.family_id || 'fam-ozdemir') === familyId
    );
    const firstChild = famUsers.find((u) => u.role === 'child') || famUsers[0];
    if (firstChild) {
      setActiveUserId(firstChild.id);
    }
  }, []);

  const switchFamilyByCode = useCallback(
    (familyCode: string): { success: boolean; message: string } => {
      const normalized = familyCode.trim().toUpperCase();
      const target = stateRef.current.families.find(
        (f) => f.family_code.toUpperCase() === normalized
      );
      if (!target) {
        return {
          success: false,
          message: `"${normalized}" koduna sahip bir aile bulunamadı. (Örnek: OZDEMIR-2026 veya YILMAZ-2026)`,
        };
      }
      switchFamilyById(target.id);
      return {
        success: true,
        message: `${target.name} hesabına geçiş yapıldı!`,
      };
    },
    [switchFamilyById]
  );

  const createNewFamily = useCallback(
    async ({
      name,
      familyCode,
      parentPin,
      momName,
      dadName,
    }: {
      name: string;
      familyCode: string;
      parentPin: string;
      momName: string;
      dadName: string;
    }) => {
      try {
        const cleanCode = familyCode.trim().toUpperCase();
        if (
          stateRef.current.families.some(
            (f) => f.family_code.toUpperCase() === cleanCode
          )
        ) {
          return {
            success: false,
            message: 'Bu aile davet kodu zaten kullanımda. Lütfen farklı bir kod seçin.',
          };
        }

        const newFamId = `fam-${Date.now()}`;
        const newFamily: FamilyAccount = {
          id: newFamId,
          name: name.trim(),
          family_code: cleanCode,
          parent_pin: parentPin.trim() || '1234',
          subscription_tier: 'pro',
        };

        const momUser: UserProfile = {
          id: `parent-mom-${Date.now()}`,
          family_id: newFamId,
          name: momName.trim() || 'Anne',
          role: 'parent',
          avatar_config: { emoji: '👩‍🚀', bg: 'from-rose-500 to-pink-600', ageGroup: 'adult' },
          theme: 'parent-command',
          points_balance: 0,
          piggy_bank_balance: 0,
          daily_shields: 3,
          streak_days: 0,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };

        const dadUser: UserProfile = {
          id: `parent-dad-${Date.now() + 1}`,
          family_id: newFamId,
          name: dadName.trim() || 'Baba',
          role: 'parent',
          avatar_config: { emoji: '👨‍✈️', bg: 'from-blue-600 to-indigo-700', ageGroup: 'adult' },
          theme: 'parent-command',
          points_balance: 0,
          piggy_bank_balance: 0,
          daily_shields: 3,
          streak_days: 0,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };

        const starterChild: UserProfile = {
          id: `child-${Date.now() + 2}`,
          family_id: newFamId,
          name: 'Can (Örnek Öğrenci)',
          role: 'child',
          avatar_config: {
            emoji: '🦊',
            bg: 'from-amber-400 to-orange-500',
            ageGroup: 'kid',
            grade: '4. Sınıf',
          },
          theme: 'cosmic-explorer',
          points_balance: 50,
          piggy_bank_balance: 20,
          daily_shields: 3,
          streak_days: 1,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };

        const starterTask1: TaskItem = {
          id: `task-tooth-${Date.now()}`,
          family_id: newFamId,
          assigned_to: 'both',
          title: 'Sabah Diş Fırçalama (2 Dk Müzikli Sayaç)',
          description: 'Müzikli fırçalama sayacını başlat ve 2 dakika boyunca dişlerini fırçala!',
          category: 'routine_morning',
          points: 15,
          verification_type: 'direct_submit',
          requires_photo: false,
          duration_minutes: 2,
          is_active: true,
          due_time: '08:00',
        };

        const starterTask2: TaskItem = {
          id: `task-acad-${Date.now() + 1}`,
          family_id: newFamId,
          assigned_to: 'both',
          title: 'Günlük Ödev & Test Çözümü',
          description: 'Bitirdiğinde ister fotoğrafını çek, ister Anne/Babanı masana kontrole çağır!',
          category: 'academic',
          points: 45,
          verification_type: 'photo_optional',
          requires_photo: false,
          duration_minutes: 35,
          is_active: true,
          due_time: '18:00',
        };

        const starterReward1: RewardItem = {
          id: `rew-unlock-${Date.now()}`,
          family_id: newFamId,
          title: '⚡ 30 Dakika Serbest Ekran / Oyun Süresi',
          cost_points: 60,
          tier: 'micro',
          auto_action: { type: 'unlock_screen', minutes: 30 },
          icon: 'Gamepad2',
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            families: [...prev.families, newFamily],
            users: [...prev.users, momUser, dadUser, starterChild],
            tasks: [...prev.tasks, starterTask1, starterTask2],
            rewards: [...prev.rewards, starterReward1],
          }),
          { familyId: newFamId, sound: 'victory' }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('families').insert(newFamily);
          await supabase.from('users').insert([momUser, dadUser, starterChild]);
          await supabase.from('tasks').insert([starterTask1, starterTask2]);
          await supabase.from('rewards').insert([starterReward1]);
        }

        setActiveFamilyId(newFamId);
        setActiveUserId(momUser.id);
        if (typeof window !== 'undefined') {
          localStorage.setItem(ACTIVE_FAMILY_KEY, newFamId);
        }

        return {
          success: true,
          message: `${newFamily.name} (${newFamily.family_code}) başarıyla oluşturuldu!`,
        };
      } catch (err) {
        console.error('[createNewFamily] Hata:', err);
        return { success: false, message: 'Aile oluşturulurken bir hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  const loginSuccessWithUser = useCallback(
    async (userId: string, familyId: string) => {
      setIsAuthenticated(true);
      setActiveFamilyId(familyId);
      setActiveUserId(userId);
      await loadFamilyData(familyId);
    },
    [loadFamilyData]
  );

  const logout = useCallback(async () => {
    await clearPersistentSession();
    if (isSupabaseConfigured && supabase) {
      try {
        await supabase.auth.signOut();
      } catch {}
    }
    setIsAuthenticated(false);
    setActiveFamilyId('');
    setActiveUserId('');
    setState({
      families: [],
      familySettings: [],
      qrStations: [],
      pointTransfers: [],
      schoolSchedules: [],
      appeals: [],
      weeklyInterviews: [],
      users: [],
      devices: [],
      tasks: [],
      submissions: [],
      rewards: [],
      redemptions: [],
      messages: [],
      violations: [],
      alarms: [],
    });
  }, []);

  const regenerateDesktopPairingCode = useCallback(
    async (userId: string) => {
      const newCode = `${Math.floor(100 + Math.random() * 900)}-${Math.floor(100 + Math.random() * 900)}`;
      setState((prev) => ({
        ...prev,
        users: prev.users.map((u) => (u.id === userId ? { ...u, desktop_pairing_code: newCode } : u)),
      }));

      if (isSupabaseConfigured && supabase) {
        try {
          await supabase.from('users').update({ desktop_pairing_code: newCode }).eq('id', userId);
        } catch {}
      }

      return newCode;
    },
    []
  );

  const createFamilyWizard = useCallback(
    async (params: {
      familyName: string;
      parentPin: string;
      members: Array<{
        name: string;
        role: 'parent' | 'child';
        grade: string;
        ageGroup: 'kid' | 'preteen' | 'teen' | 'adult';
        emoji: string;
      }>;
    }) => {
      const newFamId = `fam-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;
      const inviteToken = `inv-${Math.random().toString(36).slice(2, 10)}`;
      const familyCode = `${params.familyName.slice(0, 4).toUpperCase().replace(/[^A-Z]/g, 'FAM')}-${new Date().getFullYear()}`;

      let authUserId: string | null = null;
      if (isSupabaseConfigured && supabase) {
        try {
          const { data: authData } = await supabase.auth.getUser();
          authUserId = authData?.user?.id || null;
        } catch {}
      }

      const newFamily: FamilyAccount = {
        id: newFamId,
        name: params.familyName,
        family_name: params.familyName,
        owner_auth_id: authUserId,
        family_invite_token: inviteToken,
        family_code: familyCode,
        parent_pin: params.parentPin || '1234',
        subscription_tier: 'pro',
        created_at: new Date().toISOString(),
      };

      const newUsers: UserProfile[] = params.members.map((m, idx) => {
        const cleanName = m.name.toLowerCase().replace(/[^a-z0-9]/g, '') || 'birey';
        const randNum = Math.floor(100 + Math.random() * 900);
        const randPass = String(Math.floor(100000 + Math.random() * 900000));
        const token = `mag-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        const pairCode = `${Math.floor(100 + Math.random() * 900)}-${Math.floor(100 + Math.random() * 900)}`;

        return {
          id: `usr-${cleanName}-${idx + 1}-${Math.random().toString(36).slice(2, 6)}`,
          family_id: newFamId,
          name: m.name,
          role: m.role,
          username: `${cleanName}.${randNum}`,
          access_password: randPass,
          magic_login_token: token,
          desktop_pairing_code: pairCode,
          avatar_config: {
            emoji: m.emoji || (m.role === 'parent' ? '👨‍✈️' : '🦁'),
            bg: m.role === 'parent' ? 'from-indigo-600 to-purple-700' : 'from-amber-400 to-orange-500',
            ageGroup: m.ageGroup || (m.role === 'parent' ? 'adult' : 'kid'),
            grade: m.grade || (m.role === 'parent' ? 'Ebeveyn' : '4. Sınıf'),
          },
          theme: m.role === 'parent' ? 'parent-command' : 'cosmic-explorer',
          points_balance: m.role === 'child' ? 25 : 0,
          piggy_bank_balance: 0,
          daily_shields: 3,
          streak_days: 0,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };
      });

      const primaryParent = newUsers.find((u) => u.role === 'parent') || newUsers[0];

      const defaultSettings: FamilySettings = {
        id: `fset-${newFamId}`,
        family_id: newFamId,
        family_chest_goal: 1000,
        family_chest_current: 0,
        family_chest_reward_title: '🍕 Ailece Pizza & Sinema Gecesi!',
        offline_master_pin_hash: '8154e6b1b7e76c0155248914635c86b29a19a6136b110924b4ef7e2310293572',
        city_lat: 41.01,
        city_lon: 28.97,
        noise_threshold_db: 75,
        autopilot_until: null,
        happy_hour_discount_percent: 0,
        happy_hour_ends_at: null,
        tts_announcements_enabled: true,
      };

      if (isSupabaseConfigured && supabase) {
        try {
          await supabase.from('families').insert(newFamily);
          await supabase.from('family_settings').insert(defaultSettings);
          await supabase.from('users').insert(newUsers);
        } catch (err) {
          console.warn('[createFamilyWizard] Supabase insert:', err);
        }
      }

      await sealPersistentSession({
        userId: primaryParent.id,
        familyId: newFamId,
        sessionToken: primaryParent.magic_login_token || primaryParent.id,
        role: primaryParent.role,
        name: primaryParent.name,
        savedAt: Date.now(),
      });

      setState((prev) => ({
        ...prev,
        families: [newFamily, ...prev.families],
        familySettings: [defaultSettings, ...prev.familySettings],
        users: [...newUsers, ...prev.users],
      }));

      setIsAuthenticated(true);
      setActiveFamilyId(newFamId);
      setActiveUserId(primaryParent.id);
      setWizardOpen(false);

      return { success: true, message: `🎉 ${params.familyName} başarıyla kuruldu!` };
    },
    []
  );

  const addChildToFamily = useCallback(
    async ({
      name,
      grade,
      ageGroup,
      emoji,
    }: {
      name: string;
      grade: string;
      ageGroup: 'kid' | 'preteen' | 'teen';
      emoji: string;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        const newChildId = `child-${Date.now()}`;
        const cleanName = name.toLowerCase().replace(/[^a-z0-9]/g, '') || 'ogrenci';
        const randPass = String(Math.floor(100000 + Math.random() * 900000));
        const token = `mag-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        const pairCode = `${Math.floor(100 + Math.random() * 900)}-${Math.floor(100 + Math.random() * 900)}`;

        const newChild: UserProfile = {
          id: newChildId,
          family_id: famId,
          name: name.trim(),
          role: 'child',
          username: `${cleanName}.${Math.floor(100 + Math.random() * 900)}`,
          access_password: randPass,
          magic_login_token: token,
          desktop_pairing_code: pairCode,
          avatar_config: {
            emoji: emoji || '🦁',
            bg:
              ageGroup === 'kid'
                ? 'from-amber-400 to-orange-500'
                : 'from-purple-500 to-fuchsia-600',
            ageGroup,
            grade: grade.trim() || 'Öğrenci',
          },
          theme: ageGroup === 'kid' ? 'cosmic-explorer' : 'cyber-academy',
          points_balance: 50,
          piggy_bank_balance: 0,
          daily_shields: 3,
          streak_days: 1,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };

        const defaultDevice: DeviceRecord = {
          id: `dev-${Date.now()}`,
          family_id: famId,
          user_id: newChildId,
          device_name: `${name.trim()} Tablet / PC`,
          device_type: 'tablet',
          is_online: true,
          last_heartbeat: new Date().toISOString(),
          last_activity_at: new Date().toISOString(),
          active_window_title: 'FamilyToStudy PWA (Aktif)',
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: [...prev.users, newChild],
            devices: [...prev.devices, defaultDevice],
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `🎉 Yeni Öğrenci Eklendi: ${newChild.name}`,
              message: `${newChild.name} (${grade}) aile akademisine katıldı!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('users').insert(newChild);
          await supabase.from('devices').insert(defaultDevice);
        }
      } catch (err) {
        console.error('[addChildToFamily] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  const addParentToFamily = useCallback(
    async ({
      name,
      roleTitle,
    }: {
      name: string;
      roleTitle?: string;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        const newParentId = `parent-${Date.now()}`;
        const cleanName = name.toLowerCase().replace(/[^a-z0-9]/g, '') || 'ebeveyn';
        const randPass = String(Math.floor(100000 + Math.random() * 900000));
        const token = `mag-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

        const newParent: UserProfile = {
          id: newParentId,
          family_id: famId,
          name: name.trim(),
          role: 'parent',
          username: `${cleanName}.${Math.floor(100 + Math.random() * 900)}`,
          access_password: randPass,
          magic_login_token: token,
          avatar_config: {
            emoji: roleTitle?.toLowerCase().includes('anne') ? '👩‍💼' : roleTitle?.toLowerCase().includes('baba') ? '👨‍💼' : '🧑‍✈️',
            bg: 'from-blue-600 to-indigo-700',
            ageGroup: 'adult',
            roleTitle: roleTitle || 'Ebeveyn',
          },
          theme: 'parent-command',
          points_balance: 0,
          piggy_bank_balance: 0,
          daily_shields: 3,
          streak_days: 1,
          wheel_spins_available: 0,
          current_mood: 'happy',
          current_state: 'FREE_TIME',
          state_ends_at: null,
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: [...prev.users, newParent],
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `🎉 Yeni Ebeveyn Eklendi: ${newParent.name}`,
              message: `${newParent.name} (${roleTitle || 'Ebeveyn'}) aileye dahil edildi!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('users').insert(newParent);
        }

        return { success: true, user: newParent, message: `${newParent.name} başarıyla eklendi.` };
      } catch (err) {
        console.error('[addParentToFamily] Hata:', err);
        return { success: false, message: 'Ebeveyn eklenirken bir hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  const updateFamilyMember = useCallback(
    async ({
      userId,
      name,
      grade,
      ageGroup,
      emoji,
      accessPassword,
    }: {
      userId: string;
      name: string;
      grade?: string;
      ageGroup?: 'kid' | 'preteen' | 'teen';
      emoji?: string;
      accessPassword?: string;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        let updatedUser: UserProfile | null = null;

        commitAndBroadcast(
          (prev) => {
            const newUsers = prev.users.map((u) => {
              if (u.id === userId) {
                const newAvatar = {
                  ...u.avatar_config,
                  ...(emoji ? { emoji } : {}),
                  ...(grade ? { grade } : {}),
                  ...(ageGroup ? { ageGroup } : {}),
                };
                updatedUser = {
                  ...u,
                  name: name.trim(),
                  ...(accessPassword ? { access_password: accessPassword.trim() } : {}),
                  avatar_config: newAvatar,
                };
                return updatedUser;
              }
              return u;
            });
            return { ...prev, users: newUsers };
          },
          {
            familyId: famId,
            alert: {
              type: 'info',
              title: '👤 Profil Güncellendi',
              message: `${name} bilgileri güncellendi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase && updatedUser) {
          const userObj = updatedUser as UserProfile;
          await supabase
            .from('users')
            .update({
              name: userObj.name,
              access_password: userObj.access_password,
              avatar_config: userObj.avatar_config,
            })
            .eq('id', userId);
        }

        return { success: true, message: 'Üye bilgileri başarıyla güncellendi.' };
      } catch (err) {
        console.error('[updateFamilyMember] Hata:', err);
        return { success: false, message: 'Güncelleme sırasında bir hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  const deleteFamilyMember = useCallback(
    async (userId: string) => {
      try {
        const famId = activeFamilyRef.current;
        const targetUser = state.users.find((u) => u.id === userId);
        if (!targetUser) {
          return { success: false, message: 'Kullanıcı bulunamadı.' };
        }

        // Ailede en az 1 ebeveyn kalmalı
        if (targetUser.role === 'parent') {
          const parentCount = state.users.filter((u) => u.role === 'parent').length;
          if (parentCount <= 1) {
            return {
              success: false,
              message: 'Ailede en az bir ebeveyn hesabı bulunmalıdır. Son ebeveyni silemezsiniz.',
            };
          }
        }

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.filter((u) => u.id !== userId),
            tasks: prev.tasks.filter((t) => t.assigned_to !== userId),
            devices: prev.devices.filter((d) => d.user_id !== userId),
          }),
          {
            familyId: famId,
            sound: 'violation',
            alert: {
              type: 'info',
              title: '🗑️ Birey Aileden Çıkarıldı',
              message: `${targetUser.name} aile akademisinden çıkarıldı.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('users').delete().eq('id', userId);
        }

        return { success: true, message: `${targetUser.name} başarıyla silindi.` };
      } catch (err) {
        console.error('[deleteFamilyMember] Hata:', err);
        return { success: false, message: 'Silme işlemi sırasında hata oluştu.' };
      }
    },
    [commitAndBroadcast, state.users]
  );

  const regenerateMemberCredentials = useCallback(
    async (userId: string) => {
      try {
        const famId = activeFamilyRef.current;
        const newPass = String(Math.floor(100000 + Math.random() * 900000));
        const newToken = `mag-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        const newPair = `${Math.floor(100 + Math.random() * 900)}-${Math.floor(100 + Math.random() * 900)}`;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === userId
                ? {
                    ...u,
                    access_password: newPass,
                    magic_login_token: newToken,
                    desktop_pairing_code: newPair,
                  }
                : u
            ),
          }),
          {
            familyId: famId,
            alert: {
              type: 'info',
              title: '🔑 Şifre & Bağlantı Yenilendi',
              message: 'Yeni 6 haneli şifre ve sihirli giriş bağlantısı oluşturuldu.',
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({
              access_password: newPass,
              magic_login_token: newToken,
              desktop_pairing_code: newPair,
            })
            .eq('id', userId);
        }

        return {
          success: true,
          newPassword: newPass,
          newMagicToken: newToken,
          newPairingCode: newPair,
          message: 'Giriş bilgileri yenilendi.',
        };
      } catch (err) {
        console.error('[regenerateMemberCredentials] Hata:', err);
        return { success: false, message: 'Giriş bilgileri yenilenirken hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  const addTaskToFamily = useCallback(
    async ({
      assignedTo,
      title,
      description,
      category,
      points,
      verificationType,
      dueTime,
      requiredQrStationId,
      isFirstComeRace,
    }: {
      assignedTo: string;
      title: string;
      description: string;
      category: TaskCategory;
      points: number;
      verificationType: TaskVerificationType;
      dueTime: string;
      requiredQrStationId?: string | null;
      isFirstComeRace?: boolean;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        const isRace = Boolean(isFirstComeRace);
        const newTask: TaskItem = {
          id: `task-${Date.now()}`,
          family_id: famId,
          assigned_to: isRace ? 'both' : assignedTo,
          title: isRace ? `⚡ İlk Kapar Yarışı: ${title.trim()}` : title.trim(),
          description:
            description.trim() ||
            (isRace
              ? 'Kardeşlerden ilk "🏃‍♂️ Ben Yaparım!" butonuna basan görevi kapar ve 15 dakika içinde bitirirse ödül puanını alır!'
              : 'Görevi tamamla; ister fotoğraf çek ister Anne/Babayı kontrole çağır!'),
          category: isRace ? 'flash_quest' : category,
          points: Math.max(5, points),
          verification_type: verificationType,
          requires_photo: false,
          duration_minutes: isRace ? 15 : 20,
          is_active: true,
          due_time: dueTime || '18:00',
          created_by: activeUser.id,
          proposal_status: 'approved',
          required_qr_station_id:
            verificationType === 'qr_scan' ? requiredQrStationId || 'qr-desk-01' : null,
          is_first_come_race: isRace,
          claimed_by: null,
          claimed_at: null,
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            tasks: [newTask, ...prev.tasks],
          }),
          {
            familyId: famId,
            sound: isRace ? 'flash' : 'walkie',
            alert: {
              type: isRace ? 'flash_quest' : 'info',
              title: isRace
                ? `🏃‍♂️ İLK KAPAR YARIŞ GÖREVİ DÜŞTÜ: ${title.trim()}`
                : `📋 Yeni Görev Eklendi: ${newTask.title}`,
              message: isRace
                ? `İlk "Ben Yaparım!" butonuna basan kardeş +${newTask.points} Puanlık görevi kapar!`
                : `+${newTask.points} Puan değerinde yeni görev listeye eklendi.`,
            },
          }
        );

        const ttsEnabled =
          stateRef.current.familySettings?.find((fs) => fs.family_id === famId)
            ?.tts_announcements_enabled ?? true;
        if (isRace) {
          speakTurkishAnnouncement(
            `Ev halkı dikkat! İlk kapar yarış görevi düştü: ${title.trim()}! İlk basan ${newTask.points} puanı kapar!`,
            ttsEnabled
          );
        }

        if (isSupabaseConfigured && supabase) {
          await supabase.from('tasks').insert(newTask);
        }
      } catch (err) {
        console.error('[addTaskToFamily] Hata:', err);
      }
    },
    [commitAndBroadcast, activeUser.id]
  );

  const addRewardToFamily = useCallback(
    async ({
      title,
      costPoints,
      tier,
      unlockMinutes,
    }: {
      title: string;
      costPoints: number;
      tier: RewardTier;
      unlockMinutes?: number | null;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        const newReward: RewardItem = {
          id: `rew-${Date.now()}`,
          family_id: famId,
          title: title.trim(),
          cost_points: Math.max(10, costPoints),
          tier,
          auto_action:
            unlockMinutes && unlockMinutes > 0
              ? { type: 'unlock_screen', minutes: unlockMinutes }
              : null,
          icon: unlockMinutes ? 'Gamepad2' : 'Gift',
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            rewards: [...prev.rewards, newReward],
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `🎁 Yeni Market Ödülü: ${newReward.title}`,
              message: `${newReward.cost_points} Puan karşılığında markete eklendi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('rewards').insert(newReward);
        }
      } catch (err) {
        console.error('[addRewardToFamily] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 1. Change Student State Across All Devices
  const setStudentState = useCallback(
    async (
      studentId: string,
      newState: StudentState,
      durationMinutes: number | null = 40
    ) => {
      try {
        const endsAt =
          durationMinutes && durationMinutes > 0
            ? new Date(Date.now() + durationMinutes * 60 * 1000).toISOString()
            : null;

        const student = stateRef.current.users.find((u) => u.id === studentId);
        const soundType =
          newState === 'BREAK_TIME'
            ? 'break'
            : newState === 'WAKE_UP_ALARM'
            ? 'wakeup'
            : 'study';

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? { ...u, current_state: newState, state_ends_at: endsAt }
                : u
            ),
          }),
          {
            familyId: student?.family_id,
            sound: soundType,
            alert: {
              type: newState === 'WAKE_UP_ALARM' ? 'wakeup' : 'info',
              title: `🔄 Çoklu Cihaz Mod Değişimi: ${student?.name || ''}`,
              message: `Tüm cihazlar (PC, Tablet, Telefon) anında ${newState} moduna senkronize edildi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({ current_state: newState, state_ends_at: endsAt })
            .eq('id', studentId);
        }

        // Phase 4 Modül E: Ders / Odaklanma başlarken İsimle Hitap Eden Konuşan Ev Asistanı (TTS)
        if (
          student &&
          (newState === 'STUDY_TIME' || newState === 'COMPUTER_STUDY')
        ) {
          const ttsEnabled =
            stateRef.current.familySettings?.find(
              (fs) => fs.family_id === student.family_id
            )?.tts_announcements_enabled ?? true;
          const mins = durationMinutes || 40;
          speakTurkishAnnouncement(
            `Dikkat dikkat! ${student.name} için ${mins} dakikalık odaklanma uçuşu başlıyor, başarılar kaptan!`,
            ttsEnabled
          );
        }
      } catch (err) {
        console.error('[setStudentState] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 2. Add +15 Min Bonus Time
  const addBonusTimeMinutes = useCallback(
    async (studentId: string, extraMinutes: number) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student || student.current_state === 'FROZEN_HOLIDAY') return;

        const baseMs = student.state_ends_at
          ? Math.max(Date.now(), new Date(student.state_ends_at).getTime())
          : Date.now();
        const newEndsAt = new Date(baseMs + extraMinutes * 60 * 1000).toISOString();

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    current_state:
                      u.current_state === 'STUDY_TIME' || u.current_state === 'SLEEP_TIME'
                        ? 'FREE_TIME'
                        : u.current_state,
                    state_ends_at: newEndsAt,
                  }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `⏱️ +${extraMinutes} Dakika Ek Süre Verildi!`,
              message: `${student.name} için tüm cihazların kilidi açıldı ve süre eklendi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({ current_state: 'FREE_TIME', state_ends_at: newEndsAt })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[addBonusTimeMinutes] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 3. Update Student Mood
  const updateStudentMood = useCallback(
    async (studentId: string, mood: UserMood) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId ? { ...u, current_mood: mood } : u
            ),
          }),
          { familyId: student?.family_id }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('users').update({ current_mood: mood }).eq('id', studentId);
        }
      } catch (err) {
        console.error('[updateStudentMood] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 4. Submit Task Completion (Flexible Verification: Photo Optional + Call Parent for Physical Check + Direct Submit)
  const submitTaskCompletion = useCallback(
    async (
      taskId: string,
      studentId: string,
      photoUrls: string[],
      submissionMethod?: TaskSubmissionMethod
    ) => {
      try {
        const task = stateRef.current.tasks.find((t) => t.id === taskId);
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!task || !student) {
          return { autoApproved: false, morningComboBonus: 0, submissionId: '' };
        }

        const resolvedMethod: TaskSubmissionMethod =
          submissionMethod ||
          (photoUrls.length > 0
            ? 'photo_uploaded'
            : task.verification_type === 'direct_submit'
            ? 'just_marked_done'
            : 'called_parent_for_check');

        const currentFamSettings = stateRef.current.familySettings?.find(
          (fs) => fs.family_id === student.family_id
        );
        const isAutopilotActive = Boolean(
          currentFamSettings?.autopilot_until &&
            new Date(currentFamSettings.autopilot_until).getTime() > Date.now()
        );

        const directOrQrAutoApprove =
          (task.verification_type === 'direct_submit' &&
            resolvedMethod === 'just_marked_done') ||
          (task.verification_type === 'qr_scan' &&
            resolvedMethod === 'qr_scanned');

        const autoApprove = directOrQrAutoApprove || isAutopilotActive;
        const isOptimisticAutopilot = !directOrQrAutoApprove && isAutopilotActive;

        const subId = `sub-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
        const newSub: TaskSubmission = {
          id: subId,
          family_id: student.family_id,
          task_id: taskId,
          user_id: studentId,
          submission_method: resolvedMethod,
          status: autoApprove ? 'approved' : 'pending',
          photo_urls: photoUrls || [],
          approved_by: isOptimisticAutopilot
            ? 'autopilot-trust'
            : autoApprove
            ? 'system-auto'
            : null,
          is_optimistic_approved: isOptimisticAutopilot,
          created_at: new Date().toISOString(),
        };

        let morningComboBonus = 0;
        if (autoApprove && task.category === 'routine_morning') {
          const morningTasks = stateRef.current.tasks.filter(
            (t) =>
              t.family_id === student.family_id &&
              t.category === 'routine_morning' &&
              t.is_active &&
              (t.assigned_to === studentId || t.assigned_to === 'both')
          );
          const completedMorningIds = new Set(
            stateRef.current.submissions
              .filter((s) => s.user_id === studentId && s.status === 'approved')
              .map((s) => s.task_id)
          );
          completedMorningIds.add(taskId);

          if (morningTasks.every((mt) => completedMorningIds.has(mt.id))) {
            morningComboBonus = 15;
          }
        }

        // Build custom parent notification based on submission_method
        const alertTitle = isOptimisticAutopilot
          ? `✈️ Otomatik Pilot Ön-Onayı: +${task.points + morningComboBonus} Puan Yüklendi!`
          : autoApprove
          ? `🌟 Rutin Tamamlandı: +${task.points + morningComboBonus} Puan!`
          : resolvedMethod === 'called_parent_for_check'
          ? `🏃‍♂️ Fiziksel Kontrol Zamanı! (${student.name})`
          : `📸 Fotoğraf Kanıtı Geldi! (${student.name})`;

        const alertMessage = isOptimisticAutopilot
          ? `🤝 Anne/Baban şu an meşgul ama sana güveniyoruz! "${task.title}" puanın ve ödülün ön-onay ile hemen yüklendi!`
          : autoApprove
          ? morningComboBonus > 0
            ? `${student.name} tüm sabah rutinlerini bitirdi ve +15 Muhteşem Sabah Bonusu kazandı!`
            : `${student.name} "${task.title}" görevini tamamladı.`
          : resolvedMethod === 'called_parent_for_check'
          ? `${student.name}, '${task.title}' görevini bitirdi, yanına gidip kontrol etmenizi bekliyor!`
          : `${student.name}, '${task.title}' görevi için ${photoUrls.length} fotoğraf gönderdi. Onay bekleniyor.`;

        const earnedPoints = autoApprove ? task.points + morningComboBonus : 0;

        const computeNextCompanion = (comp?: CompanionConfig): CompanionConfig => {
          const base: CompanionConfig = comp || {
            type: 'dragon',
            name: 'Ateş Kanat',
            xp: 0,
            level: 1,
            evolution_stage: 1,
            hunger: 80,
            energy: 100,
          };
          const nextXp = (base.xp || 0) + 20;
          const nextLevel = 1 + Math.floor(nextXp / 100);
          const nextStage =
            nextLevel >= 5 ? 4 : nextLevel >= 3 ? 3 : nextLevel >= 2 ? 2 : 1;
          return {
            ...base,
            xp: nextXp,
            level: nextLevel,
            evolution_stage: nextStage,
            hunger: 100,
            energy: 100,
          };
        };

        const updatedAutoCompanion = autoApprove
          ? computeNextCompanion(student.companion_config)
          : student.companion_config;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            submissions: [newSub, ...prev.submissions],
            users: autoApprove
              ? prev.users.map((u) =>
                  u.id === studentId
                    ? {
                        ...u,
                        points_balance: u.points_balance + earnedPoints,
                        companion_config: computeNextCompanion(u.companion_config),
                      }
                    : u
                )
              : prev.users,
            familySettings: autoApprove
              ? (prev.familySettings || INITIAL_FAMILY_SETTINGS).map((fs) =>
                  fs.family_id === student.family_id
                    ? {
                        ...fs,
                        family_chest_current:
                          fs.family_chest_current + earnedPoints,
                      }
                    : fs
                )
              : prev.familySettings,
          }),
          {
            familyId: student.family_id,
            sound: autoApprove ? 'victory' : 'walkie',
            alert: {
              type: autoApprove ? 'approval' : 'info',
              title: alertTitle,
              message: alertMessage,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('task_submissions').insert(newSub);
          if (autoApprove) {
            await supabase
              .from('users')
              .update({
                points_balance: student.points_balance + earnedPoints,
                companion_config: updatedAutoCompanion,
              })
              .eq('id', studentId);
            const currentChest =
              stateRef.current.familySettings?.find(
                (fs) => fs.family_id === student.family_id
              )?.family_chest_current || 0;
            await supabase
              .from('family_settings')
              .update({
                family_chest_current: currentChest + earnedPoints,
              })
              .eq('family_id', student.family_id);
          }
        }

        if (autoApprove) {
          const ttsEnabled =
            stateRef.current.familySettings?.find(
              (fs) => fs.family_id === student.family_id
            )?.tts_announcements_enabled ?? true;
          speakTurkishAnnouncement(
            `Harika haber ${student.name}! Görevin onaylandı ve hesabına ${earnedPoints} puan yüklendi!`,
            ttsEnabled
          );
        }

        return {
          autoApproved: autoApprove,
          morningComboBonus,
          submissionId: subId,
        };
      } catch (err) {
        console.error('[submitTaskCompletion] Hata:', err);
        return { autoApproved: false, morningComboBonus: 0, submissionId: '' };
      }
    },
    [commitAndBroadcast]
  );

  // 5. Atomic Task Submission Approval (with Phase 3 Companion XP/Evolution & Success Album Praise)
  const approveOrRejectSubmission = useCallback(
    async (
      submissionId: string,
      parentId: string,
      decision: 'approved' | 'rejected',
      options?: {
        featureInAlbum?: boolean;
        praiseNote?: string | null;
      }
    ): Promise<{ success: boolean; message: string }> => {
      try {
        const targetSub = stateRef.current.submissions.find((s) => s.id === submissionId);
        if (!targetSub) {
          return { success: false, message: 'Görev gönderimi bulunamadı.' };
        }
        if (targetSub.status !== 'pending') {
          return {
            success: false,
            message: 'Bu görev zaten diğer ebeveyn tarafından onaylandı/işlendi! (Çift puan koruması devrede)',
          };
        }

        const task = stateRef.current.tasks.find((t) => t.id === targetSub.task_id);
        const student = stateRef.current.users.find((u) => u.id === targetSub.user_id);
        const parent = stateRef.current.users.find((u) => u.id === parentId);
        if (!task || !student) {
          return { success: false, message: 'İlgili görev veya öğrenci bulunamadı.' };
        }

        let morningComboBonus = 0;
        if (decision === 'approved' && task.category === 'routine_morning') {
          const morningTasks = stateRef.current.tasks.filter(
            (t) =>
              t.family_id === student.family_id &&
              t.category === 'routine_morning' &&
              t.is_active &&
              (t.assigned_to === student.id || t.assigned_to === 'both')
          );
          const approvedSet = new Set(
            stateRef.current.submissions
              .filter((s) => s.user_id === student.id && s.status === 'approved')
              .map((s) => s.task_id)
          );
          approvedSet.add(task.id);
          if (morningTasks.every((mt) => approvedSet.has(mt.id))) {
            morningComboBonus = 15;
          }
        }

        const totalAwarded = decision === 'approved' ? task.points + morningComboBonus : 0;
        const coopBonus = decision === 'approved' && task.category === 'coop' ? 15 : 0;
        const featureInAlbum = Boolean(options?.featureInAlbum && decision === 'approved');
        const praiseNote =
          decision === 'approved' && options?.praiseNote?.trim()
            ? options.praiseNote.trim()
            : targetSub.parent_praise_note || null;

        const computeNextCompanion = (comp?: CompanionConfig): CompanionConfig => {
          const base: CompanionConfig = comp || {
            type: 'dragon',
            name: 'Ateş Kanat',
            xp: 0,
            level: 1,
            evolution_stage: 1,
            hunger: 80,
            energy: 100,
          };
          const nextXp = (base.xp || 0) + 20;
          const nextLevel = 1 + Math.floor(nextXp / 100);
          const nextStage =
            nextLevel >= 5 ? 4 : nextLevel >= 3 ? 3 : nextLevel >= 2 ? 2 : 1;
          return {
            ...base,
            xp: nextXp,
            level: nextLevel,
            evolution_stage: nextStage,
            hunger: 100,
            energy: 100,
          };
        };

        commitAndBroadcast(
          (prev) => {
            const current = prev.submissions.find((s) => s.id === submissionId);
            if (!current || current.status !== 'pending') return prev;

            return {
              ...prev,
              submissions: prev.submissions.map((s) =>
                s.id === submissionId
                  ? {
                      ...s,
                      status: decision,
                      approved_by: parentId,
                      is_featured_in_album: featureInAlbum || s.is_featured_in_album,
                      parent_praise_note: praiseNote,
                    }
                  : s
              ),
              users:
                decision === 'approved'
                  ? prev.users.map((u) =>
                      u.id === student.id
                        ? {
                            ...u,
                            points_balance: u.points_balance + totalAwarded + coopBonus,
                            companion_config: computeNextCompanion(u.companion_config),
                          }
                        : u
                    )
                  : prev.users,
              familySettings:
                decision === 'approved'
                  ? (prev.familySettings || INITIAL_FAMILY_SETTINGS).map((fs) =>
                      fs.family_id === student.family_id
                        ? {
                            ...fs,
                            family_chest_current:
                              fs.family_chest_current + totalAwarded + coopBonus,
                          }
                        : fs
                    )
                  : prev.familySettings,
            };
          },
          {
            familyId: student.family_id,
            sound: decision === 'approved' ? 'victory' : 'walkie',
            alert: {
              type: 'approval',
              title:
                decision === 'approved'
                  ? `✅ Görev Onaylandı! (+${totalAwarded + coopBonus} Puan & +20 Yoldaş XP)`
                  : `❌ Görev Tekrar İsteniyor`,
              message:
                decision === 'approved'
                  ? `${parent?.name || 'Ebeveyn'}, ${student.name} için "${task.title}" görevini onayladı.${
                      featureInAlbum ? ' ⭐ Başarı Albümüne Eklendi!' : ''
                    }`
                  : `${parent?.name || 'Ebeveyn'} görevin tekrar kontrol edilmesini istedi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('approve_task_submission', {
            p_submission_id: submissionId,
            p_parent_id: parentId,
            p_decision: decision,
            p_feature_in_album: featureInAlbum,
            p_praise_note: praiseNote,
          });
        }

        if (decision === 'approved') {
          const ttsEnabled =
            stateRef.current.familySettings?.find(
              (fs) => fs.family_id === student.family_id
            )?.tts_announcements_enabled ?? true;
          speakTurkishAnnouncement(
            `Harika haber ${student.name}! Görevin onaylandı ve hesabına ${
              totalAwarded + coopBonus
            } puan yüklendi!`,
            ttsEnabled
          );
        }

        return {
          success: true,
          message:
            decision === 'approved'
              ? `+${totalAwarded + coopBonus} Puan ve +20 Dijital Yoldaş XP ${student.name} hesabına aktarıldı!${
                  featureInAlbum ? ' (⭐ Başarı Albümüne eklendi!)' : ''
                }`
              : 'Görev reddedildi.',
        };
      } catch (err) {
        console.error('[approveOrRejectSubmission] Hata:', err);
        return { success: false, message: 'Onay işlemi sırasında hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  // 5B. On-the-spot Parent PIN Verification right from Student's Screen!
  const approveTaskOnSpotWithPin = useCallback(
    async (
      submissionId: string,
      enteredPin: string
    ): Promise<{ success: boolean; message: string }> => {
      try {
        const expectedPin =
          activeFamily.parent_pin || process.env.NEXT_PUBLIC_PARENT_PIN || '1234';
        if (enteredPin.trim() !== expectedPin) {
          return {
            success: false,
            message: 'Hatalı Ebeveyn PIN Kodu!',
          };
        }
        const parentUser =
          familyUsers.find((u) => u.role === 'parent') || activeUser;
        return await approveOrRejectSubmission(
          submissionId,
          parentUser.id,
          'approved'
        );
      } catch (err) {
        console.error('[approveTaskOnSpotWithPin] Hata:', err);
        return { success: false, message: 'PIN onayı sırasında hata oluştu.' };
      }
    },
    [activeFamily.parent_pin, familyUsers, activeUser, approveOrRejectSubmission]
  );

  // 6. Create Flash Quest (supports Phase 4 "İlk Kapar" Race Mode)
  const createFlashQuest = useCallback(
    async (
      assignedTo: string,
      title: string,
      points: number,
      durationMinutes: number,
      verificationType: TaskVerificationType = 'physical_check',
      isFirstComeRace: boolean = false
    ) => {
      try {
        const famId = activeFamilyRef.current;
        const isRace = Boolean(isFirstComeRace);
        const newTask: TaskItem = {
          id: `flash-${Date.now()}`,
          family_id: famId,
          assigned_to: isRace ? 'both' : assignedTo,
          title: isRace
            ? `⚡ İlk Kapar Yarışı: ${title}`
            : `⚡ ALTIN GÖREV: ${title}`,
          description: isRace
            ? `Kardeşlerden ilk "🏃‍♂️ Ben Yaparım!" butonuna basan görevi kapar ve ${durationMinutes} dakika içinde bitirirse +${points} Altın Puan kazanır!`
            : `${durationMinutes} dakika içinde tamamlayana tam ${points} Altın Puan! (Bitince fotoğraf çek veya Anne/Babayı kontrole çağır)`,
          category: 'flash_quest',
          points,
          verification_type: verificationType,
          requires_photo: false,
          duration_minutes: durationMinutes,
          is_active: true,
          due_time: `${durationMinutes} dk içinde`,
          is_first_come_race: isRace,
          claimed_by: null,
          claimed_at: null,
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            tasks: [newTask, ...prev.tasks],
          }),
          {
            familyId: famId,
            sound: 'flash',
            alert: {
              type: 'flash_quest',
              title: isRace
                ? '🏃‍♂️ İLK KAPAR KARDEŞ YARIŞ GÖREVİ DÜŞTÜ!'
                : '⚡ SÜRPRİZ ALTIN GÖREV BAŞLADI!',
              message: `${title} (${durationMinutes} dk içinde bitirene +${points} Puan!)`,
            },
          }
        );

        const ttsEnabled =
          stateRef.current.familySettings?.find((fs) => fs.family_id === famId)
            ?.tts_announcements_enabled ?? true;
        speakTurkishAnnouncement(
          isRace
            ? `Ev halkı dikkat! İlk kapar yarış görevi düştü: ${title}! İlk basan ${points} altın puanı kapar!`
            : `Ev halkı dikkat! ${points} puanlık sürpriz altın görev başladı: ${title}!`,
          ttsEnabled
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('tasks').insert(newTask);
        }
      } catch (err) {
        console.error('[createFlashQuest] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 7. Request Reward Redemption (with Phase 4 Happy Hour Discount support!)
  const requestRewardRedemption = useCallback(
    async (rewardId: string, studentId: string) => {
      try {
        const reward = stateRef.current.rewards.find((r) => r.id === rewardId);
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!reward || !student) {
          return { success: false, message: 'Ödül bulunamadı.' };
        }

        const famSettings = stateRef.current.familySettings?.find(
          (fs) => fs.family_id === student.family_id
        );
        const now = new Date();
        let discountPct = 0;
        if (
          famSettings?.happy_hour_discount_percent &&
          famSettings.happy_hour_discount_percent > 0 &&
          (!famSettings.happy_hour_ends_at ||
            new Date(famSettings.happy_hour_ends_at).getTime() > now.getTime())
        ) {
          discountPct = famSettings.happy_hour_discount_percent;
        } else if (now.getDay() === 5 && now.getHours() >= 18 && now.getHours() < 20) {
          discountPct = 30;
        }

        const effectiveCost =
          discountPct > 0
            ? Math.max(5, Math.round((reward.cost_points * (100 - discountPct)) / 100))
            : reward.cost_points;

        if (student.points_balance < effectiveCost) {
          return {
            success: false,
            message: `Puanın yetmiyor! ${effectiveCost - student.points_balance} puana daha ihtiyacın var.`,
          };
        }

        const newRedemption: RewardRedemption = {
          id: `red-${Date.now()}-${Math.random().toString(36).slice(2, 5)}`,
          family_id: student.family_id,
          reward_id: rewardId,
          user_id: studentId,
          status: 'pending',
          approved_by: null,
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            redemptions: [newRedemption, ...prev.redemptions],
          }),
          {
            familyId: student.family_id,
            sound: 'walkie',
            alert: {
              type: 'info',
              title: `🎁 Ödül Talebi: ${student.name}${
                discountPct > 0 ? ` (%${discountPct} Happy Hour İndirimli!)` : ''
              }`,
              message: `${student.name}, "${reward.title}" (${effectiveCost} P) ödülünü almak istiyor!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('reward_redemptions').insert(newRedemption);
        }

        return {
          success: true,
          message:
            discountPct > 0
              ? `🏷️ %${discountPct} İndirimli (${effectiveCost} Puan) ödül talebin Anne ve Babaya gönderildi!`
              : 'Ödül talebin Anne ve Babaya gönderildi! Onaylandığında anında aktif olacak.',
        };
      } catch (err) {
        console.error('[requestRewardRedemption] Hata:', err);
        return { success: false, message: 'Ödül talebi gönderilirken hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  // 8. Approve or Reject Reward Redemption (with Phase 4 Happy Hour Discount support!)
  const approveOrRejectRedemption = useCallback(
    async (
      redemptionId: string,
      parentId: string,
      decision: 'approved' | 'rejected'
    ) => {
      try {
        const red = stateRef.current.redemptions.find((r) => r.id === redemptionId);
        if (!red || red.status !== 'pending') {
          return { success: false, message: 'Bu ödül talebi zaten işlenmiş.' };
        }
        const reward = stateRef.current.rewards.find((r) => r.id === red.reward_id);
        const student = stateRef.current.users.find((u) => u.id === red.user_id);
        if (!reward || !student) {
          return { success: false, message: 'Ödül veya öğrenci bulunamadı.' };
        }

        const famSettings = stateRef.current.familySettings?.find(
          (fs) => fs.family_id === student.family_id
        );
        const now = new Date();
        let discountPct = 0;
        if (
          famSettings?.happy_hour_discount_percent &&
          famSettings.happy_hour_discount_percent > 0 &&
          (!famSettings.happy_hour_ends_at ||
            new Date(famSettings.happy_hour_ends_at).getTime() > now.getTime())
        ) {
          discountPct = famSettings.happy_hour_discount_percent;
        } else if (now.getDay() === 5 && now.getHours() >= 18 && now.getHours() < 20) {
          discountPct = 30;
        }

        const effectiveCost =
          discountPct > 0
            ? Math.max(5, Math.round((reward.cost_points * (100 - discountPct)) / 100))
            : reward.cost_points;

        if (decision === 'approved' && student.points_balance < effectiveCost) {
          return { success: false, message: 'Öğrencinin puan bakiyesi yetersiz.' };
        }

        const unlockMinutes =
          decision === 'approved' && reward.auto_action?.type === 'unlock_screen'
            ? reward.auto_action.minutes || 30
            : null;

        const unlockedEndsAt = unlockMinutes
          ? new Date(Date.now() + unlockMinutes * 60 * 1000).toISOString()
          : student.state_ends_at;

        commitAndBroadcast(
          (prev) => {
            const current = prev.redemptions.find((r) => r.id === redemptionId);
            if (!current || current.status !== 'pending') return prev;

            return {
              ...prev,
              redemptions: prev.redemptions.map((r) =>
                r.id === redemptionId
                  ? { ...r, status: decision, approved_by: parentId }
                  : r
              ),
              users:
                decision === 'approved'
                  ? prev.users.map((u) =>
                      u.id === student.id
                        ? {
                            ...u,
                            points_balance: Math.max(0, u.points_balance - effectiveCost),
                            current_state: unlockMinutes ? 'FREE_TIME' : u.current_state,
                            state_ends_at: unlockMinutes ? unlockedEndsAt : u.state_ends_at,
                          }
                        : u
                    )
                  : prev.users,
            };
          },
          {
            familyId: student.family_id,
            sound: decision === 'approved' ? 'victory' : 'walkie',
            alert: {
              type: 'approval',
              title:
                decision === 'approved'
                  ? `🎉 Ödül Onaylandı: ${reward.title}`
                  : 'Ödül Talebi Reddedildi',
              message:
                decision === 'approved' && unlockMinutes
                  ? `${student.name} için tüm cihazların kilidi otomatik olarak ${unlockMinutes} dakika boyunca açıldı (FREE_TIME)!`
                  : `${student.name} ödülü kullanabilir.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('approve_reward_redemption', {
            p_redemption_id: redemptionId,
            p_parent_id: parentId,
            p_decision: decision,
          });
        }

        return { success: true, message: 'Ödül işlemi tamamlandı.' };
      } catch (err) {
        console.error('[approveOrRejectRedemption] Hata:', err);
        return { success: false, message: 'Ödül onayı sırasında hata oluştu.' };
      }
    },
    [commitAndBroadcast]
  );

  // 9. Piggy Bank Deposit & Sunday +20% Interest Bonus
  const depositToPiggyBank = useCallback(
    async (studentId: string, amount: number) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student || amount <= 0 || student.points_balance < amount) return;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance - amount,
                    piggy_bank_balance: u.piggy_bank_balance + amount,
                  }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `💎 Birikim Kasasına +${amount} Puan Eklendi!`,
              message: `${student.name} puanlarını biriktiriyor! Pazar gecesi %20 sabır bonusu kazanacak.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({
              points_balance: student.points_balance - amount,
              piggy_bank_balance: student.piggy_bank_balance + amount,
            })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[depositToPiggyBank] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  const triggerSundayPiggyBonus = useCallback(async () => {
    try {
      const famId = activeFamilyRef.current;
      commitAndBroadcast(
        (prev) => ({
          ...prev,
          users: prev.users.map((u) =>
            (u.family_id || 'fam-ozdemir') === famId &&
            u.role === 'child' &&
            u.piggy_bank_balance > 0
              ? { ...u, piggy_bank_balance: Math.round(u.piggy_bank_balance * 1.2) }
              : u
          ),
        }),
        {
          familyId: famId,
          sound: 'victory',
          alert: {
            type: 'approval',
            title: '💎 Pazar Gecesi +%20 Birikim Kasası Sabır Bonusu!',
            message: 'Ailenizdeki çocukların birikim kasalarına %20 sabır ödülü eklendi!',
          },
        }
      );

      if (isSupabaseConfigured && supabase) {
        await supabase.rpc('apply_sunday_piggy_bank_bonus', {
          p_family_id: famId,
        });
      }
    } catch (err) {
      console.error('[triggerSundayPiggyBonus] Hata:', err);
    }
  }, [commitAndBroadcast]);

  // 10. End-of-day Zero Violation Shield Bonus
  const triggerDailyZeroViolationBonus = useCallback(async () => {
    try {
      const famId = activeFamilyRef.current;
      commitAndBroadcast(
        (prev) => ({
          ...prev,
          users: prev.users.map((u) =>
            (u.family_id || 'fam-ozdemir') === famId && u.role === 'child'
              ? {
                  ...u,
                  points_balance: u.points_balance + (u.daily_shields === 3 ? 20 : 0),
                  daily_shields: 3,
                }
              : u
          ),
        }),
        {
          familyId: famId,
          sound: 'victory',
          alert: {
            type: 'approval',
            title: '🛡️ Gün Sonu Kalkan Kontrolü & +20 Puan Bonus!',
            message: 'Kalkanlarını koruyan çocuklarınıza +20 Sıfır İhlal Bonusu verildi ve 3 kalkan yenilendi!',
          },
        }
      );

      if (isSupabaseConfigured && supabase) {
        await supabase.rpc('award_daily_shield_bonus', {
          p_family_id: famId,
        });
      }
    } catch (err) {
      console.error('[triggerDailyZeroViolationBonus] Hata:', err);
    }
  }, [commitAndBroadcast]);

  // 11. Spin Lucky Wheel
  const spinLuckyWheel = useCallback(
    async (studentId: string) => {
      const prizes = [
        { label: '🌟 +25 Süper Puan', bonusPoints: 25 },
        { label: '💎 +50 Kristal Puan', bonusPoints: 50 },
        { label: '🚀 +35 Hız Bonusu', bonusPoints: 35 },
        { label: '👑 +75 Efsane Hazine!', bonusPoints: 75 },
        { label: '🍭 +30 Tatlı Sürpriz Puanı', bonusPoints: 30 },
      ];
      const chosen = prizes[Math.floor(Math.random() * prizes.length)];
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance + chosen.bonusPoints,
                    wheel_spins_available: Math.max(0, u.wheel_spins_available - 1),
                  }
                : u
            ),
          }),
          {
            familyId: student?.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `🎡 Şans Çarkı Ödülü: ${chosen.label}`,
              message: `5 Günlük Seri Çarkından +${chosen.bonusPoints} Puan kazanıldı!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase && student) {
          await supabase
            .from('users')
            .update({
              points_balance: student.points_balance + chosen.bonusPoints,
              wheel_spins_available: Math.max(0, student.wheel_spins_available - 1),
            })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[spinLuckyWheel] Hata:', err);
      }

      return chosen;
    },
    [commitAndBroadcast]
  );

  // 12. Focus Shield & Violation Sensor
  const recordViolation = useCallback(
    async (
      studentId: string,
      violationType: ViolationType,
      customDeviceName?: string
    ) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student || student.current_state === 'FROZEN_HOLIDAY') return;

        const studentDevice =
          stateRef.current.devices.find((d) => d.user_id === studentId) ||
          stateRef.current.devices[0];

        const violationLabels: Record<ViolationType, string> = {
          ios_touch_detected: 'telefona/tablete dokundu (Odaklanma Kalkanı İhlali)',
          ios_app_minimized: 'görev ekranından çıktı / uygulamayı alta attı',
          pc_mouse_move: 'ders saatinde PC faresini hareket ettirdi',
          pc_key_press: 'ders saatinde PC klavyesini kullandı',
          agent_offline: 'PC koruma ajanını kapattı',
          unauthorized_app_opened: 'bilgisayarlı ders modunda izin verilmeyen uygulama/oyun açtı',
          clock_tamper_attempt: 'cihaz saatini ileri/geri alarak sayaç hilesi denedi (Anti-Cheat)',
          high_noise_detected: 'ortam ses seviyesi 8 sn boyunca gürültü/bağırma eşiğini aştı (>dB)',
          watchdog_agent_restarted: 'PC koruma ajanını zorla kapatmaya çalıştı (İkiz Nöbetçi tarafından 0.5 sn içinde yeniden başlatıldı)',
        };

        const newLog: ViolationLog = {
          id: `viol-${Date.now()}-${Math.random().toString(36).slice(2, 5)}`,
          family_id: student.family_id,
          user_id: studentId,
          device_id: studentDevice?.id || 'unknown-device',
          violation_type: violationType,
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            violations: [newLog, ...prev.violations],
            users: prev.users.map((u) =>
              u.id === studentId
                ? { ...u, daily_shields: Math.max(0, u.daily_shields - 1) }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'violation',
            alert: {
              type: 'violation',
              title: `🚨 UYARI: ${student.name} Kalkan Kırdı!`,
              message: `${student.name} ders saatinde ${violationLabels[violationType]}${
                customDeviceName ? ` (${customDeviceName})` : ''
              }! 1 Kalkan kırıldı.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase && studentDevice) {
          await supabase.rpc('record_violation_and_break_shield', {
            p_user_id: studentId,
            p_device_id: studentDevice.id,
            p_violation_type: violationType,
          });
        }
      } catch (err) {
        console.error('[recordViolation] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 13. Smart Wake-Up Alarm Trigger & Challenge Completion
  const triggerWakeUpAlarm = useCallback(
    async (studentId: string) => {
      await setStudentState(studentId, 'WAKE_UP_ALARM', 15);
    },
    [setStudentState]
  );

  const completeWakeUpChallenge = useCallback(
    async (studentId: string) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        soundEngine.stopWakeUpAlarmLoop();

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    current_state: 'ROUTINE_TIME',
                    state_ends_at: new Date(Date.now() + 25 * 60 * 1000).toISOString(),
                    points_balance: u.points_balance + 10,
                  }
                : u
            ),
          }),
          {
            familyId: student?.family_id,
            sound: 'victory',
            alert: {
              type: 'wakeup',
              title: `☀️ ${student?.name || 'Öğrenci'} uyandı ve güne başladı!`,
              message: `${student?.name || 'Öğrenci'} akıllı alarm görevini başarıyla çözdü (+10 Erken Kalkış Puanı) ve Sabah Rutini moduna geçti!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({
              current_state: 'ROUTINE_TIME',
              state_ends_at: new Date(Date.now() + 25 * 60 * 1000).toISOString(),
            })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[completeWakeUpChallenge] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 14. Direct Message & Walkie-Talkie Audio System
  const sendDirectMessage = useCallback(
    async (
      senderId: string,
      receiverId: string,
      messageType: 'text' | 'audio' | 'quick_request',
      content: string,
      audioUrl: string | null = null
    ) => {
      try {
        const sender = stateRef.current.users.find((u) => u.id === senderId);
        const famId = sender?.family_id || activeFamilyRef.current;
        const newMsg: DirectMessage = {
          id: `msg-${Date.now()}-${Math.random().toString(36).slice(2, 5)}`,
          family_id: famId,
          sender_id: senderId,
          receiver_id: receiverId,
          message_type: messageType,
          content,
          audio_url: audioUrl,
          is_read: false,
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            messages: [...prev.messages, newMsg],
          }),
          {
            familyId: famId,
            sound: 'walkie',
            alert: {
              type: 'info',
              title: `📻 Telsiz / DM (${sender?.name || 'Aile Üyesi'})`,
              message: messageType === 'audio' ? '🎙️ Sesli Telsiz Mesajı Gönderdi' : content,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('messages').insert(newMsg);
        }
      } catch (err) {
        console.error('[sendDirectMessage] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 15. Update PC Active Window Title
  const updateDeviceWindowTitle = useCallback(
    async (deviceId: string, windowTitle: string) => {
      try {
        commitAndBroadcast((prev) => ({
          ...prev,
          devices: prev.devices.map((d) =>
            d.id === deviceId
              ? {
                  ...d,
                  active_window_title: windowTitle,
                  last_activity_at: new Date().toISOString(),
                }
              : d
          ),
        }));

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('devices')
            .update({
              active_window_title: windowTitle,
              last_activity_at: new Date().toISOString(),
            })
            .eq('id', deviceId);
        }
      } catch (err) {
        console.error('[updateDeviceWindowTitle] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 16. Phase 2: Student Task Proposal (Tersine Görev Teklifi)
  const proposeTaskByStudent = useCallback(
    async ({
      studentId,
      title,
      description,
      requestedPoints,
    }: {
      studentId: string;
      title: string;
      description: string;
      requestedPoints: number;
    }) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        const famId = student?.family_id || activeFamilyRef.current;
        const proposedTask: TaskItem = {
          id: `task-prop-${Date.now()}`,
          family_id: famId,
          assigned_to: studentId,
          title: title.trim(),
          description:
            description.trim() ||
            `${student?.name || 'Öğrenci'} tarafından önerilen ekstra sorumluluk görevi.`,
          category: 'chore',
          points: Math.max(5, Math.min(200, requestedPoints)),
          verification_type: 'physical_check',
          requires_photo: false,
          duration_minutes: 20,
          is_active: true,
          due_time: 'Bugün',
          created_by: studentId,
          proposal_status: 'pending_parent_approval',
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            tasks: [proposedTask, ...prev.tasks],
          }),
          {
            familyId: famId,
            sound: 'walkie',
            alert: {
              type: 'info',
              title: `💡 Yeni Görev Önerisi! (${student?.name || 'Öğrenci'})`,
              message: `${student?.name || 'Öğrenci'}, "${proposedTask.title}" (+${proposedTask.points} P) görevini yapmayı teklif ediyor!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('tasks').insert(proposedTask);
        }
      } catch (err) {
        console.error('[proposeTaskByStudent] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  const reviewTaskProposal = useCallback(
    async (taskId: string, decision: 'approved' | 'rejected') => {
      try {
        const target = stateRef.current.tasks.find((t) => t.id === taskId);
        if (!target) return;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            tasks: prev.tasks.map((t) =>
              t.id === taskId
                ? {
                    ...t,
                    proposal_status: decision,
                    is_active: decision === 'approved',
                  }
                : t
            ),
          }),
          {
            familyId: target.family_id,
            sound: decision === 'approved' ? 'victory' : 'walkie',
            alert: {
              type: 'approval',
              title:
                decision === 'approved'
                  ? `✅ Görev Teklifi Onaylandı: ${target.title}`
                  : `❌ Görev Teklifi Reddedildi`,
              message:
                decision === 'approved'
                  ? `"${target.title}" (+${target.points} P) görevi aktif görev listesine eklendi!`
                  : `"${target.title}" teklifi kabul edilmedi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('tasks')
            .update({
              proposal_status: decision,
              is_active: decision === 'approved',
            })
            .eq('id', taskId);
        }
      } catch (err) {
        console.error('[reviewTaskProposal] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 17. Phase 2: Sibling Point Gifting & Golden Heart Badge (`transfer_points_between_siblings`)
  const transferPointsBetweenSiblings = useCallback(
    async (
      senderId: string,
      receiverId: string,
      amount: number,
      message: string
    ): Promise<{
      success: boolean;
      message: string;
      awardedGoldenHeart: boolean;
    }> => {
      try {
        const sender = stateRef.current.users.find((u) => u.id === senderId);
        const receiver = stateRef.current.users.find((u) => u.id === receiverId);
        if (!sender || !receiver) {
          return {
            success: false,
            message: 'Gönderen veya alıcı kardeş bulunamadı.',
            awardedGoldenHeart: false,
          };
        }
        if (amount <= 0 || sender.points_balance < amount) {
          return {
            success: false,
            message: 'Puan bakiyen bu hediye transferi için yeterli değil.',
            awardedGoldenHeart: false,
          };
        }

        const goldenHeartBadge = '💛 Altın Kalp Rozeti';
        const existingBadges = Array.isArray(sender.badges) ? sender.badges : [];
        const awardedGoldenHeart = !existingBadges.includes(goldenHeartBadge);
        const updatedBadges = awardedGoldenHeart
          ? [...existingBadges, goldenHeartBadge]
          : existingBadges;

        const transferRecord: PointTransfer = {
          id: `ptrans-${Date.now()}`,
          family_id: sender.family_id,
          sender_child_id: senderId,
          receiver_child_id: receiverId,
          amount,
          message: message.trim() || 'Kardeşim için hediye puan! 💛',
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            pointTransfers: [transferRecord, ...(prev.pointTransfers || [])],
            users: prev.users.map((u) => {
              if (u.id === senderId) {
                return {
                  ...u,
                  points_balance: u.points_balance - amount,
                  badges: updatedBadges,
                };
              }
              if (u.id === receiverId) {
                return {
                  ...u,
                  points_balance: u.points_balance + amount,
                };
              }
              return u;
            }),
          }),
          {
            familyId: sender.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `💛 Kardeş Dayanışması: ${sender.name} -> ${receiver.name} (+${amount} P)`,
              message: `${sender.name}, kardeşi ${receiver.name}'e ${amount} Puan hediye etti!${
                awardedGoldenHeart ? ' 🏅 Altın Kalp Rozeti Kazandı!' : ''
              }`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('transfer_points_between_siblings', {
            sender_id: senderId,
            receiver_id: receiverId,
            transfer_amount: amount,
            note: transferRecord.message,
          });
        }

        return {
          success: true,
          message: `${receiver.name} hesabına +${amount} Puan hediye edildi!`,
          awardedGoldenHeart,
        };
      } catch (err) {
        console.error('[transferPointsBetweenSiblings] Hata:', err);
        return {
          success: false,
          message: 'Puan transferi sırasında hata oluştu.',
          awardedGoldenHeart: false,
        };
      }
    },
    [commitAndBroadcast]
  );

  // 18. Phase 2: Add Physical QR Station (`qr_stations`)
  const addQRStation = useCallback(
    async ({
      stationCode,
      title,
      linkedAction,
    }: {
      stationCode: string;
      title: string;
      linkedAction: QRStationLinkedAction;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        const cleanCode = stationCode
          .trim()
          .toUpperCase()
          .replace(/\s+/g, '_');
        const newStation: QRStation = {
          id: `qr-${Date.now()}`,
          family_id: famId,
          station_code: cleanCode || `STATION_${Date.now()}`,
          title: title.trim(),
          linked_action: linkedAction,
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            qrStations: [...(prev.qrStations || []), newStation],
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `📷 Yeni Fiziksel QR İstasyonu: ${newStation.title}`,
              message: `${newStation.station_code} kodu oluşturuldu, şimdi yazdırabilirsiniz.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('qr_stations').insert(newStation);
        }
      } catch (err) {
        console.error('[addQRStation] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 19. Phase 2: Update Student Whitelist Config for COMPUTER_STUDY mode
  const updateStudentWhitelist = useCallback(
    async (studentId: string, whitelistConfig: WhitelistConfig) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId ? { ...u, whitelist_config: whitelistConfig } : u
            ),
          }),
          {
            familyId: student?.family_id,
            sound: 'walkie',
            alert: {
              type: 'info',
              title: `💻 Bilgisayarlı Ders İzin Listesi Güncellendi (${student?.name || ''})`,
              message: `İzinli uygulamalar (${whitelistConfig.allowed_exes.join(', ')}) kaydedildi.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({ whitelist_config: whitelistConfig })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[updateStudentWhitelist] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 20. Phase 2: Update Family Co-op Chest Goal & Reward Title
  const updateFamilyChestConfig = useCallback(
    async ({ goal, rewardTitle }: { goal: number; rewardTitle: string }) => {
      try {
        const famId = activeFamilyRef.current;
        commitAndBroadcast(
          (prev) => ({
            ...prev,
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === famId
                  ? {
                      ...fs,
                      family_chest_goal: Math.max(100, goal),
                      family_chest_reward_title: rewardTitle.trim(),
                    }
                  : fs
            ),
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: '🏆 Aile Hazine Sandığı Hedefi Güncellendi!',
              message: `Yeni ortak hedef: ${rewardTitle.trim()} (${goal} Puan)`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({
              family_chest_goal: Math.max(100, goal),
              family_chest_reward_title: rewardTitle.trim(),
            })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[updateFamilyChestConfig] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 21. Phase 2: Offline Emergency 6-Digit Master PIN (SHA-256)
  const updateOfflineMasterPin = useCallback(
    async (rawSixDigitPin: string) => {
      try {
        const famId = activeFamilyRef.current;
        const hashHex = await computeSha256Hex(rawSixDigitPin.trim());

        if (typeof window !== 'undefined') {
          localStorage.setItem(`family_to_study_offline_pin_${famId}`, hashHex);
        }

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === famId
                  ? { ...fs, offline_master_pin_hash: hashHex }
                  : fs
            ),
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: '🔐 6 Haneli Acil Durum Offline PIN Kaydedildi!',
              message:
                'SHA-256 özeti veritabanına ve tüm cihazların localStorage önbelleğine senkronize edildi.',
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({ offline_master_pin_hash: hashHex })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[updateOfflineMasterPin] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  const unlockWithOfflineMasterPin = useCallback(
    async (
      studentId: string,
      enteredSixDigitPin: string
    ): Promise<{ success: boolean; message: string }> => {
      try {
        const famId = activeFamilyRef.current;
        const enteredHash = await computeSha256Hex(enteredSixDigitPin.trim());
        const cachedLocalHash =
          typeof window !== 'undefined'
            ? localStorage.getItem(`family_to_study_offline_pin_${famId}`)
            : null;
        const expectedHash =
          familySettings.offline_master_pin_hash ||
          cachedLocalHash ||
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92'; // 123456

        if (enteredHash !== expectedHash) {
          return {
            success: false,
            message: 'Hatalı 6 Haneli Acil Durum Offline PIN Kodu!',
          };
        }

        await setStudentState(studentId, 'FREE_TIME', null);
        return {
          success: true,
          message: 'Acil Durum Offline PIN doğrulandı! Cihaz kilidi açıldı.',
        };
      } catch (err) {
        console.error('[unlockWithOfflineMasterPin] Hata:', err);
        return {
          success: false,
          message: 'Offline PIN doğrulaması sırasında hata oluştu.',
        };
      }
    },
    [familySettings.offline_master_pin_hash, setStudentState]
  );

  // 22. Phase 3: Grace Period "+3 Minute Extension" Joker (`use_grace_period_extension`)
  const useGracePeriodExtension = useCallback(
    async (studentId: string): Promise<{ success: boolean; message: string }> => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) {
          return { success: false, message: 'Öğrenci bulunamadı.' };
        }
        if (student.grace_used_today) {
          return {
            success: false,
            message: 'Bugünkü +3 dakika uzatma jokerini zaten kullandın.',
          };
        }
        if (student.points_balance < 10) {
          return {
            success: false,
            message: '+3 dakika uzatma jokeri için en az 10 puan gereklidir.',
          };
        }

        const currentEndsMs = student.state_ends_at
          ? new Date(student.state_ends_at).getTime()
          : 0;
        const baseMs = Math.max(Date.now() + serverTimeOffset, currentEndsMs);
        const newEndsIso = new Date(baseMs + 3 * 60 * 1000).toISOString();

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance - 10,
                    grace_used_today: true,
                    state_ends_at: newEndsIso,
                  }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `⏱️ ${student.name} +3 Dakika Oyun Kaydetme Jokeri Aldı!`,
              message:
                '10 Puan karşılığında +3 dk uzatma tanımlandı. Süre bitmeden kendi isteğiyle çıkarsa 10 puan iade + 5 irade bonusu kazanacak!',
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('use_grace_period_extension', {
            p_user_id: studentId,
          });
        }

        return {
          success: true,
          message:
            '⏱️ +3 Dakika uzatma eklendi! Oyununu kaydedip süre bitmeden çıkarsan 10 puanın iade edilir ve +5 İrade Bonusu kazanırsın!',
        };
      } catch (err) {
        console.error('[useGracePeriodExtension] Hata:', err);
        return { success: false, message: 'Uzatma alınırken hata oluştu.' };
      }
    },
    [commitAndBroadcast, serverTimeOffset]
  );

  // 23. Phase 3: Voluntary Early Lock Refund (`voluntary_early_lock_refund`)
  const voluntaryEarlyLockRefund = useCallback(
    async (studentId: string): Promise<{ success: boolean; message: string }> => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) {
          return { success: false, message: 'Öğrenci bulunamadı.' };
        }

        const lockEndsIso = new Date(
          Date.now() + serverTimeOffset + 40 * 60 * 1000
        ).toISOString();

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance + 15,
                    current_state: 'STUDY_TIME',
                    state_ends_at: lockEndsIso,
                  }
                : u
            ),
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === student.family_id
                  ? { ...fs, family_chest_current: fs.family_chest_current + 5 }
                  : fs
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `🏅 Harika Öz-Kontrol! ${student.name} Kendi İsteğiyle Çıktı (+15 Puan)`,
              message: `${student.name} oyununu kaydedip süre bitmeden kendi rızasıyla ders moduna geçti! 10 Puan iadesi + 5 İrade Bonusu kazandı!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('voluntary_early_lock_refund', {
            p_user_id: studentId,
          });
        }

        return {
          success: true,
          message:
            '🎉 Tebrikler! Kendi isteğinle çıktığın için 10 puanın iade edildi ve +5 İrade Bonusu kazandın (+15 Puan)!',
        };
      } catch (err) {
        console.error('[voluntaryEarlyLockRefund] Hata:', err);
        return { success: false, message: 'İşlem sırasında hata oluştu.' };
      }
    },
    [commitAndBroadcast, serverTimeOffset]
  );

  // 24. Phase 3: Award Health / Posture / Water Break Points (+2 or +5 Points)
  const awardHealthPoints = useCallback(
    async (studentId: string, points: number, reason: string) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student || points <= 0) return;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance + points,
                    companion_config: u.companion_config
                      ? {
                          ...u.companion_config,
                          energy: Math.min(100, (u.companion_config.energy || 80) + 10),
                        }
                      : u.companion_config,
                  }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'info',
              title: `💚 Sağlık Bonusu: ${student.name} (+${points} Puan)`,
              message: reason,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({ points_balance: student.points_balance + points })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[awardHealthPoints] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 25. Phase 3: Update Digital Companion Config (Type / Name / XP / Hunger)
  const updateCompanionConfig = useCallback(
    async (studentId: string, updates: Partial<CompanionConfig>) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) return;
        const base: CompanionConfig = student.companion_config || {
          type: 'dragon',
          name: 'Ateş Kanat',
          xp: 120,
          level: 2,
          evolution_stage: 2,
          hunger: 90,
          energy: 95,
        };
        const nextComp: CompanionConfig = { ...base, ...updates };

        commitAndBroadcast((prev) => ({
          ...prev,
          users: prev.users.map((u) =>
            u.id === studentId ? { ...u, companion_config: nextComp } : u
          ),
        }));

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({ companion_config: nextComp })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[updateCompanionConfig] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 26. Phase 3: Upsert Weekly School Schedule (`school_schedules`)
  const upsertSchoolSchedule = useCallback(
    async (schedule: Omit<SchoolScheduleItem, 'id' | 'family_id'>) => {
      try {
        const famId = activeFamilyRef.current;
        const newId = `sch-${schedule.user_id}-${schedule.day_of_week}`;
        const fullItem: SchoolScheduleItem = {
          id: newId,
          family_id: famId,
          ...schedule,
        };

        commitAndBroadcast(
          (prev) => {
            const existingList = prev.schoolSchedules || INITIAL_SCHOOL_SCHEDULES;
            const filtered = existingList.filter(
              (s) =>
                !(
                  s.user_id === schedule.user_id &&
                  s.day_of_week === schedule.day_of_week
                )
            );
            return {
              ...prev,
              schoolSchedules: [...filtered, fullItem],
            };
          },
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: '🎒 Haftalık Okul & Çanta Programı Güncellendi!',
              message: `${schedule.reminder_note || 'Yeni ders programı kaydedildi.'}`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('school_schedules').upsert(fullItem, {
            onConflict: 'user_id,day_of_week',
          });
        }
      } catch (err) {
        console.error('[upsertSchoolSchedule] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 27. Phase 3: Update Family Weather Coordinates & Noise Threshold (dB)
  const updateFamilyWeatherAndNoiseConfig = useCallback(
    async ({
      cityLat,
      cityLon,
      noiseThresholdDb,
    }: {
      cityLat: number;
      cityLon: number;
      noiseThresholdDb: number;
    }) => {
      try {
        const famId = activeFamilyRef.current;
        commitAndBroadcast(
          (prev) => ({
            ...prev,
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === famId
                  ? {
                      ...fs,
                      city_lat: cityLat,
                      city_lon: cityLon,
                      noise_threshold_db: noiseThresholdDb,
                    }
                  : fs
            ),
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: '🌤️ Hava Durumu Konumu & 🔊 Gürültü Eşiği Güncellendi!',
              message: `Koordinat: (${cityLat}, ${cityLon}) • Gürültü Sınırı: ${noiseThresholdDb} dB`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({
              city_lat: cityLat,
              city_lon: cityLon,
              noise_threshold_db: noiseThresholdDb,
            })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[updateFamilyWeatherAndNoiseConfig] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // =========================================================================
  // PHASE 4 METHODS (Autopilot, Court of Appeals, Dynamic Economy, Active Break & Weekly Interview)
  // =========================================================================

  // 28. Phase 4: Submit Appeal (Adalet Divanı / Hakem Heyetine İtiraz)
  const submitAppeal = useCallback(
    async ({
      studentId,
      violationId = null,
      submissionId = null,
      reasonText,
      audioUrl = null,
    }: {
      studentId: string;
      violationId?: string | null;
      submissionId?: string | null;
      reasonText: string;
      audioUrl?: string | null;
    }) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) {
          return { success: false, message: 'Öğrenci profili bulunamadı.' };
        }
        if (student.appeal_used_today) {
          return {
            success: false,
            message: '⚖️ Bugünkü 1 kez Hakem Heyetine İtiraz hakkını zaten kullandın!',
          };
        }
        if (!reasonText.trim() && !audioUrl) {
          return {
            success: false,
            message: 'Lütfen savunma metni yaz veya 15 saniyelik ses kaydı ekle.',
          };
        }

        const newAppeal: AppealRecord = {
          id: `app-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          family_id: student.family_id,
          user_id: studentId,
          violation_id: violationId,
          submission_id: submissionId,
          reason_text:
            reasonText.trim() || '🎙️ Sesli savunma kaydı gönderildi.',
          audio_url: audioUrl,
          status: 'pending',
          reviewed_by: null,
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            appeals: [newAppeal, ...(prev.appeals || INITIAL_APPEALS)],
            users: prev.users.map((u) =>
              u.id === studentId ? { ...u, appeal_used_today: true } : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'walkie',
            alert: {
              type: 'info',
              title: `⚖️ Adalet Divanı Çağrısı: ${student.name} İtiraz Etti!`,
              message: `"${newAppeal.reason_text}" — Ebeveyn panelinden savunmayı dinleyip karar verebilirsiniz.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('appeals').insert(newAppeal);
          await supabase
            .from('users')
            .update({ appeal_used_today: true })
            .eq('id', studentId);
        }

        return {
          success: true,
          message:
            '⚖️ İtirazın ve savunman Adalet Divanına (Anne/Babaya) iletildi! Haklı bulunursan kalkanın tamir edilecek.',
        };
      } catch (err) {
        console.error('[submitAppeal] Hata:', err);
        return {
          success: false,
          message: 'İtiraz gönderilirken bir hata oluştu.',
        };
      }
    },
    [commitAndBroadcast]
  );

  // 29. Phase 4: Resolve Appeal (`resolve_appeal` RPC + Shield Repair Celebration)
  const resolveAppeal = useCallback(
    async (
      appealId: string,
      parentId: string,
      decision: 'accepted' | 'rejected'
    ) => {
      try {
        const appeal = (stateRef.current.appeals || INITIAL_APPEALS).find(
          (a) => a.id === appealId
        );
        if (!appeal || appeal.status !== 'pending') {
          return {
            success: false,
            message: 'Bu itiraz zaten sonuçlandırılmış.',
            shieldRestored: false,
          };
        }

        const student = stateRef.current.users.find(
          (u) => u.id === appeal.user_id
        );
        const shieldRestored = decision === 'accepted';

        if (shieldRestored && student) {
          setLastRestoredShieldStudentId(student.id);
        }

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            appeals: (prev.appeals || INITIAL_APPEALS).map((a) =>
              a.id === appealId
                ? { ...a, status: decision, reviewed_by: parentId }
                : a
            ),
            violations:
              shieldRestored && appeal.violation_id
                ? prev.violations.filter((v) => v.id !== appeal.violation_id)
                : prev.violations,
            users: prev.users.map((u) => {
              if (u.id !== appeal.user_id) return u;
              if (!shieldRestored) return u;
              return {
                ...u,
                daily_shields: Math.min(3, u.daily_shields + 1),
                points_balance: u.points_balance + 10,
              };
            }),
          }),
          {
            familyId: appeal.family_id,
            sound: shieldRestored ? 'victory' : 'violation',
            alert: {
              type: shieldRestored ? 'approval' : 'violation',
              title: shieldRestored
                ? `⚖️ Adalet Yerini Buldu! ${student?.name || 'Öğrenci'} Haklı Bulundu! 🛡️✨`
                : `⚖️ Hakem Heyeti Kararı: İtiraz Reddedildi`,
              message: shieldRestored
                ? `${student?.name || 'Öğrenci'} savunmasında haklı bulundu! Kırılan kalkanı parlayarak tamir edildi (+1🛡️) ve +10 Adalet Puanı eklendi!`
                : 'Hakem heyeti savunmayı inceledi ve mevcut kararı onayladı.',
            },
          }
        );

        const ttsEnabled =
          stateRef.current.familySettings?.find(
            (fs) => fs.family_id === appeal.family_id
          )?.tts_announcements_enabled ?? true;
        if (shieldRestored && student) {
          speakTurkishAnnouncement(
            `Adalet Divanı kararı: ${student.name} savunmasında haklı bulundu! Kalkanın tamir edildi ve 10 puan eklendi!`,
            ttsEnabled
          );
        }

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('resolve_appeal', {
            p_appeal_id: appealId,
            p_parent_id: parentId,
            p_decision: decision,
          });
        }

        return {
          success: true,
          message: shieldRestored
            ? `🛡️ ${student?.name || 'Öğrenci'} haklı bulundu! Kalkan tamir edildi (+1🛡️) ve +10 Puan verildi.`
            : 'İtiraz reddedildi olarak işaretlendi.',
          shieldRestored,
        };
      } catch (err) {
        console.error('[resolveAppeal] Hata:', err);
        return {
          success: false,
          message: 'İtiraz karara bağlanırken hata oluştu.',
          shieldRestored: false,
        };
      }
    },
    [commitAndBroadcast]
  );

  // 30. Phase 4: Claim First-Come Race Task Atomically (`claim_race_task_atomic`)
  const claimRaceTaskAtomic = useCallback(
    async (taskId: string, studentId: string) => {
      try {
        const task = stateRef.current.tasks.find((t) => t.id === taskId);
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!task || !student) {
          return { success: false, message: 'Görev veya öğrenci bulunamadı.' };
        }
        if (task.claimed_by && task.claimed_by !== studentId) {
          const claimer = stateRef.current.users.find(
            (u) => u.id === task.claimed_by
          );
          return {
            success: false,
            message: `⚡ Çok geç! Bu yarış görevini az önce ${
              claimer?.name || 'kardeşin'
            } kaptı!`,
          };
        }
        if (task.claimed_by === studentId) {
          return {
            success: true,
            message: 'Bu yarış görevini zaten sen kaptın! Hemen tamamla!',
          };
        }

        if (isSupabaseConfigured && supabase) {
          const { data, error } = await supabase.rpc('claim_race_task_atomic', {
            p_task_id: taskId,
            p_user_id: studentId,
          });
          if (!error && data && typeof data === 'object' && 'success' in data) {
            const rpcRes = data as { success: boolean; message?: string };
            if (!rpcRes.success) {
              return {
                success: false,
                message:
                  rpcRes.message ||
                  '⚡ Çok geç! Kardeşin senden milisaniyeler önce bu görevi kaptı!',
              };
            }
          }
        }

        const claimedAtIso = new Date().toISOString();
        commitAndBroadcast(
          (prev) => ({
            ...prev,
            tasks: prev.tasks.map((t) =>
              t.id === taskId
                ? {
                    ...t,
                    claimed_by: studentId,
                    claimed_at: claimedAtIso,
                  }
                : t
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'flash',
            alert: {
              type: 'flash_quest',
              title: `🏃‍♂️ ${student.name} Yarış Görevini Kaptı!`,
              message: `"${task.title}" görevini ilk ${student.name} üstlendi! 15 dakika içinde bitirirse +${task.points} Puan kazanacak!`,
            },
          }
        );

        return {
          success: true,
          message: `🏃‍♂️ Harika hız! "${task.title}" görevini sen kaptın! Şimdi tamamlayıp puanı topla!`,
        };
      } catch (err) {
        console.error('[claimRaceTaskAtomic] Hata:', err);
        return {
          success: false,
          message: 'Yarış görevi alınırken bir hata oluştu.',
        };
      }
    },
    [commitAndBroadcast]
  );

  // 31. Phase 4: Set Parent Autopilot Mode (1 Hour / 2 Hours / Off)
  const setParentAutopilot = useCallback(
    async (hours: number | null) => {
      try {
        const famId = activeFamilyRef.current;
        const autopilotUntil =
          hours && hours > 0
            ? new Date(
                Date.now() + serverTimeOffset + hours * 3600 * 1000
              ).toISOString()
            : null;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === famId
                  ? { ...fs, autopilot_until: autopilotUntil }
                  : fs
            ),
          }),
          {
            familyId: famId,
            sound: 'victory',
            alert: {
              type: 'info',
              title: autopilotUntil
                ? `✈️ Ebeveyn Otonom Pilot Modu Aktif (${hours} Saat)`
                : '✈️ Otonom Pilot Modu Kapatıldı',
              message: autopilotUntil
                ? 'Siz toplantıda/meşgulken çocukların tamamladığı görevler güven esasıyla anında ön-onay alacak. Daha sonra tek tıkla gözden geçirebilirsiniz.'
                : 'Görev onayları tekrar standart ebeveyn kontrolüne alındı.',
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({ autopilot_until: autopilotUntil })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[setParentAutopilot] Hata:', err);
      }
    },
    [commitAndBroadcast, serverTimeOffset]
  );

  // 32. Phase 4: Finalize All Optimistic Approvals
  const finalizeAllOptimisticApprovals = useCallback(async () => {
    try {
      const famId = activeFamilyRef.current;
      commitAndBroadcast(
        (prev) => ({
          ...prev,
          submissions: prev.submissions.map((s) =>
            (s.family_id || 'fam-ozdemir') === famId && s.is_optimistic_approved
              ? { ...s, is_optimistic_approved: false }
              : s
          ),
        }),
        {
          familyId: famId,
          sound: 'victory',
          alert: {
            type: 'approval',
            title: '✈️ Otomatik Onaylanan Görevler Kesinleştirildi!',
            message:
              'Otonom pilot süresince ön-onay alan tüm görevler ebeveyn tarafından kesin olarak onaylandı.',
          },
        }
      );

      if (isSupabaseConfigured && supabase) {
        await supabase
          .from('task_submissions')
          .update({ is_optimistic_approved: false })
          .eq('family_id', famId)
          .eq('is_optimistic_approved', true);
      }
    } catch (err) {
      console.error('[finalizeAllOptimisticApprovals] Hata:', err);
    }
  }, [commitAndBroadcast]);

  // 33. Phase 4: Revert Optimistic Approval (`revert_optimistic_approval` RPC)
  const revertOptimisticApproval = useCallback(
    async (submissionId: string) => {
      try {
        const sub = stateRef.current.submissions.find(
          (s) => s.id === submissionId
        );
        if (!sub) {
          return { success: false, message: 'Görev gönderimi bulunamadı.' };
        }
        const task = stateRef.current.tasks.find((t) => t.id === sub.task_id);
        const student = stateRef.current.users.find(
          (u) => u.id === sub.user_id
        );
        const pointsToRevert = task?.points || 20;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            submissions: prev.submissions.map((s) =>
              s.id === submissionId
                ? {
                    ...s,
                    status: 'rejected',
                    is_optimistic_approved: false,
                  }
                : s
            ),
            users: prev.users.map((u) =>
              u.id === sub.user_id
                ? {
                    ...u,
                    points_balance: Math.max(
                      0,
                      u.points_balance - pointsToRevert
                    ),
                  }
                : u
            ),
          }),
          {
            familyId: sub.family_id,
            sound: 'violation',
            alert: {
              type: 'violation',
              title: `↩️ Ön-Onay İptal Edildi: ${student?.name || 'Öğrenci'}`,
              message: `"${
                task?.title || 'Görev'
              }" görevinin otomatik ön-onayı ebeveyn kontrolünde iptal edildi ve ${pointsToRevert} puan geri alındı.`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.rpc('revert_optimistic_approval', {
            p_submission_id: submissionId,
          });
        }

        return {
          success: true,
          message: `Ön-onay iptal edildi ve ${pointsToRevert} puan geri alındı.`,
        };
      } catch (err) {
        console.error('[revertOptimisticApproval] Hata:', err);
        return {
          success: false,
          message: 'Ön-onay geri alınırken hata oluştu.',
        };
      }
    },
    [commitAndBroadcast]
  );

  // 34. Phase 4: Start Happy Hour Market Discount (%20 - %50)
  const startHappyHourDiscount = useCallback(
    async (discountPercent: number, durationMinutes: number = 120) => {
      try {
        const famId = activeFamilyRef.current;
        const pct = Math.max(0, Math.min(75, Math.round(discountPercent)));
        const endsAt =
          pct > 0
            ? new Date(
                Date.now() + serverTimeOffset + durationMinutes * 60 * 1000
              ).toISOString()
            : null;

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
              (fs) =>
                fs.family_id === famId
                  ? {
                      ...fs,
                      happy_hour_discount_percent: pct,
                      happy_hour_ends_at: endsAt,
                    }
                  : fs
            ),
          }),
          {
            familyId: famId,
            sound: 'flash',
            alert: {
              type: 'flash_quest',
              title:
                pct > 0
                  ? `🏷️ HAPPY HOUR BAŞLADI! Ödül Marketinde %${pct} İndirim!`
                  : '🏷️ Happy Hour İndirimi Sona Erdi',
              message:
                pct > 0
                  ? `Önümüzdeki ${durationMinutes} dakika boyunca tüm ödüllerde %${pct} dev indirim fırsatını kaçırmayın!`
                  : 'Ödül marketi fiyatları standart seviyesine döndü.',
            },
          }
        );

        const ttsEnabled =
          stateRef.current.familySettings?.find((fs) => fs.family_id === famId)
            ?.tts_announcements_enabled ?? true;
        if (pct > 0) {
          speakTurkishAnnouncement(
            `Ev halkı dikkat! Ödül marketinde yüzde ${pct} Happy Hour indirimi başladı!`,
            ttsEnabled
          );
        }

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({
              happy_hour_discount_percent: pct,
              happy_hour_ends_at: endsAt,
            })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[startHappyHourDiscount] Hata:', err);
      }
    },
    [commitAndBroadcast, serverTimeOffset]
  );

  // 35. Phase 4: Toggle Turkish TTS Voice Announcements (`tts_announcements_enabled`)
  const toggleTTSAnnouncements = useCallback(
    async (enabled: boolean) => {
      try {
        const famId = activeFamilyRef.current;
        commitAndBroadcast((prev) => ({
          ...prev,
          familySettings: (prev.familySettings || INITIAL_FAMILY_SETTINGS).map(
            (fs) =>
              fs.family_id === famId
                ? { ...fs, tts_announcements_enabled: enabled }
                : fs
          ),
        }));

        if (enabled) {
          speakTurkishAnnouncement(
            'Sesli ev asistanı aktif edildi.',
            true
          );
        }

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('family_settings')
            .update({ tts_announcements_enabled: enabled })
            .eq('family_id', famId);
        }
      } catch (err) {
        console.error('[toggleTTSAnnouncements] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 36. Phase 4: Complete Active Break Roulette Challenge (+5 Bonus Points & +10 Companion Energy)
  const completeActiveBreakChallenge = useCallback(
    async (studentId: string, challengeTitle: string) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) return;

        const baseComp: CompanionConfig = student.companion_config || {
          type: 'dragon',
          name: 'Ateş Kanat',
          xp: 120,
          level: 2,
          evolution_stage: 2,
          hunger: 90,
          energy: 85,
        };
        const updatedComp: CompanionConfig = {
          ...baseComp,
          energy: Math.min(100, (baseComp.energy || 80) + 10),
          xp: baseComp.xp + 10,
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            users: prev.users.map((u) =>
              u.id === studentId
                ? {
                    ...u,
                    points_balance: u.points_balance + 5,
                    companion_config: updatedComp,
                  }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `🏃‍♂️ Aktif Mola Hareketi Tamamlandı: ${student.name} (+5 Puan)`,
              message: `${student.name}, "${challengeTitle}" egzersizini yaptı! +5 Enerji Puanı ve +10 Yoldaş Enerjisi kazandı!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase
            .from('users')
            .update({
              points_balance: student.points_balance + 5,
              companion_config: updatedComp,
            })
            .eq('id', studentId);
        }
      } catch (err) {
        console.error('[completeActiveBreakChallenge] Hata:', err);
      }
    },
    [commitAndBroadcast]
  );

  // 37. Phase 4: Save Weekly Sunday Interview & Audio Time Capsule (`weekly_interviews`)
  const saveWeeklyInterview = useCallback(
    async ({
      studentId,
      questionText,
      audioUrl = null,
      answerNote = null,
    }: {
      studentId: string;
      questionText: string;
      audioUrl?: string | null;
      answerNote?: string | null;
    }) => {
      try {
        const student = stateRef.current.users.find((u) => u.id === studentId);
        if (!student) {
          return { success: false, message: 'Öğrenci bulunamadı.' };
        }
        if (!audioUrl && !answerNote?.trim()) {
          return {
            success: false,
            message: 'Lütfen ses kaydı al veya cevabını kısaca not et.',
          };
        }

        const now = new Date();
        const day = now.getDay();
        const diffToMonday = day === 0 ? -6 : 1 - day;
        const monday = new Date(now);
        monday.setDate(now.getDate() + diffToMonday);
        const weekStartDate = monday.toISOString().split('T')[0];

        const newInterview: WeeklyInterviewRecord = {
          id: `wi-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          family_id: student.family_id,
          user_id: studentId,
          week_start_date: weekStartDate,
          question_text: questionText,
          audio_url: audioUrl,
          answer_note:
            answerNote?.trim() || '🎙️ Sesli zaman kapsülü kaydı eklendi.',
          created_at: new Date().toISOString(),
        };

        commitAndBroadcast(
          (prev) => ({
            ...prev,
            weeklyInterviews: [
              newInterview,
              ...(prev.weeklyInterviews || INITIAL_WEEKLY_INTERVIEWS),
            ],
            users: prev.users.map((u) =>
              u.id === studentId
                ? { ...u, points_balance: u.points_balance + 15 }
                : u
            ),
          }),
          {
            familyId: student.family_id,
            sound: 'victory',
            alert: {
              type: 'approval',
              title: `🎙️ Yeni Sesli Anı Kapsülü Kaydedildi: ${student.name} (+15 Puan)`,
              message: `"${questionText}" sorusunun yanıtı Başarı & Anı Albümüne eklendi!`,
            },
          }
        );

        if (isSupabaseConfigured && supabase) {
          await supabase.from('weekly_interviews').insert(newInterview);
          await supabase
            .from('users')
            .update({ points_balance: student.points_balance + 15 })
            .eq('id', studentId);
        }

        return {
          success: true,
          message:
            '🎙️ Sesli Anı Kapsülün kaydedildi ve +15 Hatıra Puanı kazandın! Başarı Albümünden her zaman dinleyebilirsin.',
        };
      } catch (err) {
        console.error('[saveWeeklyInterview] Hata:', err);
        return {
          success: false,
          message: 'Röportaj kaydedilirken bir hata oluştu.',
        };
      }
    },
    [commitAndBroadcast]
  );

  return (
    <FamilyRealtimeContext.Provider
      value={{
        isAuthenticated,
        sessionLoading,
        wizardOpen,
        wizardOwnerEmail,
        setWizardOpen,
        createFamilyWizard,
        regenerateDesktopPairingCode,
        logout,
        loginSuccessWithUser,
        families: state.families,
        activeFamily,
        familySettings,
        qrStations: familyQrStations,
        pointTransfers: familyPointTransfers,
        schoolSchedules: familySchoolSchedules,
        appeals: familyAppeals,
        weeklyInterviews: familyWeeklyInterviews,
        activeHappyHourDiscountPercent,
        lastRestoredShieldStudentId,
        clearRestoredShieldCelebration,
        serverTimeOffset,
        switchFamilyById,
        switchFamilyByCode,
        createNewFamily,
        users: familyUsers,
        devices: familyDevices,
        tasks: familyTasks,
        submissions: familySubmissions,
        rewards: familyRewards,
        redemptions: familyRedemptions,
        messages: familyMessages,
        violations: familyViolations,
        alarms: familyAlarms,
        activeUser,
        activeDeviceType,
        setActiveUserById,
        setActiveDeviceType,
        remainingSecondsByUser,
        liveAlerts: familyAlerts,
        dismissAlert,
        isLiveSupabase: isSupabaseConfigured,
        addChildToFamily,
        addParentToFamily,
        updateFamilyMember,
        deleteFamilyMember,
        regenerateMemberCredentials,
        addTaskToFamily,
        addRewardToFamily,
        proposeTaskByStudent,
        reviewTaskProposal,
        transferPointsBetweenSiblings,
        addQRStation,
        updateStudentWhitelist,
        updateFamilyChestConfig,
        updateOfflineMasterPin,
        unlockWithOfflineMasterPin,
        useGracePeriodExtension,
        voluntaryEarlyLockRefund,
        awardHealthPoints,
        updateCompanionConfig,
        upsertSchoolSchedule,
        updateFamilyWeatherAndNoiseConfig,
        submitAppeal,
        resolveAppeal,
        claimRaceTaskAtomic,
        setParentAutopilot,
        finalizeAllOptimisticApprovals,
        revertOptimisticApproval,
        startHappyHourDiscount,
        toggleTTSAnnouncements,
        completeActiveBreakChallenge,
        saveWeeklyInterview,
        setStudentState,
        addBonusTimeMinutes,
        updateStudentMood,
        submitTaskCompletion,
        approveOrRejectSubmission,
        approveTaskOnSpotWithPin,
        createFlashQuest,
        requestRewardRedemption,
        approveOrRejectRedemption,
        depositToPiggyBank,
        triggerSundayPiggyBonus,
        triggerDailyZeroViolationBonus,
        spinLuckyWheel,
        recordViolation,
        triggerWakeUpAlarm,
        completeWakeUpChallenge,
        sendDirectMessage,
        updateDeviceWindowTitle,
      }}
    >
      {children}
    </FamilyRealtimeContext.Provider>
  );
};

export const useFamilyRealtime = () => {
  const ctx = useContext(FamilyRealtimeContext);
  if (!ctx) {
    throw new Error('useFamilyRealtime must be used inside FamilyRealtimeProvider');
  }
  return ctx;
};
