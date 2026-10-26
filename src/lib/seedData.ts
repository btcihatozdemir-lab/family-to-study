import {
  FamilyAccount,
  FamilySettings,
  QRStation,
  PointTransfer,
  SchoolScheduleItem,
  AppealRecord,
  WeeklyInterviewRecord,
  UserProfile,
  DeviceRecord,
  TaskItem,
  RewardItem,
  TaskSubmission,
  RewardRedemption,
  DirectMessage,
  ViolationLog,
  AlarmSchedule,
} from '@/types/database';

/**
 * FAZ 6: GERÇEK MULTI-TENANT AİLE İZOLASYONU
 * Eski sahte (mock/seed) aile ve öğrenci verileri tamamen temizlenmiştir.
 * Sistem yalnızca giriş yapmış kullanıcının gerçek aile verilerini yükler.
 */

export const INITIAL_FAMILY_SETTINGS: FamilySettings[] = [];
export const INITIAL_QR_STATIONS: QRStation[] = [];
export const INITIAL_POINT_TRANSFERS: PointTransfer[] = [];
export const INITIAL_FAMILIES: FamilyAccount[] = [];
export const INITIAL_USERS: UserProfile[] = [];
export const INITIAL_DEVICES: DeviceRecord[] = [];
export const INITIAL_TASKS: TaskItem[] = [];
export const INITIAL_REWARDS: RewardItem[] = [];
export const INITIAL_SUBMISSIONS: TaskSubmission[] = [];
export const INITIAL_SCHOOL_SCHEDULES: SchoolScheduleItem[] = [];
export const INITIAL_REDEMPTIONS: RewardRedemption[] = [];
export const INITIAL_MESSAGES: DirectMessage[] = [];
export const INITIAL_VIOLATIONS: ViolationLog[] = [];
export const INITIAL_APPEALS: AppealRecord[] = [];
export const INITIAL_WEEKLY_INTERVIEWS: WeeklyInterviewRecord[] = [];
export const INITIAL_ALARMS: AlarmSchedule[] = [];
