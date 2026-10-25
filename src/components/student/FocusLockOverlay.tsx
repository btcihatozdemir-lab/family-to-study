'use client';

import React, { useEffect, useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Shield,
  ShieldAlert,
  Camera,
  Moon,
  BookOpen,
  Sparkles,
  CheckCircle2,
  Hand,
  KeyRound,
} from 'lucide-react';
import { UserProfile, TaskItem } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { getAgeAdaptivePersona } from '@/lib/ageThemeEngine';
import { WalkieTalkieDM } from '@/components/shared/WalkieTalkieDM';
import { PhotoProofModal } from './PhotoProofModal';

interface FocusLockOverlayProps {
  student: UserProfile;
  remainingSeconds: number;
}

export const FocusLockOverlay: React.FC<FocusLockOverlayProps> = ({
  student,
  remainingSeconds,
}) => {
  const {
    tasks,
    submissions,
    recordViolation,
    unlockWithOfflineMasterPin,
  } = useFamilyRealtime();
  const [selectedTaskForModal, setSelectedTaskForModal] =
    useState<TaskItem | null>(null);
  const [violationFlash, setViolationFlash] = useState<string | null>(null);
  const [showOfflinePinBox, setShowOfflinePinBox] = useState(false);
  const [offlinePinInput, setOfflinePinInput] = useState('');
  const [offlinePinError, setOfflinePinError] = useState<string | null>(null);
  const lastViolationMsRef = useRef<number>(0);

  const persona = getAgeAdaptivePersona(student);
  const isJunior = persona.tier === 'junior';
  const isSleepMode = student.current_state === 'SLEEP_TIME';

  // Find active academic or routine tasks for this student
  const activeTasks = tasks.filter(
    (t) =>
      t.is_active &&
      (t.assigned_to === student.id || t.assigned_to === 'both') &&
      !submissions.some(
        (s) =>
          s.task_id === t.id &&
          s.user_id === student.id &&
          (s.status === 'approved' || s.status === 'pending')
      )
  );

  const primaryFocusTask =
    activeTasks.find(
      (t) => t.category === 'academic' || t.category === 'flash_quest'
    ) || activeTasks[0];

  // 1. iOS / Tablet App Minimized Sensor (document.visibilityState === 'hidden')
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'hidden') {
        const now = Date.now();
        if (now - lastViolationMsRef.current > 3000) {
          lastViolationMsRef.current = now;
          recordViolation(student.id, 'ios_app_minimized');
          setViolationFlash(
            '🚨 Görev ekranından çıkıldığı tespit edildi! 1 Odaklanma Kalkanı kırıldı!'
          );
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () =>
      document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [student.id, recordViolation]);

  // 2. Unauthorized Touch / Click Sensor (Ignores elements inside data-allow-touch="true")
  const handleProtectedSurfaceInteraction = (
    e: React.MouseEvent<HTMLDivElement> | React.TouchEvent<HTMLDivElement>
  ) => {
    const target = e.target as HTMLElement | null;
    if (!target) return;

    if (target.closest('[data-allow-touch="true"]')) {
      return;
    }

    const now = Date.now();
    if (now - lastViolationMsRef.current < 2200) return;
    lastViolationMsRef.current = now;

    recordViolation(student.id, 'ios_touch_detected');
    setViolationFlash(
      isJunior
        ? `🚨 Eyvah! ${student.name}, ekrana dokunduğun için uyuyan kedi uyandı ve 1 Süper Kalkanın kırıldı!`
        : `🚨 Odak Protokolü İhlali: ${student.name}, çalışma modunda ekran etkileşimi algılandı (-1 Odak Enerjisi).`
    );
    setTimeout(() => setViolationFlash(null), 5000);
  };

  // Format MM:SS
  const mins = Math.floor(remainingSeconds / 60);
  const secs = remainingSeconds % 60;
  const formattedTime = `${String(mins).padStart(2, '0')}:${String(secs).padStart(
    2,
    '0'
  )}`;

  // Circular progress ring math
  const totalEstimatedSec = isSleepMode ? 8 * 3600 : 40 * 60;
  const progressRatio = Math.min(
    1,
    Math.max(0.05, remainingSeconds / totalEstimatedSec)
  );
  const radius = 84;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference * (1 - progressRatio);

  return (
    <div
      onMouseDown={handleProtectedSurfaceInteraction}
      onTouchStart={handleProtectedSurfaceInteraction}
      className={`min-h-[calc(100vh-4rem)] w-full rounded-3xl p-4 sm:p-8 relative overflow-hidden select-none transition-colors duration-700 ${
        isSleepMode
          ? 'bg-gradient-to-b from-slate-950 via-indigo-950 to-slate-950 border-indigo-500/40'
          : isJunior
          ? 'bg-gradient-to-br from-indigo-950 via-teal-950/60 to-amber-950/50 border-amber-400/50'
          : 'bg-gradient-to-br from-slate-950 via-purple-950/80 to-indigo-950 border-fuchsia-500/40'
      } border-2 shadow-2xl text-white`}
    >
      {/* Violation Flash Banner */}
      <AnimatePresence>
        {violationFlash && (
          <motion.div
            initial={{ y: -40, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: -40, opacity: 0 }}
            className="mb-5 bg-rose-600/95 border-2 border-rose-300 rounded-2xl p-4 flex items-center gap-3 shadow-2xl"
          >
            <ShieldAlert className="w-7 h-7 text-white shrink-0 animate-bounce" />
            <div className="text-xs sm:text-sm font-bold">{violationFlash}</div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Top Status & Remaining Daily Shields */}
      <div className="flex flex-wrap items-center justify-between gap-4 mb-6">
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 rounded-2xl bg-indigo-500/20 border border-indigo-400/40 flex items-center justify-center text-3xl">
            {isSleepMode ? '🌙' : isJunior ? '🐱🌱' : '🪐⚡'}
          </div>
          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-amber-400/20 text-amber-300 text-[11px] font-extrabold uppercase tracking-wider">
              {isSleepMode ? (
                <>
                  <Moon className="w-3.5 h-3.5" /> Uyku & Dinlenme Kalkanı
                </>
              ) : (
                <>
                  <BookOpen className="w-3.5 h-3.5" /> {persona.lockBadge}
                </>
              )}
            </div>
            <h2 className="text-lg sm:text-2xl font-black mt-0.5">
              {isSleepMode
                ? 'Tatlı Rüyalar! Dinlenme Modu Aktif 💤'
                : persona.lockHeadline}
            </h2>
          </div>
        </div>

        {/* Daily Shields Display */}
        <div className="bg-slate-900/90 border border-slate-700 rounded-2xl px-4 py-2.5 flex items-center gap-3">
          <div>
            <div className="text-[11px] text-slate-400 font-semibold">
              {persona.shieldLabel}
            </div>
            <div className="text-xs text-emerald-300 font-bold">
              {persona.shieldSubtext}
            </div>
          </div>
          <div className="flex items-center gap-1.5">
            {[1, 2, 3].map((idx) => {
              const intact = idx <= student.daily_shields;
              return (
                <motion.div
                  key={idx}
                  animate={intact ? { scale: [1, 1.08, 1] } : { scale: 0.85 }}
                  transition={{ repeat: intact ? Infinity : 0, duration: 2 }}
                  className={`p-2 rounded-xl border ${
                    intact
                      ? 'bg-emerald-500/20 border-emerald-400 text-emerald-300 shadow-lg shadow-emerald-500/20'
                      : 'bg-rose-950/50 border-rose-800/50 text-rose-600 opacity-50'
                  }`}
                >
                  <Shield className="w-5 h-5 fill-current" />
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Column: Circular Timer & Age-Adaptive Mascot/Core Animation */}
        <div className="lg:col-span-5 bg-slate-900/60 border border-indigo-500/30 rounded-3xl p-6 flex flex-col items-center text-center">
          <motion.div
            animate={{ y: [0, -8, 0] }}
            transition={{ repeat: Infinity, duration: 3, ease: 'easeInOut' }}
            className="mb-3 flex items-center justify-center gap-3 text-4xl sm:text-5xl"
          >
            <span>{isSleepMode ? '🛌🌟' : persona.lockMascotEmojis}</span>
          </motion.div>
          <p className="text-xs sm:text-sm text-indigo-200 max-w-xs mb-4">
            {isSleepMode
              ? 'Sabah alarmına kadar cihazların dinlenme modunda.'
              : persona.lockSubtext}
          </p>

          {/* Large Circular Synchronized Countdown */}
          <div className="relative w-52 h-52 flex items-center justify-center mb-4">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 200 200">
              <circle
                cx="100"
                cy="100"
                r={radius}
                stroke="rgba(99, 102, 241, 0.2)"
                strokeWidth="12"
                fill="transparent"
              />
              <circle
                cx="100"
                cy="100"
                r={radius}
                stroke={isJunior ? '#fbbf24' : '#e879f9'}
                strokeWidth="12"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                strokeLinecap="round"
                fill="transparent"
                className="transition-all duration-500"
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-[11px] uppercase tracking-widest text-indigo-300 font-bold">
                KALAN SÜRE
              </span>
              <span className="text-4xl sm:text-5xl font-black font-mono tracking-tight text-white my-1">
                {formattedTime}
              </span>
              <span className="text-[11px] text-emerald-300 font-semibold">
                Tüm Cihazlar Senkron
              </span>
            </div>
          </div>

          <div className="bg-amber-500/10 border border-amber-400/30 rounded-2xl p-3 text-xs text-amber-200 flex items-center gap-2">
            <Hand className="w-4 h-4 text-amber-400 shrink-0" />
            <span>{persona.lockSensorWarning}</span>
          </div>
        </div>

        {/* Right Column: Active Task Card (Photo Proof) & Walkie-Talkie DM */}
        <div className="lg:col-span-7 space-y-5">
          {/* Active Task Card */}
          <div
            data-allow-touch="true"
            className="bg-slate-900/90 border-2 border-emerald-500/40 rounded-3xl p-5 shadow-xl"
          >
            <div className="flex items-center justify-between gap-2 mb-2">
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-extrabold">
                <Sparkles className="w-3.5 h-3.5" />
                {isJunior
                  ? 'ŞU ANKİ ÖDEV MACERAN'
                  : 'AKTİF ÇALIŞMA GÖREVİ (QUEST)'}
              </span>
              {primaryFocusTask && (
                <span className="text-sm font-black text-amber-400">
                  +{primaryFocusTask.points} {isJunior ? 'Yıldız ⭐' : 'XP 💎'}
                </span>
              )}
            </div>

            {primaryFocusTask ? (
              <>
                <h3 className="text-lg sm:text-xl font-black text-white mb-1">
                  {primaryFocusTask.title}
                </h3>
                <p className="text-xs sm:text-sm text-slate-300 mb-4">
                  {primaryFocusTask.description}
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  <button
                    type="button"
                    onClick={() => setSelectedTaskForModal(primaryFocusTask)}
                    className="py-3.5 px-4 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 text-slate-950 font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-lg shadow-emerald-500/25 transition"
                  >
                    <CheckCircle2 className="w-4 h-4 shrink-0" />
                    <span>👀 Tamamladım! (Kontrole Çağır)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setSelectedTaskForModal(primaryFocusTask)}
                    className="py-3.5 px-4 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-lg transition"
                  >
                    <Camera className="w-4 h-4 shrink-0" />
                    <span>📸 Fotoğraf Çek ve Gönder</span>
                  </button>
                </div>
              </>
            ) : (
              <div className="text-center py-4 text-emerald-300 font-bold text-sm">
                🎉 Harika! Tüm aktif görevlerini tamamladın ve onaya gönderdin!
              </div>
            )}
          </div>

          {/* Walkie-Talkie & DM Box */}
          <WalkieTalkieDM currentUserId={student.id} compact />

          {/* Acil Durum Offline PIN Kilit Açma Kutusu (İnternet Kesintisi Durumu İçin) */}
          <div
            data-allow-touch="true"
            className="bg-slate-900/80 border border-slate-800 rounded-2xl p-3.5"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs text-slate-400 flex items-center gap-1.5 font-semibold">
                <KeyRound className="w-3.5 h-3.5 text-amber-400" />
                <span>Acil Durum Offline Ebeveyn Kilidi Açma (SHA-256)</span>
              </span>
              <button
                type="button"
                onClick={() => {
                  setShowOfflinePinBox((v) => !v);
                  setOfflinePinError(null);
                }}
                className="text-xs font-bold text-indigo-300 hover:text-indigo-200 underline"
              >
                {showOfflinePinBox ? 'Gizle' : '6 Haneli PIN Gir'}
              </button>
            </div>

            {showOfflinePinBox && (
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  const res = await unlockWithOfflineMasterPin(
                    student.id,
                    offlinePinInput
                  );
                  if (!res.success) {
                    setOfflinePinError(res.message);
                  } else {
                    setOfflinePinInput('');
                    setShowOfflinePinBox(false);
                  }
                }}
                className="mt-3 flex flex-wrap items-center gap-2"
              >
                <input
                  type="password"
                  maxLength={6}
                  value={offlinePinInput}
                  onChange={(e) => setOfflinePinInput(e.target.value)}
                  placeholder="6 Haneli Offline PIN (Varsayılan: 123456)"
                  className="flex-1 bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                />
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-black text-xs transition"
                >
                  Kilidi Aç
                </button>
                {offlinePinError && (
                  <p className="w-full text-xs text-rose-400 font-bold mt-1">
                    {offlinePinError}
                  </p>
                )}
              </form>
            )}
          </div>
        </div>
      </div>

      {/* Photo Proof Modal */}
      {selectedTaskForModal && (
        <PhotoProofModal
          task={selectedTaskForModal}
          studentId={student.id}
          onClose={() => setSelectedTaskForModal(null)}
        />
      )}
    </div>
  );
};
