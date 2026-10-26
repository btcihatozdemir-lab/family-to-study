'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Shield,
  ShieldAlert,
  Lock,
  Unlock,
  Sun,
  Coffee,
  Moon,
  PlusCircle,
  CheckCircle2,
  XCircle,
  Monitor,
  Smartphone,
  Tablet,
  Zap,
  Gift,
  Camera,
  Vault,
  Copy,
  QrCode,
  Share2,
  KeyRound,
  CalendarDays,
  Eye,
  EyeOff,
  Award,
  Clock,
  Activity,
  UserPlus,
  ListPlus,
  Sparkles,
  Scale,
  Plane,
  Tag,
  Volume2,
  RotateCcw,
} from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { WalkieTalkieDM } from '@/components/shared/WalkieTalkieDM';
import { PrintableQRStationCard } from '@/components/shared/QRCodeScannerAndPrint';
import { SuccessAlbumModal } from '@/components/shared/SuccessAlbumModal';
import { WeeklyScheduleEditorModal } from '@/components/schedule/WeeklyScheduleEditorModal';
import { buildMagicLoginUrl } from '@/lib/urlHelper';
import {
  QRStationLinkedAction,
  RewardTier,
  TaskCategory,
  TaskVerificationType,
  UserProfile,
} from '@/types/database';

const MOOD_BADGES = {
  happy: { emoji: '😊', label: 'Mutlu', color: 'bg-emerald-500/20 text-emerald-300' },
  excited: { emoji: '🤩', label: 'Enerjik', color: 'bg-amber-500/20 text-amber-300' },
  tired: { emoji: '🥱', label: 'Yorgun', color: 'bg-blue-500/20 text-blue-300' },
  angry: { emoji: '😤', label: 'Stresli', color: 'bg-rose-500/20 text-rose-300' },
};

const CHILD_EMOJIS = ['🦁', '🦄', '🦊', '🦖', '🦋', '🐼', '🚀', '⚡'];

export const ParentCommandCenter: React.FC = () => {
  const {
    activeFamily,
    familySettings,
    qrStations,
    schoolSchedules,
    appeals,
    activeHappyHourDiscountPercent,
    activeUser,
    users,
    devices,
    tasks,
    submissions,
    rewards,
    redemptions,
    violations,
    remainingSecondsByUser,
    addChildToFamily,
    addTaskToFamily,
    addRewardToFamily,
    reviewTaskProposal,
    addQRStation,
    updateStudentWhitelist,
    updateFamilyChestConfig,
    updateOfflineMasterPin,
    upsertSchoolSchedule,
    updateFamilyWeatherAndNoiseConfig,
    resolveAppeal,
    setParentAutopilot,
    finalizeAllOptimisticApprovals,
    revertOptimisticApproval,
    startHappyHourDiscount,
    toggleTTSAnnouncements,
    setStudentState,
    addBonusTimeMinutes,
    approveOrRejectSubmission,
    approveOrRejectRedemption,
    createFlashQuest,
    triggerWakeUpAlarm,
    triggerSundayPiggyBonus,
    triggerDailyZeroViolationBonus,
    recordViolation,
    sendDirectMessage,
    regenerateDesktopPairingCode,
  } = useFamilyRealtime();

  const childrenUsers = users.filter((u) => u.role === 'child');
  const pendingSubmissions = submissions.filter((s) => s.status === 'pending');
  const optimisticSubmissions = submissions.filter(
    (s) => s.status === 'approved' && s.is_optimistic_approved
  );
  const pendingAppeals = appeals.filter((a) => a.status === 'pending');
  const pendingRedemptions = redemptions.filter((r) => r.status === 'pending');
  const pendingStudentProposals = tasks.filter(
    (t) => t.proposal_status === 'pending_parent_approval'
  );
  const isAutopilotActive = Boolean(
    familySettings?.autopilot_until &&
      new Date(familySettings.autopilot_until).getTime() > Date.now()
  );

  // Flash Quest Form State
  const [flashTarget, setFlashTarget] = useState<string>('both');
  const [flashTitle, setFlashTitle] = useState<string>(
    '15 Dakika İçinde Odasını & Masasını Toplayana 2 Kat Altın Puan!'
  );
  const [flashPoints, setFlashPoints] = useState<number>(60);
  const [flashDuration, setFlashDuration] = useState<number>(15);
  const [flashRequiresPhoto, setFlashRequiresPhoto] = useState<boolean>(true);
  const [flashIsRace, setFlashIsRace] = useState<boolean>(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [zoomedPhoto, setZoomedPhoto] = useState<string | null>(null);

  // Dynamic Family Management Drawer State
  const [mgmtTab, setMgmtTab] = useState<
    | 'none'
    | 'child'
    | 'task'
    | 'reward'
    | 'qr'
    | 'security_chest'
    | 'schedule_weather'
  >('none');
  const [showSuccessAlbum, setShowSuccessAlbum] = useState(false);
  const [selectedStudentForSchedule, setSelectedStudentForSchedule] = useState<UserProfile | null>(null);
  const [selectedStudentForQR, setSelectedStudentForQR] = useState<UserProfile | null>(null);
  const [revealedPasswordId, setRevealedPasswordId] = useState<string | null>(null);

  // Phase 3: Task Approval Album Feature & Praise Note State (keyed by submission ID)
  const [albumFeatureBySub, setAlbumFeatureBySub] = useState<
    Record<string, boolean>
  >({});
  const [praiseNoteBySub, setPraiseNoteBySub] = useState<
    Record<string, string>
  >({});

  // Phase 3: Weekly School Schedule Editor & Weather / Noise Settings State
  const [schedChildId, setSchedChildId] = useState<string>(
    childrenUsers[0]?.id || 'child-omer'
  );
  const [schedDay, setSchedDay] = useState<number>(
    ((new Date().getDay() || 7) % 7) + 1
  );
  const [schedHasPe, setSchedHasPe] = useState<boolean>(true);
  const [schedHasArt, setSchedHasArt] = useState<boolean>(false);
  const [schedCustomItems, setSchedCustomItems] = useState<string>(
    'Eşofman takımı, Spor ayakkabısı, Suluk'
  );
  const [schedNote, setSchedNote] = useState<string>(
    'Yarın Beden Eğitimi dersi var! Eşofman ve suluğunu çantana koymayı unutma.'
  );
  const [cityLatInput, setCityLatInput] = useState<number>(
    familySettings?.city_lat ?? 41.08
  );
  const [cityLonInput, setCityLonInput] = useState<number>(
    familySettings?.city_lon ?? 31.12
  );
  const [noiseDbInput, setNoiseDbInput] = useState<number>(
    familySettings?.noise_threshold_db ?? 75
  );

  // Add Child State
  const [childName, setChildName] = useState('');
  const [childGrade, setChildGrade] = useState('4. Sınıf (10 Yaş)');
  const [childAgeGroup, setChildAgeGroup] = useState<'kid' | 'preteen' | 'teen'>('kid');
  const [childEmoji, setChildEmoji] = useState('🦊');

  // Add Task State
  const [newTaskTarget, setNewTaskTarget] = useState('both');
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskDesc, setNewTaskDesc] = useState('');
  const [newTaskCat, setNewTaskCat] = useState<TaskCategory>('academic');
  const [newTaskPoints, setNewTaskPoints] = useState(40);
  const [newTaskVerifType, setNewTaskVerifType] =
    useState<TaskVerificationType>('photo_optional');
  const [newTaskQrStationId, setNewTaskQrStationId] = useState<string>(
    qrStations[0]?.id || ''
  );
  const [newTaskDue, setNewTaskDue] = useState('18:30');
  const [newTaskIsRace, setNewTaskIsRace] = useState<boolean>(false);

  // Add Reward State
  const [newRewTitle, setNewRewTitle] = useState('');
  const [newRewCost, setNewRewCost] = useState(60);
  const [newRewTier, setNewRewTier] = useState<RewardTier>('micro');
  const [newRewUnlockMin, setNewRewUnlockMin] = useState<number>(30);

  // Phase 2: QR Station Generator State
  const [newQrCode, setNewQrCode] = useState('STATION_DESK_03');
  const [newQrTitle, setNewQrTitle] = useState('Çalışma Masası QR İstasyonu');
  const [newQrAction, setNewQrAction] =
    useState<QRStationLinkedAction>('complete_task');

  // Phase 2: Family Chest & 6-Digit Offline Master PIN State
  const [chestGoalInput, setChestGoalInput] = useState<number>(
    familySettings?.family_chest_goal || 1500
  );
  const [chestRewardTitleInput, setChestRewardTitleInput] = useState<string>(
    familySettings?.family_chest_reward_title ||
      '🍕 Cumartesi Akşamı Ailece Sinema & Pizza Gecesi!'
  );
  const [offlinePinInput, setOfflinePinInput] = useState<string>('145300');

  // Phase 2: Per-Student Whitelist Editor Drawer State
  const [openWhitelistChildId, setOpenWhitelistChildId] = useState<string | null>(
    null
  );
  const [whitelistExesInput, setWhitelistExesInput] = useState<string>(
    'chrome.exe, winword.exe, acrord32.exe, code.exe'
  );
  const [whitelistKeywordsInput, setWhitelistKeywordsInput] = useState<string>(
    'eba, ders, ödev, morpa, tonguç, matematik, fen, ingilizce'
  );

  const showStatus = (msg: string) => {
    setStatusMessage(msg);
    setTimeout(() => setStatusMessage(null), 4000);
  };

  const handleSendFlashQuest = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!flashTitle.trim()) return;
    await createFlashQuest(
      flashTarget,
      flashTitle.trim(),
      flashPoints,
      flashDuration,
      flashRequiresPhoto ? 'photo_optional' : 'physical_check',
      flashIsRace
    );
    showStatus(
      flashIsRace
        ? '🏃‍♂️ İlk Kapar Kardeş Yarışı görevi tüm öğrenci ekranlarına sesli anonsla fırlatıldı!'
        : '⚡ Sürpriz Altın Görev tüm öğrenci cihazlarına sesli bildirimle gönderildi!'
    );
  };

  const handleAddChildSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!childName.trim()) return;
    await addChildToFamily({
      name: childName,
      grade: childGrade,
      ageGroup: childAgeGroup,
      emoji: childEmoji,
    });
    setChildName('');
    setMgmtTab('none');
    showStatus(`🎉 ${childName} başarıyla ${activeFamily.name} hesabına eklendi!`);
  };

  const handleAddTaskSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTaskTitle.trim()) return;
    await addTaskToFamily({
      assignedTo: newTaskTarget,
      title: newTaskTitle,
      description: newTaskDesc,
      category: newTaskCat,
      points: newTaskPoints,
      verificationType: newTaskVerifType,
      dueTime: newTaskDue,
      requiredQrStationId:
        newTaskVerifType === 'qr_scan' ? newTaskQrStationId || null : null,
      isFirstComeRace: newTaskIsRace,
    });
    setNewTaskTitle('');
    setNewTaskDesc('');
    setNewTaskIsRace(false);
    setMgmtTab('none');
    showStatus('📋 Yeni görev başarıyla aile görev listesine eklendi!');
  };

  const handleAddRewardSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRewTitle.trim()) return;
    await addRewardToFamily({
      title: newRewTitle,
      costPoints: newRewCost,
      tier: newRewTier,
      unlockMinutes: newRewTier === 'micro' ? newRewUnlockMin : null,
    });
    setNewRewTitle('');
    setMgmtTab('none');
    showStatus('🎁 Yeni ödül başarıyla aile marketine eklendi!');
  };

  const handleAddQRStationSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newQrCode.trim() || !newQrTitle.trim()) return;
    await addQRStation({
      stationCode: newQrCode.trim().toUpperCase(),
      title: newQrTitle.trim(),
      linkedAction: newQrAction,
    });
    showStatus(`📷 ${newQrTitle} istasyonu oluşturuldu! Tek tıkla yazdırabilirsiniz.`);
  };

  const handleSaveChestConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    await updateFamilyChestConfig({
      goal: chestGoalInput,
      rewardTitle: chestRewardTitleInput,
    });
    showStatus('🧰 Ortak Aile Hazine Sandığı hedefi ve ödülü güncellendi!');
  };

  const handleSaveOfflinePin = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleaned = offlinePinInput.replace(/\D/g, '').slice(0, 6);
    if (cleaned.length !== 6) {
      showStatus('⚠️ Lütfen tam 6 haneli bir Çevrimdışı Kurtarma PIN kodu girin.');
      return;
    }
    await updateOfflineMasterPin(cleaned);
    showStatus(
      `🔐 6 Haneli Çevrimdışı Kurtarma PIN kodu (${cleaned}) SHA-256 ile şifrelenip kaydedildi!`
    );
  };

  const handleOpenWhitelistForChild = (child: (typeof childrenUsers)[number]) => {
    if (openWhitelistChildId === child.id) {
      setOpenWhitelistChildId(null);
      return;
    }
    setOpenWhitelistChildId(child.id);
    setWhitelistExesInput(
      (child.whitelist_config?.allowed_exes || ['chrome.exe', 'winword.exe']).join(
        ', '
      )
    );
    setWhitelistKeywordsInput(
      (
        child.whitelist_config?.allowed_keywords || ['eba', 'ders', 'ödev']
      ).join(', ')
    );
  };

  const handleSaveWhitelistForChild = async (studentId: string) => {
    const allowed_exes = whitelistExesInput
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const allowed_keywords = whitelistKeywordsInput
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    await updateStudentWhitelist(studentId, { allowed_exes, allowed_keywords });
    setOpenWhitelistChildId(null);
    showStatus('💻 Bilgisayarlı Ders (Whitelist) kuralları kaydedildi!');
  };

  const handleSubmissionDecision = async (
    subId: string,
    decision: 'approved' | 'rejected'
  ) => {
    const featureInAlbum = Boolean(albumFeatureBySub[subId]);
    const praiseNote = (praiseNoteBySub[subId] || '').trim() || null;
    const res = await approveOrRejectSubmission(subId, activeUser.id, decision, {
      featureInAlbum,
      praiseNote,
    });
    showStatus(res.message);
  };

  const handleSaveScheduleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const targetUserId = schedChildId || childrenUsers[0]?.id;
    if (!targetUserId) return;
    const customItems = schedCustomItems
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    await upsertSchoolSchedule({
      user_id: targetUserId,
      day_of_week: schedDay,
      has_pe_class: schedHasPe,
      has_art_class: schedHasArt,
      custom_items_to_pack: customItems,
      reminder_note: schedNote,
    });
    showStatus('🎒 Haftalık okul ders programı ve akıllı çanta listesi kaydedildi!');
  };

  const handleSaveWeatherAndNoiseSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await updateFamilyWeatherAndNoiseConfig({
      cityLat: cityLatInput,
      cityLon: cityLonInput,
      noiseThresholdDb: noiseDbInput,
    });
    showStatus(
      `🌤️ Hava durumu koordinatları (${cityLatInput}, ${cityLonInput}) ve 🔊 Gürültü eşiği (${noiseDbInput} dB) güncellendi!`
    );
  };

  const handleRedemptionDecision = async (
    redId: string,
    decision: 'approved' | 'rejected'
  ) => {
    const res = await approveOrRejectRedemption(redId, activeUser.id, decision);
    showStatus(res.message);
  };

  return (
    <div className="space-y-6">
      {/* Phase 3: Aile Başarı Albümü & Film Gecesi Slayt Gösterisi Modalı */}
      <SuccessAlbumModal
        isOpen={showSuccessAlbum}
        onClose={() => setShowSuccessAlbum(false)}
      />

      {/* Status Feedback Banner */}
      {statusMessage && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-indigo-600 border border-indigo-400 text-white font-bold px-5 py-3 rounded-2xl shadow-xl text-sm flex items-center justify-between"
        >
          <span>{statusMessage}</span>
          <button
            type="button"
            onClick={() => setStatusMessage(null)}
            className="text-xs underline ml-4"
          >
            Tamam
          </button>
        </motion.div>
      )}

      {/* Top Parent Header & Global Economy Automation Triggers */}
      <div className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 border border-indigo-500/30 rounded-3xl p-5 sm:p-6 shadow-2xl space-y-4">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-rose-500 to-indigo-600 flex items-center justify-center text-3xl shadow-lg relative shrink-0">
              {activeUser.avatar_config.emoji}
              <div className="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-slate-900 border-2 border-indigo-400 overflow-hidden shadow-lg flex items-center justify-center">
                <img
                  src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/family-logo.png`}
                  alt="Family Logo"
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    (e.currentTarget as HTMLElement).style.display = 'none';
                  }}
                />
              </div>
            </div>
            <div>
              <div className="inline-flex flex-wrap items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-extrabold mb-1">
                <Activity className="w-3.5 h-3.5" />
                <span>
                  {activeFamily.name.toUpperCase()} ({activeFamily.family_code}) — EBEVEYN KONTROL MERKEZİ
                </span>
              </div>
              <h1 className="text-xl sm:text-2xl font-black text-white">
                Hoş Geldiniz, {activeUser.name}
              </h1>
              <p className="text-xs text-slate-400">
                Çoklu Aile (Multi-Tenant) izolasyonu, çift onay önleyici atomik motor ve cihaz kilidi aktif.
              </p>
            </div>
          </div>

          {/* Economy Bonus Actions */}
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => setShowSuccessAlbum(true)}
              className="px-3.5 py-2.5 rounded-xl bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-slate-950 font-black text-xs flex items-center gap-1.5 shadow-lg transition"
            >
              <span>🏆 Aile Başarı Albümü & 🎬 Film Gecesi</span>
            </button>
            <button
              type="button"
              onClick={triggerDailyZeroViolationBonus}
              className="px-3.5 py-2.5 rounded-xl bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-400/40 text-emerald-300 font-bold text-xs flex items-center gap-1.5 transition"
            >
              <Award className="w-4 h-4" />
              <span>Gün Sonu +20 Kalkan Bonusu</span>
            </button>
            <button
              type="button"
              onClick={triggerSundayPiggyBonus}
              className="px-3.5 py-2.5 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 border border-amber-400/40 text-amber-300 font-bold text-xs flex items-center gap-1.5 transition"
            >
              <Vault className="w-4 h-4" />
              <span>Pazar +%20 Altın Kasa Bonusu</span>
            </button>
          </div>
        </div>

        {/* Phase 4 Control Bar: Autopilot (Meşgulüm Modu), Happy Hour Market Discount & Turkish TTS Voice Assistant */}
        <div className="pt-3 border-t border-slate-800/80 grid grid-cols-1 xl:grid-cols-3 gap-3">
          {/* 1. Otonom Pilot Modu (1 Saat / 2 Saat) */}
          <div className="rounded-2xl border border-cyan-500/30 bg-slate-950/75 p-3 flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Plane className="w-4 h-4 text-cyan-400 shrink-0" />
              <div>
                <div className="text-[11px] font-black text-cyan-300 uppercase">
                  ✈️ Meşgulüm / Otomatik Pilot Modu
                </div>
                <div className="text-[10px] text-slate-400">
                  {isAutopilotActive
                    ? `Aktif • Bitiş: ${new Date(
                        familySettings.autopilot_until!
                      ).toLocaleTimeString('tr-TR', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}`
                    : 'Görevlere güven esasıyla anında ön-onay verir'}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={async () => {
                  await setParentAutopilot(1);
                  showStatus('✈️ Otonom Pilot Modu 1 saatliğine aktif edildi!');
                }}
                className={`px-2.5 py-1 rounded-lg text-[11px] font-black transition ${
                  isAutopilotActive
                    ? 'bg-cyan-500/25 text-cyan-200 border border-cyan-400/40'
                    : 'bg-cyan-500 text-slate-950 hover:bg-cyan-400'
                }`}
              >
                1 Saat
              </button>
              <button
                type="button"
                onClick={async () => {
                  await setParentAutopilot(2);
                  showStatus('✈️ Otonom Pilot Modu 2 saatliğine aktif edildi!');
                }}
                className="px-2.5 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-[11px] font-black transition"
              >
                2 Saat
              </button>
              {isAutopilotActive && (
                <button
                  type="button"
                  onClick={async () => {
                    await setParentAutopilot(null);
                    showStatus('✈️ Otonom Pilot Modu kapatıldı.');
                  }}
                  className="px-2 py-1 rounded-lg bg-rose-600/30 text-rose-200 text-[11px] font-bold hover:bg-rose-600/50"
                >
                  Kapat
                </button>
              )}
            </div>
          </div>

          {/* 2. Dinamik Ekonomi: Happy Hour İndirim Saati Başlat (%20 - %50) */}
          <div className="rounded-2xl border border-amber-500/30 bg-slate-950/75 p-3 flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Tag className="w-4 h-4 text-amber-400 shrink-0" />
              <div>
                <div className="text-[11px] font-black text-amber-300 uppercase">
                  🏷️ İndirim Saati Başlat (Happy Hour)
                </div>
                <div className="text-[10px] text-slate-400">
                  {activeHappyHourDiscountPercent > 0
                    ? `Aktif: Ödül Marketinde %${activeHappyHourDiscountPercent} İndirim!`
                    : 'Cuma 18:00-20:00 otomatik veya manuel başlatın'}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              {[20, 30, 50].map((pct) => (
                <button
                  key={pct}
                  type="button"
                  onClick={async () => {
                    await startHappyHourDiscount(pct, 120);
                    showStatus(
                      `🏷️ Ödül Marketinde 2 saatlik %${pct} Happy Hour İndirimi başlatıldı!`
                    );
                  }}
                  className={`px-2.5 py-1 rounded-lg text-[11px] font-black transition ${
                    activeHappyHourDiscountPercent === pct
                      ? 'bg-amber-400 text-slate-950'
                      : 'bg-amber-500/20 hover:bg-amber-500/35 text-amber-300 border border-amber-400/30'
                  }`}
                >
                  %{pct}
                </button>
              ))}
              {activeHappyHourDiscountPercent > 0 && (
                <button
                  type="button"
                  onClick={async () => {
                    await startHappyHourDiscount(0, 0);
                    showStatus('🏷️ Happy Hour indirimi sonlandırıldı.');
                  }}
                  className="px-2 py-1 rounded-lg bg-rose-600/30 text-rose-200 text-[11px] font-bold"
                >
                  Bitir
                </button>
              )}
            </div>
          </div>

          {/* 3. İsimli Türkçe Sesli Ev Asistanı (TTS Announcements) */}
          <div className="rounded-2xl border border-emerald-500/30 bg-slate-950/75 p-3 flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <Volume2 className="w-4 h-4 text-emerald-400 shrink-0" />
              <div>
                <div className="text-[11px] font-black text-emerald-300 uppercase">
                  🔊 Türkçe Sesli Ev Asistanı (TTS)
                </div>
                <div className="text-[10px] text-slate-400">
                  Çocuklara isimleriyle sesli görev ve ödül anonsu yapar
                </div>
              </div>
            </div>
            <button
              type="button"
              onClick={async () => {
                const nextVal = !(
                  familySettings?.tts_announcements_enabled ?? true
                );
                await toggleTTSAnnouncements(nextVal);
                showStatus(
                  nextVal
                    ? '🔊 Türkçe Sesli Ev Asistanı anonsları açıldı!'
                    : '🔇 Sesli Ev Asistanı sessize alındı.'
                );
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-black transition ${
                familySettings?.tts_announcements_enabled ?? true
                  ? 'bg-emerald-500 text-slate-950'
                  : 'bg-slate-800 text-slate-400 border border-slate-700'
              }`}
            >
              {familySettings?.tts_announcements_enabled ?? true
                ? '🔊 Sesli Anons: AÇIK'
                : '🔇 Sesli Anons: KAPALI'}
            </button>
          </div>
        </div>

        {/* Dynamic Multi-Tenant Family Quick Creation Bar (Add Child / Task / Reward) */}
        <div className="pt-3 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2">
          <span className="text-xs text-slate-300 font-semibold flex items-center gap-1.5">
            <Sparkles className="w-4 h-4 text-amber-400" />
            <span>Aile Özelleştirme & Dinamik Kayıt Ekleme:</span>
          </span>

          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => setMgmtTab(mgmtTab === 'child' ? 'none' : 'child')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'child'
                  ? 'bg-indigo-600 text-white border-indigo-400'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-slate-200 border-slate-700'
              }`}
            >
              <UserPlus className="w-3.5 h-3.5" />
              <span>+ Yeni Çocuk / Öğrenci Ekle</span>
            </button>

            <button
              type="button"
              onClick={() => setMgmtTab(mgmtTab === 'task' ? 'none' : 'task')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'task'
                  ? 'bg-indigo-600 text-white border-indigo-400'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-slate-200 border-slate-700'
              }`}
            >
              <ListPlus className="w-3.5 h-3.5" />
              <span>+ Yeni Görev / Rutin Ekle</span>
            </button>

            <button
              type="button"
              onClick={() => setMgmtTab(mgmtTab === 'reward' ? 'none' : 'reward')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'reward'
                  ? 'bg-indigo-600 text-white border-indigo-400'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-slate-200 border-slate-700'
              }`}
            >
              <Gift className="w-3.5 h-3.5" />
              <span>+ Yeni Market Ödülü Ekle</span>
            </button>

            <button
              type="button"
              onClick={() => setMgmtTab(mgmtTab === 'qr' ? 'none' : 'qr')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'qr'
                  ? 'bg-emerald-600 text-white border-emerald-400'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-emerald-300 border-emerald-500/40'
              }`}
            >
              <span>📷 QR İstasyonları Yönetimi & Yazdır</span>
            </button>

            <button
              type="button"
              onClick={() =>
                setMgmtTab(mgmtTab === 'security_chest' ? 'none' : 'security_chest')
              }
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'security_chest'
                  ? 'bg-amber-500 text-slate-950 border-amber-300'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-amber-300 border-amber-500/40'
              }`}
            >
              <span>🧰 Aile Hazinesi & 🔐 6 Haneli Offline PIN</span>
            </button>

            <button
              type="button"
              onClick={() =>
                setMgmtTab(
                  mgmtTab === 'schedule_weather' ? 'none' : 'schedule_weather'
                )
              }
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition ${
                mgmtTab === 'schedule_weather'
                  ? 'bg-cyan-500 text-slate-950 border-cyan-300'
                  : 'bg-slate-800/90 hover:bg-slate-800 text-cyan-300 border-cyan-500/40'
              }`}
            >
              <span>🎒 Okul Programı, 🌤️ Hava & 🔊 Gürültü Eşiği</span>
            </button>
          </div>
        </div>

        {/* Collapsible Forms for Adding Child / Task / Reward */}
        {mgmtTab === 'child' && (
          <form
            onSubmit={handleAddChildSubmit}
            className="bg-slate-950/90 border border-indigo-500/40 rounded-2xl p-4 space-y-3"
          >
            <div className="text-xs font-black text-indigo-300 uppercase">
              {activeFamily.name} İçin Yeni Öğrenci Profili Oluştur
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div>
                <label className="block text-xs text-slate-400 mb-1">Öğrenci Adı</label>
                <input
                  type="text"
                  required
                  value={childName}
                  onChange={(e) => setChildName(e.target.value)}
                  placeholder="Örn: Kerem"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Sınıf & Yaş Bilgisi</label>
                <input
                  type="text"
                  value={childGrade}
                  onChange={(e) => setChildGrade(e.target.value)}
                  placeholder="Örn: 5. Sınıf (11 Yaş)"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Tema Seviyesi</label>
                <select
                  value={childAgeGroup}
                  onChange={(e) => setChildAgeGroup(e.target.value as 'kid' | 'preteen' | 'teen')}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                >
                  <option value="kid">İlkokul (Kozmik Kaşif Teması)</option>
                  <option value="preteen">Ortaokul (Siber Akademi Teması)</option>
                  <option value="teen">Lise (Modern Odak Teması)</option>
                </select>
              </div>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-slate-400 mr-1">Avatar:</span>
                {CHILD_EMOJIS.map((em) => (
                  <button
                    key={em}
                    type="button"
                    onClick={() => setChildEmoji(em)}
                    className={`w-8 h-8 rounded-lg text-base flex items-center justify-center ${
                      childEmoji === em ? 'bg-indigo-600 scale-110' : 'bg-slate-800'
                    }`}
                  >
                    {em}
                  </button>
                ))}
              </div>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-emerald-500 text-slate-950 font-black text-xs"
              >
                Öğrenciyi Kaydet
              </button>
            </div>
          </form>
        )}

        {mgmtTab === 'task' && (
          <form
            onSubmit={handleAddTaskSubmit}
            className="bg-slate-950/90 border border-indigo-500/40 rounded-2xl p-4 space-y-3"
          >
            <div className="text-xs font-black text-indigo-300 uppercase">
              {activeFamily.name} İçin Yeni Görev / Rutin Tanımla
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
              <div>
                <label className="block text-xs text-slate-400 mb-1">Kime Atansın?</label>
                <select
                  value={newTaskTarget}
                  onChange={(e) => setNewTaskTarget(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                >
                  <option value="both">Tüm Çocuklara Ortak (Co-op)</option>
                  {childrenUsers.map((c) => (
                    <option key={c.id} value={c.id}>
                      Sadece {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Kategori</label>
                <select
                  value={newTaskCat}
                  onChange={(e) => setNewTaskCat(e.target.value as TaskCategory)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                >
                  <option value="academic">📸 Akademik (Fotoğraf Kanıtlı)</option>
                  <option value="routine_morning">☀️ Sabah Rutini (+15 Combo)</option>
                  <option value="routine_evening">🌙 Akşam Rutini</option>
                  <option value="coop">🤝 Kardeş Dayanışması</option>
                </select>
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Puan Ödülü</label>
                <input
                  type="number"
                  value={newTaskPoints}
                  onChange={(e) => setNewTaskPoints(Number(e.target.value))}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Hedef Saat</label>
                <input
                  type="text"
                  value={newTaskDue}
                  onChange={(e) => setNewTaskDue(e.target.value)}
                  placeholder="18:30"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <input
                type="text"
                required
                value={newTaskTitle}
                onChange={(e) => setNewTaskTitle(e.target.value)}
                placeholder="Görev Başlığı (Örn: Türkçe Paragraf Testi Çözümü)"
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              />
              <input
                type="text"
                value={newTaskDesc}
                onChange={(e) => setNewTaskDesc(e.target.value)}
                placeholder="Açıklama (Örn: Çözdüğün sayfaların fotoğrafını çekip gönder)"
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              />
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-2 text-xs text-slate-300">
                <span>Doğrulama Yöntemi:</span>
                <select
                  value={newTaskVerifType}
                  onChange={(e) =>
                    setNewTaskVerifType(e.target.value as TaskVerificationType)
                  }
                  className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white"
                >
                  <option value="photo_optional">
                    📸 İsteğe Bağlı Fotoğraf veya 👀 Fiziksel Kontrol Çağrısı
                  </option>
                  <option value="physical_check">
                    🏃‍♂️ Yanına Gidip Fiziksel Kontrol (veya Fotoğraf)
                  </option>
                  <option value="direct_submit">
                    ✅ Doğrudan Tek Tıkla Tamamla (Örn: Diş Fırçalama / Çanta)
                  </option>
                  <option value="qr_scan">
                    📷 Fiziksel QR İstasyonu Okutarak Doğrulama (qr_scan)
                  </option>
                </select>

                {newTaskVerifType === 'qr_scan' && (
                  <select
                    value={newTaskQrStationId}
                    onChange={(e) => setNewTaskQrStationId(e.target.value)}
                    className="bg-slate-900 border border-emerald-500/50 rounded-xl px-3 py-1.5 text-xs text-emerald-300 font-bold"
                  >
                    {qrStations.map((st) => (
                      <option key={st.id} value={st.id}>
                        📷 {st.title} ({st.station_code})
                      </option>
                    ))}
                  </select>
                )}

                <label className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-500/15 border border-amber-400/40 text-amber-300 font-bold text-xs cursor-pointer">
                  <input
                    type="checkbox"
                    checked={newTaskIsRace}
                    onChange={(e) => setNewTaskIsRace(e.target.checked)}
                    className="rounded border-amber-400"
                  />
                  <span>⚡ İlk Kapar Yarışı (Tek Kişilik)</span>
                </label>
              </div>
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-emerald-500 text-slate-950 font-black text-xs"
              >
                Görevi Ekle
              </button>
            </div>
          </form>
        )}

        {mgmtTab === 'reward' && (
          <form
            onSubmit={handleAddRewardSubmit}
            className="bg-slate-950/90 border border-indigo-500/40 rounded-2xl p-4 space-y-3"
          >
            <div className="text-xs font-black text-indigo-300 uppercase">
              {activeFamily.name} Marketine Yeni Ödül Ekle
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
              <div className="sm:col-span-2">
                <label className="block text-xs text-slate-400 mb-1">Ödül Başlığı</label>
                <input
                  type="text"
                  required
                  value={newRewTitle}
                  onChange={(e) => setNewRewTitle(e.target.value)}
                  placeholder="Örn: 🎮 45 Dakika PlayStation / Tablet Süresi"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Puan Maliyeti</label>
                <input
                  type="number"
                  value={newRewCost}
                  onChange={(e) => setNewRewCost(Number(e.target.value))}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Kademe</label>
                <select
                  value={newRewTier}
                  onChange={(e) => setNewRewTier(e.target.value as RewardTier)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                >
                  <option value="micro">⚡ Mikro (Otomatik Ekran Kilidi Açar)</option>
                  <option value="medium">🍕 Orta Kademe</option>
                  <option value="large">🏆 Büyük Hedef</option>
                  <option value="parent_challenge">
                    🎯 Ebeveyne Meydan Oku (Babaya 10 Şınav vb.)
                  </option>
                </select>
              </div>
            </div>
            <div className="flex items-center justify-between">
              {newRewTier === 'micro' ? (
                <div className="flex items-center gap-2 text-xs text-slate-300">
                  <span>Onaylandığında tüm cihazların kilidini kaç dk açsın?</span>
                  <input
                    type="number"
                    value={newRewUnlockMin}
                    onChange={(e) => setNewRewUnlockMin(Number(e.target.value))}
                    className="w-20 bg-slate-900 border border-slate-700 rounded-lg px-2 py-1 text-xs text-white"
                  />
                  <span>dk</span>
                </div>
              ) : (
                <span className="text-xs text-slate-400">Özel aile etkinliği / meydan okuma ödülü</span>
              )}
              <button
                type="submit"
                className="px-5 py-2 rounded-xl bg-emerald-500 text-slate-950 font-black text-xs"
              >
                Ödülü Markete Ekle
              </button>
            </div>
          </form>
        )}

        {/* Phase 2: QR Station Generator & One-Click Print View */}
        {mgmtTab === 'qr' && (
          <div className="bg-slate-950/90 border border-emerald-500/40 rounded-2xl p-4 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="text-xs font-black text-emerald-300 uppercase">
                📷 Fiziksel QR İstasyonu Üretici & Tek Tıkla Yazdırma Merkezi
              </div>
              <span className="text-[11px] text-slate-400">
                Banyo aynasına, çalışma masasına veya kitaplığa yapıştırılacak QR kodlar
              </span>
            </div>

            <form
              onSubmit={handleAddQRStationSubmit}
              className="grid grid-cols-1 sm:grid-cols-4 gap-3 items-end"
            >
              <div>
                <label className="block text-xs text-slate-400 mb-1">
                  İstasyon Kodu (Benzersiz)
                </label>
                <input
                  type="text"
                  required
                  value={newQrCode}
                  onChange={(e) => setNewQrCode(e.target.value)}
                  placeholder="STATION_BATHROOM_01"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">
                  İstasyon Başlığı
                </label>
                <input
                  type="text"
                  required
                  value={newQrTitle}
                  onChange={(e) => setNewQrTitle(e.target.value)}
                  placeholder="Banyo Aynası Sabah İstasyonu"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">
                  Tetiklenecek Aksiyon
                </label>
                <select
                  value={newQrAction}
                  onChange={(e) =>
                    setNewQrAction(e.target.value as QRStationLinkedAction)
                  }
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                >
                  <option value="dismiss_wake_up_alarm">
                    ☀️ Sabah Alarmını Sustur + Diş Fırçası Sayacı Başlat
                  </option>
                  <option value="start_tooth_brushing">
                    🪥 2 Dk Diş Fırçalama Sayacı Başlat
                  </option>
                  <option value="complete_task">
                    ✅ Görev Doğrulaması Tamamla
                  </option>
                </select>
              </div>
              <button
                type="submit"
                className="px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs transition"
              >
                + QR İstasyonu Oluştur
              </button>
            </form>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
              {qrStations.map((station) => (
                <PrintableQRStationCard key={station.id} station={station} />
              ))}
            </div>
          </div>
        )}

        {/* Phase 2: Family Treasure Chest & 6-Digit Offline Master PIN Settings */}
        {mgmtTab === 'security_chest' && (
          <div className="bg-slate-950/90 border border-amber-500/40 rounded-2xl p-4 grid grid-cols-1 lg:grid-cols-2 gap-4">
            <form
              onSubmit={handleSaveChestConfig}
              className="bg-slate-900/90 border border-amber-500/30 rounded-2xl p-4 space-y-3"
            >
              <div className="text-xs font-black text-amber-300 uppercase">
                🧰 Ortak Aile Hazine Sandığı (Family Co-op Chest) Ayarları
              </div>
              <p className="text-[11px] text-slate-400">
                Çocukların kazandığı her görev puanı kendi bakiyelerine eklendiği gibi otomatik olarak bu ortak aile sandığına da eklenir! (Mevcut: {familySettings?.family_chest_current || 0} / {familySettings?.family_chest_goal || 1500} Puan)
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                <div>
                  <label className="block text-xs text-slate-400 mb-1">
                    Sandık Hedef Puanı
                  </label>
                  <input
                    type="number"
                    value={chestGoalInput}
                    onChange={(e) => setChestGoalInput(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-bold"
                  />
                </div>
                <div className="sm:col-span-2">
                  <label className="block text-xs text-slate-400 mb-1">
                    Sandık Dolunca Kazanılacak Ortak Aile Ödülü
                  </label>
                  <input
                    type="text"
                    value={chestRewardTitleInput}
                    onChange={(e) => setChestRewardTitleInput(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                  />
                </div>
              </div>
              <button
                type="submit"
                className="px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-black text-xs transition"
              >
                🧰 Hazine Sandığı Hedefini Güncelle
              </button>
            </form>

            <form
              onSubmit={handleSaveOfflinePin}
              className="bg-slate-900/90 border border-indigo-500/30 rounded-2xl p-4 space-y-3"
            >
              <div className="text-xs font-black text-indigo-300 uppercase">
                🔐 6 Haneli Çevrimdışı Kurtarma Şifresi (Offline Master PIN)
              </div>
              <p className="text-[11px] text-slate-400">
                Evde internet koptuğunda veya çocuğun fişi çekmesi durumunda kilit ekranındaki &quot;🔐 Çevrimdışı Ebeveyn Şifresi&quot; alanına girilecek 6 haneli PIN. Cihazlara SHA-256 hash olarak önbelleklenir (Varsayılan: <code className="text-amber-300">145300</code>).
              </p>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  maxLength={6}
                  value={offlinePinInput}
                  onChange={(e) =>
                    setOfflinePinInput(e.target.value.replace(/\D/g, '').slice(0, 6))
                  }
                  placeholder="6 Haneli PIN (Örn: 145300)"
                  className="bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white font-mono tracking-widest w-44 text-center"
                />
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-black text-xs transition"
                >
                  🔐 SHA-256 İle Şifrele & Kaydet
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Phase 3: Weekly School Schedule Editor & Weather / Noise Settings */}
        {mgmtTab === 'schedule_weather' && (
          <div className="bg-slate-950/90 border border-cyan-500/40 rounded-2xl p-4 grid grid-cols-1 lg:grid-cols-2 gap-4">
            <form
              onSubmit={handleSaveScheduleSubmit}
              className="bg-slate-900/90 border border-cyan-500/30 rounded-2xl p-4 space-y-3"
            >
              <div className="text-xs font-black text-cyan-300 uppercase">
                🎒 Haftalık Okul & Kurs Ders Programı (Akıllı Çanta Listesi)
              </div>
              <p className="text-[11px] text-slate-400">
                Akşam &quot;Çantanı Hazırla&quot; görevinde çocuğun karşısına ertesi günün derslerine göre otomatik kontrol listesi çıkar (Kayıtlı gün sayısı: {schoolSchedules.length}).
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                <div>
                  <label className="block text-[11px] text-slate-400 mb-1">
                    Öğrenci Seçin
                  </label>
                  <select
                    value={schedChildId}
                    onChange={(e) => setSchedChildId(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                  >
                    {childrenUsers.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.avatar_config.emoji} {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] text-slate-400 mb-1">
                    Haftanın Günü
                  </label>
                  <select
                    value={schedDay}
                    onChange={(e) => setSchedDay(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                  >
                    <option value={1}>1 - Pazartesi</option>
                    <option value={2}>2 - Salı</option>
                    <option value={3}>3 - Çarşamba</option>
                    <option value={4}>4 - Perşembe</option>
                    <option value={5}>5 - Cuma</option>
                    <option value={6}>6 - Cumartesi (Kurs/Etüt)</option>
                    <option value={7}>7 - Pazar</option>
                  </select>
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-4 text-xs text-slate-200 pt-1">
                <label className="flex items-center gap-1.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={schedHasPe}
                    onChange={(e) => setSchedHasPe(e.target.checked)}
                    className="rounded"
                  />
                  <span>👟 Beden Eğitimi Var (Eşofman & Suluk)</span>
                </label>
                <label className="flex items-center gap-1.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={schedHasArt}
                    onChange={(e) => setSchedHasArt(e.target.checked)}
                    className="rounded"
                  />
                  <span>🎨 Görsel Sanatlar / Resim Var (Boya & Çanta)</span>
                </label>
              </div>

              <div>
                <label className="block text-[11px] text-slate-400 mb-1">
                  Çantaya Konulacak Ek Eşyalar (Virgülle ayırın)
                </label>
                <input
                  type="text"
                  value={schedCustomItems}
                  onChange={(e) => setSchedCustomItems(e.target.value)}
                  placeholder="Eşofman takımı, Suluk, Matematik defteri"
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white"
                />
              </div>

              <div>
                <label className="block text-[11px] text-slate-400 mb-1">
                  Akşam Çanta Hatırlatma Mesajı
                </label>
                <input
                  type="text"
                  value={schedNote}
                  onChange={(e) => setSchedNote(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white"
                />
              </div>

              <button
                type="submit"
                className="px-4 py-2 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black text-xs transition"
              >
                🎒 Ders Programı & Çanta Listesini Kaydet
              </button>
            </form>

            <form
              onSubmit={handleSaveWeatherAndNoiseSubmit}
              className="bg-slate-900/90 border border-emerald-500/30 rounded-2xl p-4 space-y-3"
            >
              <div className="text-xs font-black text-emerald-300 uppercase">
                🌤️ Canlı Hava Durumu (Open-Meteo) & 🔊 Akıllı Gürültü Sensörü
              </div>
              <p className="text-[11px] text-slate-400">
                Sabah rutinlerinde ve Dijital Yoldaş kıyafetinde kullanılan şehir koordinatları ile ders/serbest zamanda mikrofon dB uyarı eşiğini ayarlayın.
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                <div>
                  <label className="block text-[11px] text-slate-400 mb-1">
                    Enlem (city_lat)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={cityLatInput}
                    onChange={(e) => setCityLatInput(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[11px] text-slate-400 mb-1">
                    Boylam (city_lon)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={cityLonInput}
                    onChange={(e) => setCityLonInput(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[11px] text-slate-400 mb-1">
                    Gürültü Eşiği (dB)
                  </label>
                  <input
                    type="number"
                    min={50}
                    max={105}
                    value={noiseDbInput}
                    onChange={(e) => setNoiseDbInput(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-amber-300 font-bold"
                  />
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
                <span>Hızlı Şehir Seçimi:</span>
                <button
                  type="button"
                  onClick={() => {
                    setCityLatInput(41.08);
                    setCityLonInput(31.12);
                  }}
                  className="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-200"
                >
                  Akçakoca / Düzce (41.08, 31.12)
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setCityLatInput(41.01);
                    setCityLonInput(28.97);
                  }}
                  className="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-200"
                >
                  İstanbul (41.01, 28.97)
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setCityLatInput(39.93);
                    setCityLonInput(32.85);
                  }}
                  className="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-200"
                >
                  Ankara (39.93, 32.85)
                </button>
              </div>

              <button
                type="submit"
                className="px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs transition"
              >
                🌤️ Hava & 🔊 Gürültü Eşiğini Kaydet
              </button>
            </form>
          </div>
        )}
      </div>

      {/* SECTION 1: LIVE STUDENT CARDS, MULTI-DEVICE MONITOR & QUICK COMMANDS */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {childrenUsers.map((child) => {
          const childDevices = devices.filter((d) => d.user_id === child.id);
          const remSec = remainingSecondsByUser[child.id] || 0;
          const mins = Math.floor(remSec / 60);
          const secs = remSec % 60;
          const moodInfo = MOOD_BADGES[child.current_mood] || MOOD_BADGES.happy;

          return (
            <div
              key={child.id}
              className="bg-slate-900/95 border border-slate-800 rounded-3xl p-5 sm:p-6 shadow-xl space-y-5"
            >
              {/* Student Profile, Mood, Shields & Current State */}
              <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-slate-800">
                <div className="flex items-center gap-3.5">
                  <div
                    className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${child.avatar_config.bg} flex items-center justify-center text-3xl shadow-md`}
                  >
                    {child.avatar_config.emoji}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h2 className="text-xl font-black text-white">
                        {child.name}
                      </h2>
                      <span className="text-xs text-slate-400 font-semibold">
                        ({child.avatar_config.grade})
                      </span>
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-xs font-bold ${moodInfo.color}`}
                      >
                        {moodInfo.emoji} {moodInfo.label}
                      </span>
                    </div>

                    <div className="flex flex-wrap items-center gap-2 mt-1.5">
                      <span
                        className={`px-2.5 py-0.5 rounded-lg text-xs font-extrabold ${
                          child.current_state === 'STUDY_TIME'
                            ? 'bg-amber-500/20 text-amber-300 border border-amber-400/40'
                            : child.current_state === 'WAKE_UP_ALARM'
                            ? 'bg-rose-500 text-white animate-pulse'
                            : child.current_state === 'BREAK_TIME'
                            ? 'bg-emerald-500/20 text-emerald-300'
                            : child.current_state === 'SLEEP_TIME'
                            ? 'bg-indigo-500/20 text-indigo-300'
                            : 'bg-slate-800 text-slate-300'
                        }`}
                      >
                        Mod: {child.current_state}
                      </span>
                      {remSec > 0 && (
                        <span className="px-2.5 py-0.5 rounded-lg bg-indigo-600 text-white font-mono font-bold text-xs flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
                        </span>
                      )}
                      {child.companion_config && (
                        <span className="px-2.5 py-0.5 rounded-lg bg-fuchsia-500/20 border border-fuchsia-400/40 text-fuchsia-200 font-bold text-[11px]">
                          🐉 Yoldaş: {child.companion_config.name} (Sv.{child.companion_config.level} • {child.companion_config.xp} XP)
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Points & Daily Shields */}
                <div className="flex items-center gap-4">
                  <div className="text-right">
                    <div className="text-xs text-slate-400">Puan / Kasa</div>
                    <div className="text-sm font-black text-amber-400">
                      {child.points_balance} P{' '}
                      <span className="text-amber-300">
                        (💎 {child.piggy_bank_balance})
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-1 bg-slate-950 px-3 py-2 rounded-2xl border border-slate-800">
                    {[1, 2, 3].map((idx) => (
                      <Shield
                        key={idx}
                        className={`w-5 h-5 ${
                          idx <= child.daily_shields
                            ? 'text-emerald-400 fill-emerald-400'
                            : 'text-rose-900'
                        }`}
                      />
                    ))}
                  </div>
                </div>
              </div>

              {/* Connected Devices & Active PC Window Title */}
              <div>
                <div className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Bağlı Cihazlar & Canlı Pencere Başlığı (Multi-Device Sync)
                </div>
                <div className="space-y-2">
                  {childDevices.map((dev) => (
                    <div
                      key={dev.id}
                      className="bg-slate-950/80 border border-slate-800 rounded-2xl px-3.5 py-2.5 flex flex-wrap items-center justify-between gap-2 text-xs"
                    >
                      <div className="flex items-center gap-2.5">
                        {dev.device_type === 'windows_pc' && (
                          <Monitor className="w-4 h-4 text-indigo-400" />
                        )}
                        {dev.device_type === 'tablet' && (
                          <Tablet className="w-4 h-4 text-purple-400" />
                        )}
                        {dev.device_type === 'ios_phone' && (
                          <Smartphone className="w-4 h-4 text-emerald-400" />
                        )}
                        <div>
                          <div className="font-bold text-white flex items-center gap-1.5">
                            <span>{dev.device_name}</span>
                            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                          </div>
                          <div className="text-slate-400 text-[11px]">
                            Aktif Pencere:{' '}
                            <strong className="text-indigo-300">
                              {dev.active_window_title}
                            </strong>
                          </div>
                        </div>
                      </div>

                      {dev.device_type === 'windows_pc' && (
                        <div className="flex items-center gap-1.5">
                          <button
                            type="button"
                            onClick={() => {
                              sendDirectMessage(
                                activeUser.id,
                                child.id,
                                'quick_request',
                                `[CMD:SCREENSHOT] 📸 ${dev.device_name} anlık ekran görüntüsü talebi gönderildi.`
                              );
                              showStatus(`📸 ${dev.device_name} ajanına 'Anlık Ekran Görüntüsü Al (mss)' komutu gönderildi!`);
                            }}
                            title="Windows Ajanına mss ile Ekran Görüntüsü Alma Komutu Gönder"
                            className="px-2.5 py-1 rounded-lg bg-indigo-500/20 hover:bg-indigo-500/35 border border-indigo-400/40 text-indigo-200 font-bold text-[11px] flex items-center gap-1 transition"
                          >
                            <Camera className="w-3 h-3" />
                            <span>Ekran Görüntüsü Al</span>
                          </button>

                          <button
                            type="button"
                            onClick={() => {
                              sendDirectMessage(
                                activeUser.id,
                                child.id,
                                'quick_request',
                                `[CMD:PACK_BAG] 🎒 ${child.name} için sesli çanta hazırlama hatırlatıcısı gönderildi.`
                              );
                              showStatus(`🎒 ${child.name} için PC sesli çanta hazırlama anonsu gönderildi!`);
                            }}
                            title="Windows Ajanına Yarının Derslerini Sesli Olarak Okuma Komutu Gönder"
                            className="px-2.5 py-1 rounded-lg bg-purple-500/20 hover:bg-purple-500/35 border border-purple-400/40 text-purple-200 font-bold text-[11px] flex items-center gap-1 transition"
                          >
                            <Volume2 className="w-3 h-3" />
                            <span>Çanta Hatırlat (Sesli)</span>
                          </button>

                          <button
                            type="button"
                            onClick={() =>
                              recordViolation(
                                child.id,
                                'pc_mouse_move',
                                dev.device_name
                              )
                            }
                            title="Windows PC Ajanı İhlal Testi"
                            className="px-2.5 py-1 rounded-lg bg-rose-500/15 hover:bg-rose-500/25 border border-rose-500/30 text-rose-300 font-semibold text-[11px] transition"
                          >
                            PC İhlal Testi
                          </button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Instant Multi-Device Remote Command Buttons */}
              <div>
                <div className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Hızlı Komutlar (Tüm Cihazları Aynı Anda Kontrol Et)
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'STUDY_TIME', 40)}
                    className="py-2.5 px-3 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <Lock className="w-4 h-4" />
                    <span>Ders Modu (40dk Kilitle)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => addBonusTimeMinutes(child.id, 15)}
                    className="py-2.5 px-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <PlusCircle className="w-4 h-4" />
                    <span>+15 Dk Ek Süre Ver</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'BREAK_TIME', 10)}
                    className="py-2.5 px-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <Coffee className="w-4 h-4" />
                    <span>Mola Başlat (Zil Çal)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => triggerWakeUpAlarm(child.id)}
                    className="py-2.5 px-3 rounded-xl bg-rose-600 hover:bg-rose-500 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <Sun className="w-4 h-4" />
                    <span>Uyandırma Alarmı Çal</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'SLEEP_TIME', 480)}
                    className="py-2.5 px-3 rounded-xl bg-indigo-700 hover:bg-indigo-600 text-white font-bold text-xs flex items-center justify-center gap-1.5 transition"
                  >
                    <Moon className="w-4 h-4" />
                    <span>Uyku Moduna Al</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'FREE_TIME', null)}
                    className="py-2.5 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold text-xs flex items-center justify-center gap-1.5 transition"
                  >
                    <Unlock className="w-4 h-4" />
                    <span>Kilidi Aç (Serbest)</span>
                  </button>

                  {/* Phase 2: 3 New Real-World Modes */}
                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'COMPUTER_STUDY', 45)}
                    className="py-2.5 px-3 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <Monitor className="w-4 h-4" />
                    <span>💻 Bilgisayarlı Ders (45dk)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'GUEST_MODE', 90)}
                    className="py-2.5 px-3 rounded-xl bg-fuchsia-600 hover:bg-fuchsia-500 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <span>🎮 Misafir Modu (90dk)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'FROZEN_HOLIDAY', null)}
                    className="py-2.5 px-3 rounded-xl bg-teal-600 hover:bg-teal-500 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <span>🏖️ Tatil Modu (Dondur)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setStudentState(child.id, 'CO_STUDY_MODE', 40)}
                    className="py-2.5 px-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-black text-xs flex items-center justify-center gap-1.5 shadow-lg transition"
                  >
                    <span>👥 Arkadaşla Ders (40dk)</span>
                  </button>
                </div>

                {/* Phase 2: Whitelist Configuration Drawer Toggle for COMPUTER_STUDY */}
                <div className="mt-3 pt-3 border-t border-slate-800/80">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="text-[11px] text-slate-400">
                      💻 Bilgisayarlı Ders İzinli Uygulamalar (Whitelist):{' '}
                      <strong className="text-blue-300">
                        {(child.whitelist_config?.allowed_exes || ['chrome.exe', 'winword.exe']).join(', ')}
                      </strong>
                    </span>
                    <button
                      type="button"
                      onClick={() => handleOpenWhitelistForChild(child)}
                      className="text-[11px] font-bold text-indigo-300 hover:text-indigo-200 underline"
                    >
                      {openWhitelistChildId === child.id
                        ? 'Kapat'
                        : '⚙️ Whitelist Düzenle (.exe & Kelime)'}
                    </button>
                  </div>

                  {openWhitelistChildId === child.id && (
                    <div className="mt-2 bg-slate-950 border border-blue-500/40 rounded-2xl p-3 space-y-2.5">
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">
                          İzin Verilen .exe Dosyaları (Virgülle ayırın)
                        </label>
                        <input
                          type="text"
                          value={whitelistExesInput}
                          onChange={(e) => setWhitelistExesInput(e.target.value)}
                          className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white font-mono"
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">
                          İzin Verilen Pencere Başlığı Anahtar Kelimeleri (Virgülle ayırın)
                        </label>
                        <input
                          type="text"
                          value={whitelistKeywordsInput}
                          onChange={(e) => setWhitelistKeywordsInput(e.target.value)}
                          className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white"
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => handleSaveWhitelistForChild(child.id)}
                        className="px-4 py-1.5 rounded-xl bg-blue-500 hover:bg-blue-400 text-slate-950 font-black text-xs transition"
                      >
                        Kaydet & Windows Ajanına Gönder
                      </button>
                    </div>
                  )}
                </div>

                {/* Phase 6: Member Access Credentials, Magic Link & Desktop Pairing Code Card */}
                <div className="mt-4 pt-3.5 border-t border-slate-800 space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="text-[11px] font-black text-indigo-400 uppercase tracking-wider flex items-center gap-1.5">
                      <KeyRound className="w-3.5 h-3.5 text-amber-400" />
                      <span>Giriş & Cihaz Eşleştirme Bilgileri</span>
                    </span>
                    <button
                      type="button"
                      onClick={() => setSelectedStudentForSchedule(child)}
                      className="px-2.5 py-1 rounded-xl bg-purple-600/30 hover:bg-purple-600/50 border border-purple-500/40 text-purple-200 text-xs font-bold flex items-center gap-1 transition"
                    >
                      <CalendarDays className="w-3.5 h-3.5" />
                      <span>Haftalık Ders Çizelgesi</span>
                    </button>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                    {/* Username & PIN */}
                    <div className="p-2.5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-1">
                      <div className="text-[10px] text-slate-500 font-bold uppercase">
                        Kullanıcı Adı / Şifre (PIN)
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="font-mono font-bold text-white">
                          {child.username || `${child.name.toLowerCase()}.101`}
                        </span>
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono font-bold text-amber-400">
                            {revealedPasswordId === child.id
                              ? child.access_password || '123456'
                              : '••••••'}
                          </span>
                          <button
                            type="button"
                            onClick={() =>
                              setRevealedPasswordId(
                                revealedPasswordId === child.id ? null : child.id
                              )
                            }
                            className="text-slate-400 hover:text-white p-1"
                            title="Şifreyi Göster/Gizle"
                          >
                            {revealedPasswordId === child.id ? (
                              <EyeOff className="w-3.5 h-3.5" />
                            ) : (
                              <Eye className="w-3.5 h-3.5" />
                            )}
                          </button>
                        </div>
                      </div>
                    </div>

                    {/* Desktop Pairing Code */}
                    <div className="p-2.5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-1">
                      <div className="text-[10px] text-slate-500 font-bold uppercase flex items-center justify-between">
                        <span>🖥️ Masaüstü Eşleştirme Kodu</span>
                        <button
                          type="button"
                          onClick={async () => {
                            const newCode = await regenerateDesktopPairingCode(child.id);
                            showStatus(`🔄 ${child.name} için yeni masaüstü kodu: ${newCode}`);
                          }}
                          className="text-[10px] text-indigo-400 hover:underline"
                        >
                          Yeni Kod Üret
                        </button>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="font-mono font-black text-sm text-cyan-300">
                          {child.desktop_pairing_code || '849-201'}
                        </span>
                        <button
                          type="button"
                          onClick={() => {
                            if (typeof navigator !== 'undefined') {
                              navigator.clipboard.writeText(child.desktop_pairing_code || '849-201');
                              showStatus(`📋 ${child.name} masaüstü eşleştirme kodu kopyalandı!`);
                            }
                          }}
                          className="px-2 py-0.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[10px] font-bold flex items-center gap-1"
                        >
                          <Copy className="w-3 h-3" />
                          <span>Kopyala</span>
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Magic Login Link & QR Scan Buttons */}
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        const link = buildMagicLoginUrl(child.magic_login_token || child.id);
                        if (typeof navigator !== 'undefined') {
                          navigator.clipboard.writeText(link);
                          showStatus(`📲 ${child.name} için tek tıkla sihirli giriş linki kopyalandı!`);
                        }
                      }}
                      className="flex-1 py-2 px-3 rounded-xl bg-indigo-600/25 hover:bg-indigo-600/40 border border-indigo-500/40 text-indigo-200 font-bold text-xs flex items-center justify-center gap-1.5 transition"
                    >
                      <Share2 className="w-3.5 h-3.5 text-indigo-300" />
                      <span>📲 Giriş Linkini Kopyala</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => setSelectedStudentForQR(child)}
                      className="py-2 px-3 rounded-xl bg-purple-600/25 hover:bg-purple-600/40 border border-purple-500/40 text-purple-200 font-bold text-xs flex items-center gap-1.5 transition"
                    >
                      <QrCode className="w-3.5 h-3.5 text-purple-300" />
                      <span>📷 QR Kod ile Okut</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* SECTION 2: ATOMIC PHOTO PROOF APPROVALS & REWARD REDEMPTIONS */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Pending Photo Proof Task Approvals */}
        <div className="lg:col-span-7 bg-slate-900/95 border border-slate-800 rounded-3xl p-5 sm:p-6">
          {/* Phase 4: ⚖️ Bekleyen İtirazlar (Mahkeme Çağrısı / Adalet Divanı) */}
          {pendingAppeals.length > 0 && (
            <div className="mb-6 pb-5 border-b border-slate-800 space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <Scale className="w-5 h-5 text-amber-400" />
                  <h3 className="text-base font-black text-amber-300">
                    ⚖️ Bekleyen İtirazlar • Mahkeme Çağrısı ({pendingAppeals.length})
                  </h3>
                </div>
                <span className="text-[11px] bg-amber-500/20 text-amber-300 px-2.5 py-0.5 rounded-full font-bold border border-amber-400/30">
                  Adalet Divanı • Kalkan Tamiri
                </span>
              </div>

              {pendingAppeals.map((appeal) => {
                const student = users.find((u) => u.id === appeal.user_id);
                const violation = violations.find(
                  (v) => v.id === appeal.violation_id
                );
                return (
                  <div
                    key={appeal.id}
                    className="bg-slate-950 border-2 border-amber-400/40 rounded-2xl p-4 space-y-3 shadow-lg"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-2.5">
                        <span className="text-2xl">
                          {student?.avatar_config.emoji || '⚖️'}
                        </span>
                        <div>
                          <div className="text-sm font-black text-white">
                            {student?.name || 'Öğrenci'} Savunma Gönderdi
                          </div>
                          {violation && (
                            <div className="text-[11px] text-rose-300 font-semibold">
                              İtiraz Edilen İhlal: {violation.violation_type} (
                              {violation.device_id})
                            </div>
                          )}
                        </div>
                      </div>
                      <span className="text-[11px] text-slate-400">
                        {new Date(appeal.created_at).toLocaleTimeString('tr-TR', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </span>
                    </div>

                    <div className="rounded-xl bg-slate-900 border border-slate-800 p-3 text-xs text-amber-100">
                      💬 <strong>Savunma:</strong> &ldquo;{appeal.reason_text}&rdquo;
                    </div>

                    {appeal.audio_url && (
                      <div className="flex items-center justify-between gap-2 rounded-xl bg-indigo-950/50 border border-indigo-500/30 p-2.5">
                        <span className="text-xs font-bold text-indigo-200 flex items-center gap-1.5">
                          <Volume2 className="w-4 h-4 text-indigo-400" />
                          <span>15sn Sesli Savunma Kaydı:</span>
                        </span>
                        <audio
                          src={appeal.audio_url}
                          controls
                          className="h-8 max-w-[220px]"
                        />
                      </div>
                    )}

                    <div className="flex flex-wrap items-center justify-end gap-2 pt-1">
                      <button
                        type="button"
                        onClick={async () => {
                          const res = await resolveAppeal(
                            appeal.id,
                            activeUser.id,
                            'accepted'
                          );
                          showStatus(res.message);
                        }}
                        className="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-400 to-teal-400 hover:brightness-110 text-slate-950 font-black text-xs flex items-center gap-1.5 shadow-lg transition"
                      >
                        <Shield className="w-4 h-4" />
                        <span>🛡️ Haklısın, Kalkanı Tamir Et (+1🛡️ & +10 P)</span>
                      </button>

                      <button
                        type="button"
                        onClick={async () => {
                          const res = await resolveAppeal(
                            appeal.id,
                            activeUser.id,
                            'rejected'
                          );
                          showStatus(res.message);
                        }}
                        className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-rose-300 font-bold text-xs transition"
                      >
                        İtirazı Reddet
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Phase 4: ✈️ Otomatik Onaylanan Görevleri Gözden Geçir (Optimistic Approvals) */}
          {optimisticSubmissions.length > 0 && (
            <div className="mb-6 pb-5 border-b border-slate-800 space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <Plane className="w-5 h-5 text-cyan-400" />
                  <h3 className="text-base font-black text-cyan-300">
                    ✈️ Otomatik Onaylanan Görevleri Gözden Geçir ({optimisticSubmissions.length})
                  </h3>
                </div>
                <button
                  type="button"
                  onClick={async () => {
                    await finalizeAllOptimisticApprovals();
                    showStatus(
                      '✈️ Otomatik ön-onay alan tüm görevler kesinleştirildi!'
                    );
                  }}
                  className="px-3.5 py-1.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black text-xs transition shadow-md"
                >
                  ✅ Tümünü Kesinleştir
                </button>
              </div>

              <div className="space-y-2.5">
                {optimisticSubmissions.map((sub) => {
                  const student = users.find((u) => u.id === sub.user_id);
                  const task = tasks.find((t) => t.id === sub.task_id);
                  return (
                    <div
                      key={sub.id}
                      className="bg-slate-950 border border-cyan-500/40 rounded-2xl p-3.5 flex flex-wrap items-center justify-between gap-3"
                    >
                      <div className="flex items-center gap-3">
                        {sub.photo_urls.length > 0 && (
                          <button
                            type="button"
                            onClick={() => setZoomedPhoto(sub.photo_urls[0])}
                            className="w-14 h-14 rounded-xl overflow-hidden border border-cyan-400/50 shrink-0"
                          >
                            <img
                              src={sub.photo_urls[0]}
                              alt="Ön-Onay Kanıtı"
                              className="w-full h-full object-cover"
                            />
                          </button>
                        )}
                        <div>
                          <div className="text-sm font-black text-white">
                            {student?.avatar_config.emoji} {student?.name} —{' '}
                            <span className="text-cyan-300">{task?.title}</span>
                          </div>
                          <div className="text-xs text-slate-400">
                            ✈️ Güven Modu ile <strong>+{task?.points} Puan</strong>{' '}
                            anında yüklendi
                          </div>
                        </div>
                      </div>

                      <button
                        type="button"
                        onClick={async () => {
                          const res = await revertOptimisticApproval(sub.id);
                          showStatus(res.message);
                        }}
                        className="px-3 py-1.5 rounded-xl bg-rose-600/20 hover:bg-rose-600/35 border border-rose-500/40 text-rose-300 font-bold text-xs flex items-center gap-1.5 transition"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>İptal Et ve Puanı Geri Al</span>
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Phase 2: Reverse Task Proposals from Children */}
          {pendingStudentProposals.length > 0 && (
            <div className="mb-6 pb-5 border-b border-slate-800 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-emerald-400" />
                  <h3 className="text-base font-black text-emerald-300">
                    ➕ Çocuklardan Gelen Yeni Görev Önerileri ({pendingStudentProposals.length})
                  </h3>
                </div>
                <span className="text-[11px] bg-emerald-500/20 text-emerald-300 px-2.5 py-0.5 rounded-full font-bold">
                  Öz-Yönetim & İnisiyatif
                </span>
              </div>

              {pendingStudentProposals.map((propTask) => {
                const proposer = users.find((u) => u.id === propTask.created_by);
                return (
                  <div
                    key={propTask.id}
                    className="bg-slate-950 border border-emerald-500/40 rounded-2xl p-3.5 flex flex-wrap items-center justify-between gap-3"
                  >
                    <div>
                      <div className="text-sm font-black text-white">
                        {proposer?.avatar_config.emoji} {proposer?.name} Görev Önerdi:{' '}
                        <span className="text-emerald-300">{propTask.title}</span>
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {propTask.description} • Talep Edilen Ödül:{' '}
                        <strong className="text-amber-300">+{propTask.points} Puan</strong>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={async () => {
                          await reviewTaskProposal(propTask.id, 'approved');
                          showStatus(`✅ "${propTask.title}" görev önerisi onaylandı ve listeye eklendi!`);
                        }}
                        className="px-3.5 py-1.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs transition"
                      >
                        Kabul Et & Listeye Ekle
                      </button>
                      <button
                        type="button"
                        onClick={async () => {
                          await reviewTaskProposal(propTask.id, 'rejected');
                          showStatus(`❌ "${propTask.title}" görev önerisi reddedildi.`);
                        }}
                        className="px-3 py-1.5 rounded-xl bg-slate-800 text-rose-300 font-bold text-xs"
                      >
                        Reddet
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <Camera className="w-5 h-5 text-amber-400" />
              <h3 className="text-lg font-black text-white">
                Bekleyen Görev Onayları ({pendingSubmissions.length})
              </h3>
            </div>
            <span className="text-[11px] bg-indigo-500/20 text-indigo-300 px-2.5 py-1 rounded-full font-bold">
              Atomik Tekil Onay & PIN Korumalı
            </span>
          </div>

          {pendingSubmissions.length === 0 ? (
            <div className="text-center py-8 text-slate-400 text-sm border border-dashed border-slate-800 rounded-2xl">
              Şu an onay bekleyen görev bulunmuyor. 🎉
            </div>
          ) : (
            <div className="space-y-4">
              {pendingSubmissions.map((sub) => {
                const student = users.find((u) => u.id === sub.user_id);
                const task = tasks.find((t) => t.id === sub.task_id);
                const isPhysicalCheck =
                  sub.submission_method === 'called_parent_for_check';
                return (
                  <div
                    key={sub.id}
                    className={`bg-slate-950/90 border rounded-2xl p-4 space-y-3 ${
                      isPhysicalCheck
                        ? 'border-emerald-400/50 shadow-lg shadow-emerald-500/10'
                        : 'border-amber-400/30'
                    }`}
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <span className="text-2xl">{student?.avatar_config.emoji}</span>
                        <div>
                          <div className="font-black text-white text-sm">
                            {student?.name} — {task?.title}
                          </div>
                          <div className="text-xs font-bold flex flex-wrap items-center gap-2 mt-0.5">
                            <span className="text-amber-300">
                              Ödül: +{task?.points} Puan
                            </span>
                            {isPhysicalCheck ? (
                              <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-400/40 text-[11px]">
                                🏃‍♂️ Fiziksel Kontrol Çağrısı (Yanına Gidip Kontrol Edin)
                              </span>
                            ) : (
                              <span className="px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 text-[11px]">
                                📸 {sub.photo_urls.length} Fotoğraf Kanıtı
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() =>
                            handleSubmissionDecision(sub.id, 'approved')
                          }
                          className="px-4 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs flex items-center gap-1.5 shadow-lg transition"
                        >
                          <CheckCircle2 className="w-4 h-4" />
                          <span>Onayla (+{task?.points} P)</span>
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            handleSubmissionDecision(sub.id, 'rejected')
                          }
                          className="px-3 py-2 rounded-xl bg-rose-600/20 hover:bg-rose-600/40 text-rose-300 font-bold text-xs flex items-center gap-1 transition"
                        >
                          <XCircle className="w-4 h-4" />
                          <span>Tekrar İste</span>
                        </button>
                      </div>
                    </div>

                    {/* Photo Proof Thumbnails */}
                    {sub.photo_urls.length > 0 && (
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                        {sub.photo_urls.map((url, idx) => (
                          <button
                            key={idx}
                            type="button"
                            onClick={() => setZoomedPhoto(url)}
                            className="relative group rounded-xl overflow-hidden border border-slate-700 aspect-video bg-slate-900"
                          >
                            <img
                              src={url}
                              alt={`Ödev Kanıtı ${idx + 1}`}
                              className="w-full h-full object-cover group-hover:scale-105 transition"
                            />
                            <span className="absolute bottom-1 left-1 bg-slate-950/80 text-[10px] text-white px-2 py-0.5 rounded font-bold">
                              Sayfa {idx + 1} (Büyüt)
                            </span>
                          </button>
                        ))}
                      </div>
                    )}

                    {/* Phase 3: Başarı Albümüne Ekle & Ebeveyn Övgü Notu */}
                    <div className="pt-2 border-t border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                      <label className="flex items-center gap-2 text-xs font-bold text-amber-300 cursor-pointer shrink-0">
                        <input
                          type="checkbox"
                          checked={Boolean(albumFeatureBySub[sub.id])}
                          onChange={(e) =>
                            setAlbumFeatureBySub((prev) => ({
                              ...prev,
                              [sub.id]: e.target.checked,
                            }))
                          }
                          className="rounded border-amber-400"
                        />
                        <span>⭐ Başarı Albümüne Ekle (+20 Yoldaş XP)</span>
                      </label>
                      <input
                        type="text"
                        value={praiseNoteBySub[sub.id] || ''}
                        onChange={(e) =>
                          setPraiseNoteBySub((prev) => ({
                            ...prev,
                            [sub.id]: e.target.value,
                          }))
                        }
                        placeholder="💬 Özel Övgü Notu (Örn: Odan pırıl pırıl olmuş, seninle gurur duyuyoruz!)"
                        className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white"
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Pending Reward Redemptions */}
          <div className="mt-6 pt-5 border-t border-slate-800">
            <div className="flex items-center gap-2 mb-3">
              <Gift className="w-5 h-5 text-pink-400" />
              <h4 className="text-base font-black text-white">
                Bekleyen Market Ödül Talepleri ({pendingRedemptions.length})
              </h4>
            </div>

            {pendingRedemptions.length === 0 ? (
              <p className="text-xs text-slate-400">
                Onay bekleyen ödül talebi yok.
              </p>
            ) : (
              <div className="space-y-2.5">
                {pendingRedemptions.map((red) => {
                  const student = users.find((u) => u.id === red.user_id);
                  const reward = rewards.find((r) => r.id === red.reward_id);
                  return (
                    <div
                      key={red.id}
                      className="bg-slate-950 border border-pink-500/30 rounded-2xl p-3.5 flex flex-wrap items-center justify-between gap-2"
                    >
                      <div>
                        <div className="text-sm font-bold text-white">
                          {student?.avatar_config.emoji} {student?.name}:{' '}
                          <span className="text-amber-300">{reward?.title}</span>
                        </div>
                        <div className="text-xs text-slate-400">
                          Maliyet: {reward?.cost_points} Puan{' '}
                          {reward?.auto_action?.type === 'unlock_screen' &&
                            `• Onaylanınca cihaz kilidi otomatik ${reward.auto_action.minutes} dk açılır!`}
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() =>
                            handleRedemptionDecision(red.id, 'approved')
                          }
                          className="px-3.5 py-1.5 rounded-xl bg-emerald-500 text-slate-950 font-black text-xs"
                        >
                          Onayla & Aktifleştir
                        </button>
                        <button
                          type="button"
                          onClick={() =>
                            handleRedemptionDecision(red.id, 'rejected')
                          }
                          className="px-3 py-1.5 rounded-xl bg-slate-800 text-rose-300 font-bold text-xs"
                        >
                          Reddet
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Flash Quest Creator, Violation Logs & Walkie-Talkie DM */}
        <div className="lg:col-span-5 space-y-6">
          {/* Flash Quest (Sürpriz Altın Görev) Sender */}
          <form
            onSubmit={handleSendFlashQuest}
            className="bg-gradient-to-br from-amber-950/60 via-slate-900 to-orange-950/50 border border-amber-400/40 rounded-3xl p-5 space-y-3.5"
          >
            <div className="flex items-center gap-2 text-amber-300 font-black text-base">
              <Zap className="w-5 h-5 fill-current" />
              <span>Sürpriz Altın Görev (Flash Quest) Gönder</span>
            </div>
            <p className="text-xs text-slate-300">
              Çocukların ekranına anında geri sayımlı ve 2 kat puanlı acil görev düşürün!
            </p>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">
                Kime Atansın?
              </label>
              <select
                value={flashTarget}
                onChange={(e) => setFlashTarget(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              >
                <option value="both">🤝 Her İki Kardeşe Ortak</option>
                {childrenUsers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.avatar_config.emoji} Sadece {c.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">
                Görev Başlığı
              </label>
              <input
                type="text"
                value={flashTitle}
                onChange={(e) => setFlashTitle(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1">
                  Altın Puan Ödülü
                </label>
                <input
                  type="number"
                  value={flashPoints}
                  onChange={(e) => setFlashPoints(Number(e.target.value))}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1">
                  Süre (Dakika)
                </label>
                <input
                  type="number"
                  value={flashDuration}
                  onChange={(e) => setFlashDuration(Number(e.target.value))}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
            </div>

            <label className="flex items-center gap-2 text-xs text-slate-300 cursor-pointer">
              <input
                type="checkbox"
                checked={flashRequiresPhoto}
                onChange={(e) => setFlashRequiresPhoto(e.target.checked)}
                className="rounded"
              />
              <span>
                📸 İsteğe bağlı fotoğraf yükleme seçeneği açık olsun (Öğrenci dilerse sizi fiziksel kontrole de çağırabilir)
              </span>
            </label>

            <label className="flex items-center gap-2 rounded-xl border border-amber-400/40 bg-amber-500/15 px-3 py-2 text-xs font-extrabold text-amber-200 cursor-pointer">
              <input
                type="checkbox"
                checked={flashIsRace}
                onChange={(e) => setFlashIsRace(e.target.checked)}
                className="rounded border-amber-400"
              />
              <span>
                ⚡ İlk Kapar Yarışı (Tek Kişilik Kardeş Yarışı — İlk &ldquo;🏃‍♂️ Ben Yaparım!&rdquo; butonuna basan kardeş görevi kapar!)
              </span>
            </label>

            <button
              type="submit"
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-slate-950 font-black text-xs sm:text-sm shadow-xl transition"
            >
              {flashIsRace
                ? '🏃‍♂️ Şimdi İlk Kapar Yarış Görevini Fırlat!'
                : '⚡ Şimdi Sürpriz Görevi Fırlat!'}
            </button>
          </form>

          {/* Walkie-Talkie & DM */}
          <WalkieTalkieDM currentUserId={activeUser.id} compact />

          {/* Recent Shield Violation Sensor Logs */}
          <div className="bg-slate-900/95 border border-rose-500/30 rounded-3xl p-5">
            <div className="flex items-center gap-2 text-rose-400 font-black text-sm mb-3">
              <ShieldAlert className="w-4 h-4" />
              <span>Canlı Kalkan İhlal Sensörü Kayıtları ({violations.length})</span>
            </div>
            {violations.length === 0 ? (
              <p className="text-xs text-slate-400">
                Bugün henüz hiçbir odaklanma kalkanı ihlali yaşanmadı! 🛡️✨
              </p>
            ) : (
              <div className="space-y-2 max-h-40 overflow-y-auto pr-1">
                {violations.slice(0, 8).map((v) => {
                  const st = users.find((u) => u.id === v.user_id);
                  return (
                    <div
                      key={v.id}
                      className="bg-rose-950/30 border border-rose-800/40 rounded-xl px-3 py-2 text-xs flex items-center justify-between"
                    >
                      <div>
                        <span className="font-bold text-rose-200">
                          {st?.name}:
                        </span>{' '}
                        <span className="text-slate-300">
                          {v.violation_type}
                        </span>
                      </div>
                      <span className="text-[10px] text-slate-400">
                        {new Date(v.created_at).toLocaleTimeString('tr-TR')}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Lightbox Modal for Zooming Photo Proofs */}
      {zoomedPhoto && (
        <div
          onClick={() => setZoomedPhoto(null)}
          className="fixed inset-0 z-50 bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-4 cursor-pointer"
        >
          <img
            src={zoomedPhoto}
            alt="Büyütülmüş Ödev Kanıtı"
            className="max-w-3xl max-h-[85vh] rounded-3xl border-2 border-white/20 shadow-2xl object-contain"
          />
        </div>
      )}

      {/* Phase 6: Weekly Schedule Editor Modal */}
      {selectedStudentForSchedule && (
        <WeeklyScheduleEditorModal
          isOpen={Boolean(selectedStudentForSchedule)}
          onClose={() => setSelectedStudentForSchedule(null)}
          student={selectedStudentForSchedule}
          schedules={schoolSchedules}
          onSaveSchedule={async (sched) => {
            await upsertSchoolSchedule(sched);
            showStatus(`🎒 ${selectedStudentForSchedule.name} için haftalık ders programı güncellendi!`);
          }}
        />
      )}

      {/* Phase 6: Member Magic Link QR Code Modal */}
      {selectedStudentForQR && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md">
          <div className="w-full max-w-sm bg-slate-900 border border-indigo-500/30 rounded-3xl p-6 text-white text-center space-y-4 shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <span className="text-2xl">{selectedStudentForQR.avatar_config.emoji}</span>
                <span className="font-black text-sm">{selectedStudentForQR.name} - Giriş QR Kodu</span>
              </div>
              <button
                type="button"
                onClick={() => setSelectedStudentForQR(null)}
                className="text-slate-400 hover:text-white text-sm font-bold"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-slate-300">
              Telefon veya tablet kamerasını bu QR koda tutun; tek tıkla şifre ekranına yönlendirir.
            </p>

            <div className="w-56 h-56 mx-auto bg-white p-3 rounded-2xl flex items-center justify-center shadow-lg">
              <img
                src={`https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(
                  buildMagicLoginUrl(
                    selectedStudentForQR.magic_login_token || selectedStudentForQR.id
                  )
                )}`}
                alt="Giriş QR Kodu"
                className="w-full h-full object-contain"
              />
            </div>

            <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800 text-[11px] text-slate-400">
              Şifre (PIN):{' '}
              <strong className="text-amber-400 font-mono text-xs">
                {selectedStudentForQR.access_password || '123456'}
              </strong>
            </div>

            <button
              type="button"
              onClick={() => setSelectedStudentForQR(null)}
              className="w-full py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs transition"
            >
              Tamam
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
