'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Shield,
  Coins,
  PiggyBank,
  Flame,
  Sparkles,
  Camera,
  CheckCircle2,
  Clock,
  Gift,
  Zap,
  Users,
  Award,
  Compass,
  Heart,
  PlusCircle,
  Trophy,
  Palmtree,
  Monitor,
  QrCode,
  Swords,
  Scale,
  Radio,
  Tag,
  Plane,
} from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { TaskItem, UserMood, RewardTier } from '@/types/database';
import { getAgeAdaptivePersona } from '@/lib/ageThemeEngine';
import { WakeUpAlarmOverlay } from './WakeUpAlarmOverlay';
import { FocusLockOverlay } from './FocusLockOverlay';
import { PhotoProofModal } from './PhotoProofModal';
import { WalkieTalkieDM } from '@/components/shared/WalkieTalkieDM';
import { CompanionWidget } from './CompanionWidget';
import { GracePeriodModal } from './GracePeriodModal';
import { SmartBagChecklistCard } from './SmartBagChecklistCard';
import { HealthAndNoiseMonitor } from './HealthAndNoiseMonitor';
import { SuccessAlbumModal } from '@/components/shared/SuccessAlbumModal';
import {
  AppealModal,
  ShieldRestoredCelebrationModal,
} from './AppealModal';
import { ActiveBreakRoulette } from './ActiveBreakRoulette';
import { WeeklyInterviewModal } from './WeeklyInterviewModal';
import { useDesktopBridge } from '@/lib/useDesktopBridge';

const MOOD_OPTIONS: { id: UserMood; emoji: string; label: string }[] = [
  { id: 'happy', emoji: '😊', label: 'Mutlu' },
  { id: 'excited', emoji: '🤩', label: 'Enerjik' },
  { id: 'tired', emoji: '🥱', label: 'Yorgun' },
  { id: 'angry', emoji: '😤', label: 'Stresli' },
];

export const StudentDashboard: React.FC = () => {
  const {
    activeUser,
    users,
    familySettings,
    tasks,
    submissions,
    rewards,
    redemptions,
    violations,
    appeals,
    activeHappyHourDiscountPercent,
    lastRestoredShieldStudentId,
    clearRestoredShieldCelebration,
    remainingSecondsByUser,
    updateStudentMood,
    requestRewardRedemption,
    depositToPiggyBank,
    spinLuckyWheel,
    proposeTaskByStudent,
    transferPointsBetweenSiblings,
    setStudentState,
    submitAppeal,
    claimRaceTaskAtomic,
    completeActiveBreakChallenge,
    saveWeeklyInterview,
  } = useFamilyRealtime();

  const [selectedTaskForModal, setSelectedTaskForModal] =
    useState<TaskItem | null>(null);
  const [autoStartBrushModal, setAutoStartBrushModal] = useState(false);
  const [activeTab, setActiveTab] = useState<'quests' | 'market' | 'piggy_wheel'>(
    'quests'
  );
  const [selectedRewardTier, setSelectedRewardTier] =
    useState<RewardTier | 'all'>('all');
  const [piggyAmount, setPiggyAmount] = useState<number>(25);
  const [wheelSpinning, setWheelSpinning] = useState(false);
  const [wheelPrizeText, setWheelPrizeText] = useState<string | null>(null);
  const [feedbackToast, setFeedbackToast] = useState<string | null>(null);

  // Phase 2: Tersine Görev Teklifi & Kardeş Puan Hediyeleşmesi State
  const [showProposeTaskBox, setShowProposeTaskBox] = useState(false);
  const [proposalTitle, setProposalTitle] = useState('');
  const [proposalDesc, setProposalDesc] = useState('');
  const [proposalPoints, setProposalPoints] = useState(30);

  const [showGiftPointsBox, setShowGiftPointsBox] = useState(false);
  const [giftReceiverId, setGiftReceiverId] = useState('');
  const [giftAmount, setGiftAmount] = useState(15);
  const [giftMessage, setGiftMessage] = useState('Sana benden destek puanı! 💛');
  const [goldenHeartModal, setGoldenHeartModal] = useState(false);
  const [showSuccessAlbum, setShowSuccessAlbum] = useState(false);

  // Phase 4: Adalet Divanı (İtiraz) & Pazar Röportajı (Sesli Anı Kapsülü) Modalları
  const [showAppealModal, setShowAppealModal] = useState(false);
  const [showWeeklyInterviewModal, setShowWeeklyInterviewModal] =
    useState(false);

  // Phase 4 Module G: Windows Masaüstü Ajanı Pencere Boyutlandırma Köprüsü (`useDesktopBridge`)
  // Herhangi bir modal/drawer/market/mola ruleti açıldığında `document.title = "FAMILYOS_UI_EXPAND"` yapar,
  // kapandığında `document.title = "FAMILYOS_UI_COLLAPSE"` yapar.
  const isAnyExpandedViewOpen =
    Boolean(selectedTaskForModal) ||
    showProposeTaskBox ||
    showGiftPointsBox ||
    goldenHeartModal ||
    showSuccessAlbum ||
    showAppealModal ||
    showWeeklyInterviewModal ||
    activeTab === 'market' ||
    activeTab === 'piggy_wheel' ||
    activeUser.current_state === 'BREAK_TIME' ||
    lastRestoredShieldStudentId === activeUser.id;

  useDesktopBridge(isAnyExpandedViewOpen);

  const myViolations = violations.filter((v) => v.user_id === activeUser.id);
  const myRejectedSubmission =
    submissions.find(
      (s) => s.user_id === activeUser.id && s.status === 'rejected'
    ) || null;
  const myPendingAppeals = appeals.filter(
    (a) => a.user_id === activeUser.id && a.status === 'pending'
  );
  const isAutopilotActive = Boolean(
    familySettings.autopilot_until &&
      new Date(familySettings.autopilot_until).getTime() > Date.now()
  );

  const siblings = users.filter(
    (u) => u.role === 'child' && u.id !== activeUser.id
  );

  const remainingSeconds = remainingSecondsByUser[activeUser.id] || 0;
  const persona = getAgeAdaptivePersona(activeUser);
  const isJunior = persona.tier === 'junior';

  // 1. If Student is in WAKE_UP_ALARM state -> Show Fullscreen Age-Adaptive Smart Alarm (with Bathroom QR support)
  if (activeUser.current_state === 'WAKE_UP_ALARM') {
    return (
      <WakeUpAlarmOverlay
        student={activeUser}
        onAutoStartToothbrush={() => {
          const toothTask =
            tasks.find(
              (t) =>
                t.id.includes('tooth') ||
                t.title.toLowerCase().includes('diş')
            ) || tasks[0];
          if (toothTask) {
            setAutoStartBrushModal(true);
            setSelectedTaskForModal(toothTask);
          }
        }}
      />
    );
  }

  // 2. If Student is in STUDY_TIME or SLEEP_TIME -> Show Synchronized Age-Adaptive Focus Lock Shield
  if (
    activeUser.current_state === 'STUDY_TIME' ||
    activeUser.current_state === 'SLEEP_TIME'
  ) {
    return (
      <FocusLockOverlay
        student={activeUser}
        remainingSeconds={remainingSeconds}
      />
    );
  }

  // 3. Phase 2: If Student is in GUEST_MODE -> Hide private DM, task list, and violation warnings; show sleek Guest Free-Time Timer!
  if (activeUser.current_state === 'GUEST_MODE') {
    const gMins = Math.floor(remainingSeconds / 60);
    const gSecs = remainingSeconds % 60;
    return (
      <div className="min-h-[75vh] bg-gradient-to-br from-slate-900 via-indigo-950 to-cyan-950 border-2 border-cyan-400/50 rounded-3xl p-8 flex flex-col items-center justify-center text-center text-white shadow-2xl">
        <div className="px-4 py-1.5 rounded-full bg-cyan-400/20 border border-cyan-300/40 text-cyan-200 font-extrabold text-xs uppercase tracking-widest mb-4">
          🎮 MİSAFİR SERBEST ZAMAN MODU AKTİF
        </div>
        <div className="text-6xl mb-4">🕹️✨🍕</div>
        <h1 className="text-2xl sm:text-4xl font-black mb-2">
          Hoş Geldiniz! İyi Eğlenceler {activeUser.name} & Arkadaşları
        </h1>
        <p className="text-sm text-slate-300 max-w-md mb-8">
          Misafir modu süresince kişisel görev listeleri, aile içi mesajlar ve
          odaklanma sensörleri gizlenmiştir.
        </p>
        <div className="bg-slate-950/80 border-2 border-cyan-400/50 rounded-3xl px-10 py-6 shadow-2xl">
          <div className="text-xs font-bold text-cyan-300 uppercase tracking-widest mb-1">
            MİSAFİR SERBEST ZAMAN SAYACI
          </div>
          <div className="text-5xl sm:text-6xl font-black font-mono text-white">
            {remainingSeconds > 0
              ? `${String(gMins).padStart(2, '0')}:${String(gSecs).padStart(2, '0')}`
              : 'SÜRESİZ AÇIK'}
          </div>
        </div>
      </div>
    );
  }

  // Filter tasks assigned to this student or 'both' (Co-op) - only approved proposals are active quests
  const myTasks = tasks.filter(
    (t) =>
      t.is_active &&
      (t.proposal_status === undefined || t.proposal_status === 'approved') &&
      (t.assigned_to === activeUser.id || t.assigned_to === 'both')
  );

  const myPendingProposals = tasks.filter(
    (t) =>
      t.created_by === activeUser.id &&
      t.proposal_status === 'pending_parent_approval'
  );

  const morningRoutineTasks = myTasks.filter(
    (t) => t.category === 'routine_morning'
  );
  const completedMorningCount = morningRoutineTasks.filter((t) =>
    submissions.some(
      (s) =>
        s.task_id === t.id &&
        s.user_id === activeUser.id &&
        s.status === 'approved'
    )
  ).length;

  const getTaskStatus = (taskId: string) => {
    const sub = submissions.find(
      (s) => s.task_id === taskId && s.user_id === activeUser.id
    );
    return sub?.status || null;
  };

  const handleBuyReward = async (rewardId: string) => {
    const res = await requestRewardRedemption(rewardId, activeUser.id);
    setFeedbackToast(res.message);
    setTimeout(() => setFeedbackToast(null), 4000);
  };

  const handleDepositPiggy = async () => {
    if (activeUser.points_balance < piggyAmount) return;
    await depositToPiggyBank(activeUser.id, piggyAmount);
    confetti({ particleCount: 50, spread: 60 });
    setFeedbackToast(
      `🐷 ${piggyAmount} ${persona.pointsLabel} aktarıldı! Pazar gecesi +%20 bonus kazanacaksın!`
    );
    setTimeout(() => setFeedbackToast(null), 4000);
  };

  const handleSpinWheel = async () => {
    if (wheelSpinning) return;
    setWheelSpinning(true);
    setWheelPrizeText(null);

    setTimeout(async () => {
      const prize = await spinLuckyWheel(activeUser.id);
      setWheelSpinning(false);
      setWheelPrizeText(prize.label);
      confetti({ particleCount: 120, spread: 90, origin: { y: 0.6 } });
    }, 1600);
  };

  const mins = Math.floor(remainingSeconds / 60);
  const secs = remainingSeconds % 60;

  // Senior Level Progress Bar Math
  const totalXp = activeUser.points_balance + activeUser.piggy_bank_balance;
  const levelProgressPct = Math.min(100, (totalXp % 50) * 2);

  // Family Chest Progress Math
  const chestPct = Math.min(
    100,
    Math.round(
      (familySettings.family_chest_current /
        Math.max(1, familySettings.family_chest_goal)) *
        100
    )
  );

  const handleProposeTaskSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!proposalTitle.trim()) return;
    await proposeTaskByStudent({
      studentId: activeUser.id,
      title: proposalTitle,
      description: proposalDesc,
      requestedPoints: proposalPoints,
    });
    setProposalTitle('');
    setProposalDesc('');
    setShowProposeTaskBox(false);
    setFeedbackToast(
      '💡 Görev önerin Anne ve Babana gönderildi! Onaylandığında listene düşecek.'
    );
    setTimeout(() => setFeedbackToast(null), 4000);
  };

  const handleGiftPointsSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const targetSiblingId = giftReceiverId || siblings[0]?.id;
    if (!targetSiblingId) return;
    const res = await transferPointsBetweenSiblings(
      activeUser.id,
      targetSiblingId,
      giftAmount,
      giftMessage
    );
    setFeedbackToast(res.message);
    setTimeout(() => setFeedbackToast(null), 4500);
    if (res.success) {
      setShowGiftPointsBox(false);
      confetti({
        particleCount: 140,
        spread: 95,
        origin: { y: 0.55 },
      });
      if (res.awardedGoldenHeart) {
        setGoldenHeartModal(true);
      }
    }
  };

  return (
    <div className="space-y-6">
      {/* Phase 3: Kriz Önleyici +3 Dakika Uzatma (Grace Period) & İrade Eğitimi Modalı */}
      <GracePeriodModal
        student={activeUser}
        remainingSeconds={remainingSeconds}
      />

      {/* Phase 3: 20-20-20 Göz & Duruş Kalkanı, Su Molası ve Yüksek Gürültü / Bağırma Sensörü */}
      <HealthAndNoiseMonitor student={activeUser} />

      {/* Phase 3: Aile Başarı Albümü & Film Gecesi Slayt Gösterisi Modalı */}
      <SuccessAlbumModal
        isOpen={showSuccessAlbum}
        onClose={() => setShowSuccessAlbum(false)}
      />

      {/* Phase 4: Adalet Divanı / Hakem Heyetine İtiraz Modalı */}
      <AppealModal
        isOpen={showAppealModal}
        onClose={() => setShowAppealModal(false)}
        studentId={activeUser.id}
        studentName={activeUser.name}
        appealUsedToday={activeUser.appeal_used_today}
        latestViolation={myViolations[0] || null}
        rejectedSubmission={myRejectedSubmission}
        onSubmitAppeal={submitAppeal}
      />

      {/* Phase 4: Kalkan Tamir Edildi Parlama Kutlama Ekranı */}
      <ShieldRestoredCelebrationModal
        isVisible={lastRestoredShieldStudentId === activeUser.id}
        studentName={activeUser.name}
        onDismiss={clearRestoredShieldCelebration}
      />

      {/* Phase 4: Pazar Röportajı & Sesli Anı Kapsülü Modalı */}
      <WeeklyInterviewModal
        isOpen={showWeeklyInterviewModal}
        onClose={() => setShowWeeklyInterviewModal(false)}
        studentId={activeUser.id}
        studentName={activeUser.name}
        onSaveInterview={saveWeeklyInterview}
      />

      {/* Altın Kalp Rozeti Kutlama Modalı */}
      {goldenHeartModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4">
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-gradient-to-br from-amber-950 via-slate-900 to-pink-950 border-2 border-amber-400 rounded-3xl max-w-md w-full p-6 text-center text-white shadow-2xl space-y-4"
          >
            <div className="text-6xl animate-bounce">💛🏅✨</div>
            <h2 className="text-2xl font-black text-amber-300">
              💛 Altın Kalp Rozeti Kazandın!
            </h2>
            <p className="text-sm text-slate-200">
              Kendi kazandığın puanları kardeşinle paylaşarak muhteşem bir
              kardeş dayanışması gösterdin! Bu özel rozet profiline kalıcı
              olarak eklendi.
            </p>
            <button
              type="button"
              onClick={() => setGoldenHeartModal(false)}
              className="w-full py-3 rounded-2xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-black text-sm shadow-xl"
            >
              Harika! Teşekkürler 🎉
            </button>
          </motion.div>
        </div>
      )}

      {/* C. ORTAK AİLE HAZİNE SANDIĞI (FAMILY CO-OP PROGRESS BAR) */}
      <div className="bg-gradient-to-r from-amber-950/90 via-indigo-950 to-purple-950 border-2 border-amber-400/50 rounded-3xl p-4 sm:p-5 shadow-xl">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-2">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-2xl bg-amber-400/20 border border-amber-300/40 flex items-center justify-center text-2xl shrink-0">
              🧰
            </div>
            <div>
              <div className="text-[11px] font-black uppercase tracking-wider text-amber-300 flex items-center gap-1">
                <Trophy className="w-3.5 h-3.5" />
                <span>ORTAK AİLE HAZİNE SANDIĞI (TÜM KARDEŞLERİN PUANLARIYLA DOLAR!)</span>
              </div>
              <div className="text-sm sm:text-base font-black text-white">
                Hedef Ödül: {familySettings.family_chest_reward_title}
              </div>
            </div>
          </div>
          <div className="text-right shrink-0">
            <span className="px-3 py-1 rounded-xl bg-slate-950/80 border border-amber-400/40 text-amber-300 font-mono font-black text-xs sm:text-sm">
              {familySettings.family_chest_current} / {familySettings.family_chest_goal} Puan (%{chestPct})
            </span>
          </div>
        </div>
        <div className="w-full h-3.5 rounded-full bg-slate-950/90 overflow-hidden border border-amber-400/30 p-0.5">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${chestPct}%` }}
            transition={{ duration: 0.8, ease: 'easeOut' }}
            className="h-full rounded-full bg-gradient-to-r from-amber-400 via-yellow-300 to-emerald-400 shadow-lg"
          />
        </div>
      </div>

      {/* E. TATİL MODU (FROZEN_HOLIDAY) VEYA BİLGİSAYARLI DERS (COMPUTER_STUDY) DURUM KARTI */}
      {activeUser.current_state === 'FROZEN_HOLIDAY' && (
        <div className="bg-gradient-to-r from-cyan-900/90 via-teal-900/90 to-emerald-900/90 border-2 border-cyan-300/60 rounded-3xl p-5 flex items-center gap-4 text-white shadow-xl">
          <Palmtree className="w-10 h-10 text-yellow-300 shrink-0 animate-bounce" />
          <div>
            <h3 className="text-lg font-black text-cyan-200">
              🏖️ Tatil Modu Aktif - Serilerin ve Kalkanların Koruma Altında!
            </h3>
            <p className="text-xs sm:text-sm text-slate-200">
              Tüm sabah alarmları ve odaklanma ihlal sensörleri tatil süresince
              donduruldu. İyi tatiller!
            </p>
          </div>
        </div>
      )}

      {activeUser.current_state === 'COMPUTER_STUDY' && (
        <div className="bg-gradient-to-r from-indigo-950 via-blue-950 to-slate-900 border-2 border-indigo-400/60 rounded-3xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-white shadow-xl">
          <div className="flex items-center gap-3">
            <Monitor className="w-8 h-8 text-indigo-300 shrink-0" />
            <div>
              <h3 className="text-sm sm:text-base font-black text-indigo-200">
                💻 Bilgisayarlı Ders & Araştırma Modu Aktif
              </h3>
              <p className="text-xs text-slate-300">
                İzinli Uygulamalar:{' '}
                <strong className="text-emerald-300">
                  {(
                    activeUser.whitelist_config?.allowed_exes || [
                      'chrome.exe',
                      'winword.exe',
                    ]
                  ).join(', ')}
                </strong>{' '}
                • İzinli Kelimeler:{' '}
                <strong className="text-amber-300">
                  {(
                    activeUser.whitelist_config?.allowed_keywords || [
                      'eba',
                      'ders',
                      'ödev',
                    ]
                  ).join(', ')}
                </strong>
              </p>
            </div>
          </div>
          {remainingSeconds > 0 && (
            <span className="px-3 py-1.5 rounded-xl bg-indigo-600 font-mono font-black text-xs shrink-0">
              ⏱️ {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
            </span>
          )}
        </div>
      )}

      {/* Faz 5: Arkadaşla Ders Modu (CO_STUDY_MODE) Durum Kartı */}
      {activeUser.current_state === 'CO_STUDY_MODE' && (
        <div className="bg-gradient-to-r from-violet-950 via-purple-950 to-indigo-900 border-2 border-purple-400/60 rounded-3xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-white shadow-xl">
          <div className="flex items-center gap-3">
            <span className="text-3xl shrink-0">👥</span>
            <div>
              <h3 className="text-sm sm:text-base font-black text-purple-200">
                👥 Arkadaşla Birlikte Ders Modu (Co-Study) Aktif
              </h3>
              <p className="text-xs text-slate-300">
                İki kişilik çalışma kalkanı devrede: Soruları birlikte tartışıp ekrana dokunabilirsiniz; gürültü ve girdi ihlal sensörleri esnetildi!
              </p>
            </div>
          </div>
          {remainingSeconds > 0 && (
            <span className="px-3 py-1.5 rounded-xl bg-purple-600 font-mono font-black text-xs shrink-0">
              ⏱️ {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
            </span>
          )}
        </div>
      )}
      {/* Feedback Toast */}
      {feedbackToast && (
        <motion.div
          initial={{ opacity: 0, y: -15 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-emerald-500 text-slate-950 font-black px-5 py-3 rounded-2xl shadow-xl text-sm flex items-center justify-between"
        >
          <span>{feedbackToast}</span>
          <button
            type="button"
            onClick={() => setFeedbackToast(null)}
            className="text-xs underline ml-4"
          >
            Kapat
          </button>
        </motion.div>
      )}

      {/* Age-Adaptive Hero Student Header Card */}
      <div
        className={`${persona.cardBorderRadius} p-5 sm:p-7 border-2 shadow-2xl relative overflow-hidden ${persona.heroGradient}`}
      >
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-5 relative z-10">
          {/* Avatar, Name, Age/Grade Persona Badge & State */}
          <div className="flex items-center gap-4">
            <div
              className={`${
                isJunior ? 'w-20 h-20 sm:w-24 sm:h-24 text-5xl rounded-3xl' : 'w-16 h-16 sm:w-20 sm:h-20 text-4xl rounded-2xl'
              } bg-gradient-to-br ${activeUser.avatar_config.bg} flex items-center justify-center shadow-xl border-2 border-white/40 shrink-0`}
            >
              {activeUser.avatar_config.emoji}
            </div>
            <div>
              <div className="flex flex-wrap items-center gap-2 mb-1">
                <span className="px-3 py-0.5 rounded-full bg-slate-950/50 border border-white/20 text-white text-xs font-extrabold flex items-center gap-1.5">
                  <Compass className="w-3.5 h-3.5 text-amber-300" />
                  {persona.badgeTitle}
                </span>
                <span
                  className={`px-3 py-0.5 rounded-full text-xs font-extrabold ${
                    activeUser.current_state === 'BREAK_TIME'
                      ? 'bg-emerald-400 text-slate-950 animate-pulse'
                      : activeUser.current_state === 'ROUTINE_TIME'
                      ? 'bg-cyan-400 text-slate-950'
                      : 'bg-slate-950/60 text-indigo-200 border border-white/20'
                  }`}
                >
                  {activeUser.current_state === 'FREE_TIME' &&
                    (isJunior ? '🟢 Serbest Oyun & Dinlenme' : '🟢 Free Mode (Serbest)')}
                  {activeUser.current_state === 'BREAK_TIME' && '🔔 Mola / Teneffüs Zamanı'}
                  {activeUser.current_state === 'ROUTINE_TIME' && '🪥 Günlük Rutin Zamanı'}
                </span>
                {remainingSeconds > 0 && (
                  <span className="px-3 py-0.5 rounded-full bg-amber-400 text-slate-950 font-mono font-black text-xs flex items-center gap-1">
                    <Clock className="w-3.5 h-3.5" />
                    {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
                  </span>
                )}
              </div>

              <h1
                className={`${
                  isJunior ? 'text-2xl sm:text-4xl' : 'text-xl sm:text-3xl'
                } font-black text-white`}
              >
                {isJunior
                  ? `Merhaba ${activeUser.name}! 🌈`
                  : `Hoş Geldin, ${activeUser.name} ⚡`}
              </h1>
              <p className="text-xs sm:text-sm text-white/85 mt-0.5">
                {persona.welcomeSubtitle}
              </p>

              {/* Earned Badges Display (Altın Kalp Rozeti vb.) */}
              {Array.isArray(activeUser.badges) && activeUser.badges.length > 0 && (
                <div className="flex flex-wrap items-center gap-1.5 mt-2">
                  {activeUser.badges.map((badge, idx) => (
                    <span
                      key={idx}
                      className="px-2.5 py-0.5 rounded-full bg-amber-400 text-slate-950 font-black text-[11px] shadow-md flex items-center gap-1"
                    >
                      <Award className="w-3.5 h-3.5" />
                      <span>{badge}</span>
                    </span>
                  ))}
                </div>
              )}

              {/* Senior Level XP Bar (Only for 11-15 age group / 5-8. Sınıf) */}
              {!isJunior && (
                <div className="mt-2.5 max-w-md">
                  <div className="flex justify-between text-[11px] font-bold text-fuchsia-200 mb-1">
                    <span>Seviye İlerlemesi (Sonraki Rütbeye %{100 - levelProgressPct} kaldı)</span>
                    <span>Toplam: {totalXp} XP</span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-slate-950/70 overflow-hidden border border-fuchsia-400/30">
                    <div
                      style={{ width: `${levelProgressPct}%` }}
                      className="h-full bg-gradient-to-r from-fuchsia-500 to-cyan-400 transition-all duration-500"
                    />
                  </div>
                </div>
              )}

              {/* Mood Picker */}
              <div className="flex flex-wrap items-center gap-1.5 mt-3">
                <span className="text-xs text-white/80 mr-1 font-semibold">
                  {isJunior ? 'Bugün nasıl hissediyorsun?' : 'Durum / Mood:'}
                </span>
                {MOOD_OPTIONS.map((m) => (
                  <button
                    key={m.id}
                    type="button"
                    onClick={() => updateStudentMood(activeUser.id, m.id)}
                    className={`px-2.5 py-1 rounded-xl text-xs font-bold transition flex items-center gap-1 ${
                      activeUser.current_mood === m.id
                        ? 'bg-white text-slate-950 shadow-md scale-105'
                        : 'bg-slate-950/50 text-slate-200 hover:bg-slate-900'
                    }`}
                  >
                    <span className={isJunior ? 'text-base' : 'text-sm'}>{m.emoji}</span>
                    <span className="hidden sm:inline">{m.label}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Gamification Economy Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
            {/* Points / XP Balance */}
            <div className="bg-slate-950/75 border border-amber-400/40 rounded-2xl p-3 text-center">
              <div className="flex items-center justify-center gap-1 text-amber-400 text-[11px] font-extrabold mb-0.5">
                <Coins className="w-4 h-4" /> {persona.pointsLabel}
              </div>
              <div className="text-2xl font-black text-white">
                {activeUser.points_balance}
              </div>
              <div className="text-[10px] text-amber-300">{persona.pointsSubtext}</div>
            </div>

            {/* Piggy Bank / Investment Vault */}
            <div className="bg-slate-950/75 border border-pink-400/40 rounded-2xl p-3 text-center">
              <div className="flex items-center justify-center gap-1 text-pink-400 text-[11px] font-extrabold mb-0.5">
                <PiggyBank className="w-4 h-4" /> {persona.piggyLabel}
              </div>
              <div className="text-2xl font-black text-white">
                {activeUser.piggy_bank_balance}
              </div>
              <div className="text-[10px] text-pink-300">Pazar +%20 Bonus</div>
            </div>

            {/* Daily Shields */}
            <div className="bg-slate-950/75 border border-emerald-400/40 rounded-2xl p-3 text-center">
              <div className="flex items-center justify-center gap-1 text-emerald-400 text-[11px] font-extrabold mb-0.5">
                <Shield className="w-4 h-4" /> {persona.shieldLabel}
              </div>
              <div className="flex items-center justify-center gap-1 my-1">
                {[1, 2, 3].map((i) => (
                  <Shield
                    key={i}
                    className={`w-5 h-5 ${
                      i <= activeUser.daily_shields
                        ? 'text-emerald-400 fill-emerald-400'
                        : 'text-slate-700'
                    }`}
                  />
                ))}
              </div>
              <div className="text-[10px] text-emerald-300">{persona.shieldSubtext}</div>
            </div>

            {/* 5-Day Streak */}
            <div className="bg-slate-950/75 border border-orange-400/40 rounded-2xl p-3 text-center">
              <div className="flex items-center justify-center gap-1 text-orange-400 text-[11px] font-extrabold mb-0.5">
                <Flame className="w-4 h-4" /> {isJunior ? 'GÜNLÜK SERİ' : 'STREAK'}
              </div>
              <div className="text-2xl font-black text-white">
                {activeUser.streak_days} Gün
              </div>
              <div className="text-[10px] text-orange-300">
                {activeUser.wheel_spins_available > 0
                  ? '🎡 Çark Hazır!'
                  : '5 Günde Çark Açılır'}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Age-Adaptive Navigation Tabs */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-5">
        {/* Phase 3: Evrimleşen Dijital Yoldaş (Virtual Companion) + Canlı Hava Durumu Kıyafeti */}
        <CompanionWidget
          student={activeUser}
          isBrushingTeeth={Boolean(
            selectedTaskForModal && autoStartBrushModal
          )}
        />

        {/* Phase 3: Okul Ders Programı & Akıllı Çanta Hazırlama Kontrol Listesi */}
        <SmartBagChecklistCard student={activeUser} />
      </div>

      {/* Phase 4: Ebeveyn Otonom Pilot (Güven Ön-Onay) Modu Aktifse Bilgi Rozeti */}
      {isAutopilotActive && (
        <div className="bg-gradient-to-r from-cyan-950/90 via-indigo-950/90 to-slate-900 border-2 border-cyan-400/50 rounded-3xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-white shadow-xl">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-cyan-400/20 border border-cyan-300/40 flex items-center justify-center text-cyan-300 shrink-0">
              <Plane className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xs font-black uppercase tracking-wider text-cyan-300">
                ✈️ EBEVEYN OTONOM PİLOT (GÜVEN MODU) AKTİF
              </div>
              <p className="text-xs text-slate-200">
                🤝 Anne/Baban şu an meşgul ama sana güveniyoruz! Tamamladığın
                görevler bekletilmeden anında ön-onay alır ve puanın hemen
                hesabına yüklenir!
              </p>
            </div>
          </div>
          <span className="px-3 py-1 rounded-xl bg-cyan-500/20 border border-cyan-400/40 text-cyan-200 font-bold text-xs shrink-0">
            Bitiş:{' '}
            {new Date(familySettings.autopilot_until!).toLocaleTimeString(
              'tr-TR',
              { hour: '2-digit', minute: '2-digit' }
            )}
          </span>
        </div>
      )}

      {/* Phase 4: Bilişsel Yorgunluk Sıfırlayıcı: Aktif Mola Enerji Çarkı */}
      <ActiveBreakRoulette
        studentId={activeUser.id}
        studentName={activeUser.name}
        isBreakTime={activeUser.current_state === 'BREAK_TIME'}
        onCompleteChallenge={completeActiveBreakChallenge}
      />

      {/* Phase 3 & Phase 4 Quick Action Bar: Aile Başarı Albümü, Pazar Röportajı, Adalet Divanı & +3 Dk Uzatma */}
      <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900/90 border border-indigo-500/30 rounded-2xl px-4 py-3">
        <div className="flex items-center gap-2 text-xs text-slate-300 font-bold">
          <Sparkles className="w-4 h-4 text-amber-400" />
          <span>
            Aile Anıları, Adalet Divanı, Sesli Zaman Kapsülü ve Süre Jokerleri:
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => setShowSuccessAlbum(true)}
            className="px-3.5 py-2 rounded-xl bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-slate-950 font-black text-xs flex items-center gap-1.5 shadow-lg transition"
          >
            <Trophy className="w-4 h-4" />
            <span>🏆 Aile Başarı Albümü & 🎬 Film Gecesi Slaytı</span>
          </button>

          <button
            type="button"
            onClick={() => setShowWeeklyInterviewModal(true)}
            className="px-3.5 py-2 rounded-xl bg-gradient-to-r from-fuchsia-500 to-rose-500 hover:from-fuchsia-400 hover:to-rose-400 text-white font-black text-xs flex items-center gap-1.5 shadow-lg transition"
          >
            <Radio className="w-4 h-4" />
            <span>🎙️ Haftanın Röportajı (Zaman Kapsülü)</span>
          </button>

          <button
            type="button"
            onClick={() => setShowAppealModal(true)}
            disabled={Boolean(activeUser.appeal_used_today)}
            className={`px-3.5 py-2 rounded-xl font-black text-xs flex items-center gap-1.5 border transition ${
              activeUser.appeal_used_today
                ? 'bg-slate-800/80 border-slate-700 text-slate-400 cursor-not-allowed'
                : 'bg-amber-500/20 hover:bg-amber-500/30 border-amber-400/50 text-amber-200 shadow-lg'
            }`}
          >
            <Scale className="w-4 h-4" />
            <span>
              {myPendingAppeals.length > 0
                ? '⚖️ İtirazın İnceleniyor...'
                : activeUser.appeal_used_today
                ? '⚖️ Günlük İtiraz Hakkı Kullanıldı'
                : '⚖️ Hakem Heyetine İtiraz Et (Günde 1 Hak)'}
            </span>
          </button>

          {activeUser.current_state === 'FREE_TIME' && (
            <button
              type="button"
              onClick={() => setStudentState(activeUser.id, 'FREE_TIME', 0.45)}
              title="Serbest zamanın bitmesine 27 saniye kalmış gibi simüle ederek +3 Dakika Uzatma Jokerini test eder"
              className="px-3 py-2 rounded-xl bg-indigo-500/20 hover:bg-indigo-500/35 border border-indigo-400/40 text-indigo-200 font-bold text-xs flex items-center gap-1.5 transition"
            >
              <Clock className="w-3.5 h-3.5" />
              <span>⏱️ Son 25 Sn (+3 Dk Uzatma Jokeri) Test Et</span>
            </button>
          )}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2 bg-slate-900/90 p-1.5 rounded-2xl border border-slate-800">
        <button
          type="button"
          onClick={() => setActiveTab('quests')}
          className={`flex-1 py-3 px-4 rounded-xl font-extrabold ${
            isJunior ? 'text-sm sm:text-base' : 'text-xs sm:text-sm'
          } flex items-center justify-center gap-2 transition ${
            activeTab === 'quests'
              ? isJunior
                ? 'bg-gradient-to-r from-amber-400 to-orange-500 text-slate-950 shadow-lg'
                : 'bg-fuchsia-600 text-white shadow-lg'
              : 'text-slate-400 hover:text-white'
          }`}
        >
          <Sparkles className="w-4 h-4" />
          <span>
            {persona.questsTabTitle} ({myTasks.length})
          </span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('market')}
          className={`flex-1 py-3 px-4 rounded-xl font-extrabold ${
            isJunior ? 'text-sm sm:text-base' : 'text-xs sm:text-sm'
          } flex items-center justify-center gap-2 transition ${
            activeTab === 'market'
              ? 'bg-amber-500 text-slate-950 shadow-lg'
              : 'text-slate-400 hover:text-white'
          }`}
        >
          <Gift className="w-4 h-4" />
          <span>{persona.marketTabTitle}</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('piggy_wheel')}
          className={`flex-1 py-3 px-4 rounded-xl font-extrabold ${
            isJunior ? 'text-sm sm:text-base' : 'text-xs sm:text-sm'
          } flex items-center justify-center gap-2 transition ${
            activeTab === 'piggy_wheel'
              ? 'bg-pink-600 text-white shadow-lg'
              : 'text-slate-400 hover:text-white'
          }`}
        >
          <PiggyBank className="w-4 h-4" />
          <span>{persona.piggyWheelTabTitle}</span>
        </button>
      </div>

      {/* Main Content Area + Walkie-Talkie Sidebar */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        <div className="lg:col-span-8 space-y-5">
          {/* TAB 1: QUESTS, ROUTINES & PHOTO PROOFS */}
          {activeTab === 'quests' && (
            <>
              {/* Morning Routine Combo Progress Bar */}
              <div className="bg-gradient-to-r from-amber-500/15 via-orange-500/15 to-yellow-500/15 border border-amber-400/40 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <div className="text-xs font-extrabold text-amber-300 uppercase tracking-wider flex items-center gap-1.5">
                    <Award className="w-4 h-4" />
                    {persona.comboBannerTitle}
                  </div>
                  <p className="text-xs text-slate-300 mt-0.5">
                    {persona.comboBannerDesc}
                  </p>
                </div>
                <div className="flex items-center gap-3 shrink-0">
                  <div className="text-sm font-black text-amber-300 bg-slate-950/60 px-3 py-1.5 rounded-xl border border-amber-400/30">
                    {completedMorningCount} / {morningRoutineTasks.length} Tamamlandı
                  </div>
                </div>
              </div>

              {/* D. TERSİNE GÖREV TEKLİFİ & KARDEŞ PUAN HEDİYELEŞMESİ BUTONLARI */}
              <div className="bg-slate-900/90 border border-indigo-500/30 rounded-2xl p-3.5 space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-xs font-extrabold text-indigo-300 flex items-center gap-1.5">
                    <Sparkles className="w-4 h-4 text-amber-400" />
                    <span>Ekstra İnisiyatif & Kardeş Dayanışması:</span>
                  </span>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        setShowProposeTaskBox((v) => !v);
                        setShowGiftPointsBox(false);
                      }}
                      className="px-3.5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-black text-xs flex items-center gap-1.5 shadow-lg transition"
                    >
                      <PlusCircle className="w-4 h-4" />
                      <span>➕ Anne/Babama Görev Öner</span>
                    </button>

                    {siblings.length > 0 && (
                      <button
                        type="button"
                        onClick={() => {
                          setShowGiftPointsBox((v) => !v);
                          setShowProposeTaskBox(false);
                        }}
                        className="px-3.5 py-2 rounded-xl bg-gradient-to-r from-amber-400 to-pink-500 hover:from-amber-300 hover:to-pink-400 text-slate-950 font-black text-xs flex items-center gap-1.5 shadow-lg transition"
                      >
                        <Heart className="w-4 h-4 fill-current" />
                        <span>💛 Kardeşime Puan Gönder</span>
                      </button>
                    )}
                  </div>
                </div>

                {/* 1. Görev Teklif Et Formu */}
                {showProposeTaskBox && (
                  <form
                    onSubmit={handleProposeTaskSubmit}
                    className="bg-slate-950/90 border border-indigo-400/40 rounded-2xl p-4 space-y-3"
                  >
                    <div className="text-xs font-black text-indigo-300 uppercase">
                      ➕ Anne ve Babana Yeni Bir Görev Teklif Et
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                      <input
                        type="text"
                        required
                        value={proposalTitle}
                        onChange={(e) => setProposalTitle(e.target.value)}
                        placeholder="Örn: Balkon Çiçeklerini Sulama & Kitaplık Tozunu Alma"
                        className="sm:col-span-2 bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                      />
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs text-slate-400 shrink-0">Puan:</span>
                        <input
                          type="number"
                          min={5}
                          max={200}
                          value={proposalPoints}
                          onChange={(e) => setProposalPoints(Number(e.target.value))}
                          className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-amber-300 font-bold"
                        />
                      </div>
                    </div>
                    <div className="flex flex-col sm:flex-row gap-2">
                      <input
                        type="text"
                        value={proposalDesc}
                        onChange={(e) => setProposalDesc(e.target.value)}
                        placeholder="Nasıl yapacağını kısaca yaz (İsteğe bağlı)"
                        className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                      />
                      <button
                        type="submit"
                        className="px-5 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs shrink-0"
                      >
                        Onaya Gönder 🚀
                      </button>
                    </div>
                  </form>
                )}

                {/* 2. Kardeşime Puan Gönder Formu */}
                {showGiftPointsBox && siblings.length > 0 && (
                  <form
                    onSubmit={handleGiftPointsSubmit}
                    className="bg-slate-950/90 border border-amber-400/40 rounded-2xl p-4 space-y-3"
                  >
                    <div className="text-xs font-black text-amber-300 uppercase flex items-center justify-between">
                      <span>💛 Kardeşine Puan Hediye Et (İlk Transferde Altın Kalp Rozeti!)</span>
                      <span className="text-slate-400">
                        Bakiyen: {activeUser.points_balance} P
                      </span>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                      <select
                        value={giftReceiverId || siblings[0]?.id}
                        onChange={(e) => setGiftReceiverId(e.target.value)}
                        className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                      >
                        {siblings.map((sib) => (
                          <option key={sib.id} value={sib.id}>
                            {sib.avatar_config.emoji} {sib.name} ({sib.points_balance} P)
                          </option>
                        ))}
                      </select>
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs text-slate-400 shrink-0">Miktar:</span>
                        <input
                          type="number"
                          min={5}
                          max={activeUser.points_balance}
                          value={giftAmount}
                          onChange={(e) => setGiftAmount(Number(e.target.value))}
                          className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-amber-300 font-bold"
                        />
                      </div>
                      <input
                        type="text"
                        value={giftMessage}
                        onChange={(e) => setGiftMessage(e.target.value)}
                        placeholder="Mesajın (Örn: İstediğin ödülü alman için hediyem!)"
                        className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                      />
                    </div>
                    <div className="flex justify-end">
                      <button
                        type="submit"
                        disabled={activeUser.points_balance < giftAmount || giftAmount <= 0}
                        className="px-5 py-2 rounded-xl bg-amber-400 hover:bg-amber-300 disabled:opacity-40 text-slate-950 font-black text-xs"
                      >
                        💛 Hediye Puanı Gönder
                      </button>
                    </div>
                  </form>
                )}

                {/* Bekleyen Görev Teklifleri */}
                {myPendingProposals.length > 0 && (
                  <div className="flex flex-wrap items-center gap-2 pt-1">
                    {myPendingProposals.map((prop) => (
                      <span
                        key={prop.id}
                        className="px-3 py-1 rounded-xl bg-indigo-500/15 border border-indigo-400/30 text-indigo-200 text-xs font-semibold"
                      >
                        ⏳ Teklifin Ebeveyn Onayında: <strong>{prop.title}</strong> (+{prop.points} P)
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {/* Tasks List */}
              <div className="space-y-3.5">
                {myTasks.map((task) => {
                  const status = getTaskStatus(task.id);
                  const isFlash = task.category === 'flash_quest';
                  const isRace = Boolean(task.is_first_come_race);
                  const isCoop = task.category === 'coop' || task.assigned_to === 'both';
                  const claimedByUser = task.claimed_by
                    ? users.find((u) => u.id === task.claimed_by)
                    : null;
                  const isClaimedBySibling = Boolean(
                    task.claimed_by && task.claimed_by !== activeUser.id
                  );

                  return (
                    <motion.div
                      key={task.id}
                      layout
                      className={`${persona.cardBorderRadius} p-4 sm:p-5 border transition ${
                        isRace
                          ? 'bg-gradient-to-r from-rose-950/90 via-amber-950/85 to-indigo-950 border-2 border-amber-400 shadow-xl shadow-amber-500/15'
                          : isFlash
                          ? 'bg-gradient-to-r from-amber-950/90 to-orange-950/80 border-amber-400 shadow-lg shadow-amber-500/10'
                          : status === 'approved'
                          ? 'bg-slate-900/40 border-emerald-500/30 opacity-75'
                          : 'bg-slate-900/90 border-slate-800 hover:border-indigo-500/50'
                      }`}
                    >
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div className="space-y-1">
                          <div className="flex flex-wrap items-center gap-2">
                            {isRace && (
                              <span className="px-2.5 py-0.5 rounded-full bg-gradient-to-r from-rose-500 to-amber-400 text-slate-950 font-black text-[11px] flex items-center gap-1 animate-pulse">
                                🏃‍♂️ İLK KAPAR YARIŞ GÖREVİ (TEK KİŞİLİK)
                              </span>
                            )}
                            {isFlash && !isRace && (
                              <span className="px-2.5 py-0.5 rounded-full bg-amber-400 text-slate-950 font-black text-[11px] flex items-center gap-1 animate-pulse">
                                <Zap className="w-3 h-3 fill-current" /> SÜRPRİZ ALTIN GÖREV
                              </span>
                            )}
                            {isCoop && !isRace && (
                              <span className="px-2.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 border border-purple-400/30 font-bold text-[11px] flex items-center gap-1">
                                <Users className="w-3 h-3" />{' '}
                                {isJunior ? 'Kardeş Takımı Görevi' : 'Co-op Sinerji Görevi'}
                              </span>
                            )}
                            {task.category === 'academic' && (
                              <span className="px-2.5 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 font-bold text-[11px]">
                                {persona.photoProofBadge}
                              </span>
                            )}
                            <span className="text-xs text-slate-400 flex items-center gap-1">
                              <Clock className="w-3 h-3" /> {task.due_time}
                            </span>
                          </div>

                          <h3 className={`${persona.titleFontSize} font-extrabold text-white`}>
                            {task.title}
                          </h3>
                          <p className="text-xs sm:text-sm text-slate-300">
                            {task.description}
                          </p>
                          {isRace && claimedByUser && (
                            <div className="pt-1">
                              <span
                                className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg text-xs font-black ${
                                  claimedByUser.id === activeUser.id
                                    ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-400/40'
                                    : 'bg-rose-500/20 text-rose-300 border border-rose-400/40'
                                }`}
                              >
                                {claimedByUser.id === activeUser.id
                                  ? '⚡ Bu yarış görevini SEN KAPTIN! 15 dk içinde bitir!'
                                  : `🔒 Bu görevi ${claimedByUser.name} kaptı!`}
                              </span>
                            </div>
                          )}
                        </div>

                        <div className="flex sm:flex-col items-center sm:items-end justify-between gap-2 shrink-0">
                          <div className="px-3.5 py-1 rounded-xl bg-amber-400/15 border border-amber-400/30 text-amber-300 font-black text-sm">
                            +{task.points} {isJunior ? 'Yıldız ⭐' : 'XP 💎'}
                          </div>

                          {status === 'approved' ? (
                            <span className="px-3.5 py-2 rounded-xl bg-emerald-500/20 text-emerald-300 font-bold text-xs flex items-center gap-1.5">
                              <CheckCircle2 className="w-4 h-4" /> Onaylandı
                            </span>
                          ) : isRace && isClaimedBySibling ? (
                            <span className="px-3.5 py-2 rounded-xl bg-slate-800 border border-slate-700 text-slate-400 font-bold text-xs">
                              🔒 {claimedByUser?.name || 'Kardeşin'} Üstlendi
                            </span>
                          ) : isRace && !task.claimed_by ? (
                            <button
                              type="button"
                              onClick={async () => {
                                const res = await claimRaceTaskAtomic(
                                  task.id,
                                  activeUser.id
                                );
                                setFeedbackToast(res.message);
                                setTimeout(() => setFeedbackToast(null), 4000);
                              }}
                              className="px-4 py-2.5 rounded-2xl bg-gradient-to-r from-amber-400 via-orange-500 to-rose-500 hover:brightness-110 text-slate-950 font-black text-xs sm:text-sm flex items-center gap-1.5 shadow-xl animate-bounce transition"
                            >
                              <span>🏃‍♂️ Ben Yaparım! (Görevi Kap)</span>
                            </button>
                          ) : status === 'pending' ? (
                            <button
                              type="button"
                              onClick={() => setSelectedTaskForModal(task)}
                              className="px-3.5 py-2 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 border border-amber-400/40 text-amber-300 font-bold text-xs flex items-center gap-1.5 transition"
                            >
                              <Clock className="w-4 h-4 animate-spin" />
                              <span>Kontrol Bekleniyor (PIN ile Onayla)</span>
                            </button>
                          ) : (
                            <div className="flex flex-wrap items-center gap-2">
                              <button
                                type="button"
                                onClick={() => {
                                  setAutoStartBrushModal(false);
                                  setSelectedTaskForModal(task);
                                }}
                                className={`px-3.5 ${
                                  isJunior
                                    ? 'py-2.5 text-xs sm:text-sm rounded-2xl'
                                    : 'py-2 text-xs rounded-xl'
                                } ${persona.actionButtonGradient} font-black flex items-center gap-1.5 shadow-lg transition`}
                              >
                                {task.verification_type === 'qr_scan' ? (
                                  <>
                                    <QrCode className="w-4 h-4" />
                                    <span>📷 QR Okut ve Tamamla</span>
                                  </>
                                ) : (
                                  <>
                                    <CheckCircle2 className="w-4 h-4" />
                                    <span>
                                      {task.verification_type === 'direct_submit'
                                        ? persona.completeButtonText
                                        : '👀 Tamamladım! (Kontrole Çağır)'}
                                    </span>
                                  </>
                                )}
                              </button>
                              {task.verification_type !== 'direct_submit' &&
                                task.verification_type !== 'qr_scan' && (
                                  <button
                                    type="button"
                                    onClick={() => {
                                      setAutoStartBrushModal(false);
                                      setSelectedTaskForModal(task);
                                    }}
                                    className="px-3 py-2 rounded-xl bg-indigo-600/80 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-1 transition"
                                  >
                                    <Camera className="w-3.5 h-3.5" />
                                    <span>📸 Fotoğraf</span>
                                  </button>
                                )}
                            </div>
                          )}
                        </div>
                      </div>
                    </motion.div>
                  );
                })}
              </div>
            </>
          )}

          {/* TAB 2: 3-TIER REWARD MARKET */}
          {activeTab === 'market' && (
            <div className="space-y-4">
              {/* Phase 4: Happy Hour İndirim Saati Banner */}
              {activeHappyHourDiscountPercent > 0 && (
                <div className="bg-gradient-to-r from-rose-600 via-amber-500 to-pink-600 rounded-3xl p-4 sm:p-5 text-slate-950 shadow-2xl flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-2 border-yellow-200">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-2xl bg-slate-950 text-amber-400 flex items-center justify-center shadow-lg shrink-0">
                      <Tag className="w-6 h-6" />
                    </div>
                    <div>
                      <span className="px-2.5 py-0.5 rounded-full bg-slate-950 text-amber-300 font-black text-[10px] uppercase tracking-wider">
                        🏷️ HAPPY HOUR İNDİRİM SAATİ AKTİF!
                      </span>
                      <h3 className="text-lg sm:text-xl font-black text-slate-950">
                        Tüm Ödül Marketinde %{activeHappyHourDiscountPercent}{' '}
                        İndirim Fırsatı!
                      </h3>
                      <p className="text-xs font-bold text-slate-900">
                        Biriktirdiğin puanlarla ödülleri çok daha ucuza hemen
                        alabilirsin!
                      </p>
                    </div>
                  </div>
                  {familySettings.happy_hour_ends_at && (
                    <span className="px-3.5 py-1.5 rounded-2xl bg-slate-950 text-amber-300 font-mono font-black text-xs shrink-0">
                      ⏰ Bitiş:{' '}
                      {new Date(
                        familySettings.happy_hour_ends_at
                      ).toLocaleTimeString('tr-TR', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </span>
                  )}
                </div>
              )}

              <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900/80 p-3 rounded-2xl border border-slate-800">
                <div className="text-xs sm:text-sm text-slate-300">
                  <strong>💡 Bilgi:</strong> &ldquo;Ekran Süresi&rdquo; ödülü onaylandığı an tüm cihazlarının kilidi otomatik açılır!
                </div>
                <div className="flex flex-wrap items-center gap-1.5">
                  {(
                    [
                      'all',
                      'micro',
                      'medium',
                      'large',
                      'parent_challenge',
                    ] as const
                  ).map((tier) => (
                    <button
                      key={tier}
                      type="button"
                      onClick={() => setSelectedRewardTier(tier)}
                      className={`px-3 py-1 rounded-lg text-xs font-bold transition ${
                        selectedRewardTier === tier
                          ? 'bg-amber-400 text-slate-950'
                          : 'bg-slate-800 text-slate-300'
                      }`}
                    >
                      {tier === 'all' && 'Tümü'}
                      {tier === 'micro' && '⚡ Mikro'}
                      {tier === 'medium' && '🍕 Orta'}
                      {tier === 'large' && '🏆 Büyük'}
                      {tier === 'parent_challenge' && '⚔️ Ebeveyne Meydan Okuma'}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {rewards
                  .filter(
                    (r) =>
                      selectedRewardTier === 'all' || r.tier === selectedRewardTier
                  )
                  .map((reward) => {
                    const effectiveCost =
                      activeHappyHourDiscountPercent > 0
                        ? Math.max(
                            5,
                            Math.round(
                              (reward.cost_points *
                                (100 - activeHappyHourDiscountPercent)) /
                                100
                            )
                          )
                        : reward.cost_points;
                    const canAfford =
                      activeUser.points_balance >= effectiveCost;
                    const isPending = redemptions.some(
                      (red) =>
                        red.reward_id === reward.id &&
                        red.user_id === activeUser.id &&
                        red.status === 'pending'
                    );

                    return (
                      <div
                        key={reward.id}
                        className="bg-slate-900/90 border border-slate-800 rounded-2xl p-5 flex flex-col justify-between gap-4 hover:border-amber-400/50 transition"
                      >
                        <div>
                          <div className="flex items-center justify-between gap-2 mb-2">
                            <span
                              className={`text-[11px] font-extrabold uppercase px-2.5 py-0.5 rounded-full flex items-center gap-1 ${
                                reward.tier === 'micro'
                                  ? 'bg-cyan-500/20 text-cyan-300'
                                  : reward.tier === 'medium'
                                  ? 'bg-purple-500/20 text-purple-300'
                                  : reward.tier === 'parent_challenge'
                                  ? 'bg-rose-500/25 text-rose-300 border border-rose-400/40'
                                  : 'bg-amber-500/20 text-amber-300'
                              }`}
                            >
                              {reward.tier === 'micro' && 'Mikro Ödül (Otomatik Kilit Açar)'}
                              {reward.tier === 'medium' && 'Orta Kademe Ödül'}
                              {reward.tier === 'large' && 'Büyük Hedef'}
                              {reward.tier === 'parent_challenge' && (
                                <>
                                  <Swords className="w-3 h-3" /> Ebeveyne Meydan Okuma
                                </>
                              )}
                            </span>
                            <div className="text-right">
                              {activeHappyHourDiscountPercent > 0 ? (
                                <div className="flex items-center gap-1.5">
                                  <span className="text-xs font-bold text-slate-500 line-through">
                                    {reward.cost_points}
                                  </span>
                                  <span className="text-base font-black text-emerald-400">
                                    {effectiveCost} {isJunior ? '⭐' : 'XP'}
                                  </span>
                                  <span className="px-1.5 py-0.5 rounded bg-rose-500/25 text-rose-300 text-[10px] font-black">
                                    -%{activeHappyHourDiscountPercent}
                                  </span>
                                </div>
                              ) : (
                                <span className="text-base font-black text-amber-400">
                                  {reward.cost_points} {isJunior ? '⭐' : 'XP'}
                                </span>
                              )}
                            </div>
                          </div>
                          <h3 className="text-base font-extrabold text-white">
                            {reward.title}
                          </h3>
                        </div>

                        <button
                          type="button"
                          disabled={!canAfford || isPending}
                          onClick={() => handleBuyReward(reward.id)}
                          className={`w-full py-2.5 px-4 rounded-xl font-bold text-xs sm:text-sm transition ${
                            isPending
                              ? 'bg-amber-500/20 text-amber-300 cursor-wait'
                              : canAfford
                              ? 'bg-amber-400 hover:bg-amber-300 text-slate-950 shadow-lg'
                              : 'bg-slate-800 text-slate-500 cursor-not-allowed'
                          }`}
                        >
                          {isPending
                            ? '⏳ Ebeveyn Onayı Bekleniyor...'
                            : canAfford
                            ? activeHappyHourDiscountPercent > 0
                              ? `🏷️ %${activeHappyHourDiscountPercent} İndirimle Talep Et (${effectiveCost} P) 🎁`
                              : 'Ödülü Talep Et 🎁'
                            : `${effectiveCost - activeUser.points_balance} ${
                                isJunior ? 'Yıldız' : 'XP'
                              } Daha Lazım`}
                        </button>
                      </div>
                    );
                  })}
              </div>
            </div>
          )}

          {/* TAB 3: PIGGY BANK / INVESTMENT VAULT & LUCKY WHEEL */}
          {activeTab === 'piggy_wheel' && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              {/* Piggy Bank / XP Vault Card */}
              <div className="bg-gradient-to-br from-pink-950/80 via-slate-900 to-rose-950/80 border border-pink-500/40 rounded-3xl p-6 text-white">
                <div className="w-12 h-12 rounded-2xl bg-pink-500/20 text-pink-300 flex items-center justify-center mb-3">
                  <PiggyBank className="w-7 h-7" />
                </div>
                <h3 className="text-xl font-black mb-1">{persona.piggyTitle}</h3>
                <p className="text-xs text-pink-200 mb-4">{persona.piggyDesc}</p>

                <div className="bg-slate-950/60 rounded-2xl p-4 mb-4 flex items-center justify-between">
                  <div>
                    <div className="text-xs text-slate-400">Mevcut Birikim</div>
                    <div className="text-2xl font-black text-pink-400">
                      {activeUser.piggy_bank_balance} {isJunior ? '⭐' : 'XP'}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-slate-400">Pazar Gecesi (+%20)</div>
                    <div className="text-lg font-black text-emerald-400">
                      {Math.round(activeUser.piggy_bank_balance * 1.2)}{' '}
                      {isJunior ? '⭐' : 'XP'}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 mb-3">
                  {[15, 25, 50].map((amt) => (
                    <button
                      key={amt}
                      type="button"
                      onClick={() => setPiggyAmount(amt)}
                      className={`flex-1 py-2 rounded-xl text-xs font-bold border ${
                        piggyAmount === amt
                          ? 'bg-pink-500 text-white border-pink-300'
                          : 'bg-slate-800 text-slate-300 border-slate-700'
                      }`}
                    >
                      +{amt} {isJunior ? '⭐' : 'XP'}
                    </button>
                  ))}
                </div>

                <button
                  type="button"
                  disabled={activeUser.points_balance < piggyAmount}
                  onClick={handleDepositPiggy}
                  className="w-full py-3 rounded-2xl bg-pink-500 hover:bg-pink-400 disabled:opacity-40 text-white font-black text-sm shadow-lg transition"
                >
                  {isJunior
                    ? `Sihirli Kumbaraya ${piggyAmount} Yıldız At 🐷`
                    : `Yatırım Kasasına ${piggyAmount} XP Kilitle 📈`}
                </button>
              </div>

              {/* 5-Day Streak Lucky Wheel Card */}
              <div className="bg-gradient-to-br from-amber-950/80 via-slate-900 to-indigo-950/80 border border-amber-400/40 rounded-3xl p-6 text-white flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="px-3 py-1 rounded-full bg-amber-400/20 text-amber-300 text-xs font-extrabold">
                      {isJunior ? '🎡 5 GÜNLÜK ŞANS ÇARKI' : '🎰 5-DAY STREAK LOOT WHEEL'}
                    </span>
                    <span className="text-xs font-bold text-orange-300">
                      Seri: {activeUser.streak_days} / 5 Gün 🔥
                    </span>
                  </div>

                  <h3 className="text-xl font-black mb-1">
                    {isJunior ? 'Hafta Sonu Sürpriz Çarkı!' : 'Haftalık Bonus Loot Çarkı'}
                  </h3>
                  <p className="text-xs text-slate-300 mb-4">
                    Rutinlerini 5 gün üst üste eksiksiz tamamlayanlara sürpriz ödüllü çark açılır!
                  </p>

                  {/* Animated Wheel Graphic */}
                  <div className="my-4 flex flex-col items-center">
                    <motion.div
                      animate={wheelSpinning ? { rotate: 1080 } : { rotate: 0 }}
                      transition={{ duration: 1.5, ease: 'easeOut' }}
                      className="w-32 h-32 rounded-full border-4 border-amber-300 bg-gradient-to-tr from-indigo-600 via-pink-500 to-amber-400 flex items-center justify-center text-4xl shadow-2xl shadow-amber-500/30"
                    >
                      {isJunior ? '🎡' : '💎'}
                    </motion.div>

                    {wheelPrizeText && (
                      <div className="mt-3 px-4 py-2 rounded-xl bg-emerald-500 text-slate-950 font-black text-sm animate-bounce">
                        Kazandın: {wheelPrizeText}!
                      </div>
                    )}
                  </div>
                </div>

                <button
                  type="button"
                  disabled={
                    wheelSpinning ||
                    (activeUser.wheel_spins_available <= 0 &&
                      activeUser.streak_days < 5)
                  }
                  onClick={handleSpinWheel}
                  className="w-full py-3 rounded-2xl bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 disabled:opacity-40 text-slate-950 font-black text-sm shadow-lg transition"
                >
                  {wheelSpinning
                    ? 'Çark Dönüyor...'
                    : activeUser.wheel_spins_available > 0 ||
                      activeUser.streak_days >= 5
                    ? 'Şans Çarkını Çevir! 🎰'
                    : `Çark İçin ${5 - activeUser.streak_days} Gün Seri Kaldı`}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Right Sidebar: Walkie-Talkie & DM with Mom & Dad */}
        <div className="lg:col-span-4">
          <WalkieTalkieDM currentUserId={activeUser.id} />
        </div>
      </div>

      {/* Photo Proof & Toothbrush Timer Modal */}
      {selectedTaskForModal && (
        <PhotoProofModal
          task={selectedTaskForModal}
          studentId={activeUser.id}
          autoStartBrush={autoStartBrushModal}
          onClose={() => {
            setAutoStartBrushModal(false);
            setSelectedTaskForModal(null);
          }}
        />
      )}
    </div>
  );
};
