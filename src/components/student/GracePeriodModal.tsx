'use client';

import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import { Clock, ShieldCheck, Sparkles, Timer } from 'lucide-react';
import { UserProfile } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { soundEngine } from '@/lib/soundEngine';

interface GracePeriodModalProps {
  student: UserProfile;
  remainingSeconds: number;
}

export const GracePeriodModal: React.FC<GracePeriodModalProps> = ({
  student,
  remainingSeconds,
}) => {
  const { useGracePeriodExtension, voluntaryEarlyLockRefund } =
    useFamilyRealtime();

  const [inGraceSession, setInGraceSession] = useState(false);
  const [feedbackBanner, setFeedbackBanner] = useState<string | null>(null);
  const warned2MinRef = useRef(false);

  const isFreeTimeWithTimer =
    student.current_state === 'FREE_TIME' &&
    Boolean(student.state_ends_at) &&
    remainingSeconds > 0;

  // Trigger audio chime once when entering the last 2 minutes (120 seconds)
  useEffect(() => {
    if (isFreeTimeWithTimer && remainingSeconds <= 120 && !warned2MinRef.current) {
      warned2MinRef.current = true;
      soundEngine.playWalkieTalkieBeep();
    } else if (remainingSeconds > 125) {
      warned2MinRef.current = false;
    }
  }, [isFreeTimeWithTimer, remainingSeconds]);

  // Reset grace session flag if state leaves FREE_TIME
  useEffect(() => {
    if (student.current_state !== 'FREE_TIME') {
      setInGraceSession(false);
    }
  }, [student.current_state]);

  const handleUseGraceExtension = async () => {
    const res = await useGracePeriodExtension(student.id);
    setFeedbackBanner(res.message);
    if (res.success) {
      setInGraceSession(true);
    }
    setTimeout(() => setFeedbackBanner(null), 5000);
  };

  const handleVoluntaryEarlyExit = async () => {
    try {
      confetti({
        particleCount: 110,
        spread: 80,
        origin: { y: 0.6 },
      });
    } catch {}
    const res = await voluntaryEarlyLockRefund(student.id);
    setFeedbackBanner(res.message);
    setInGraceSession(false);
    setTimeout(() => setFeedbackBanner(null), 5000);
  };

  const showTwoMinuteWarning =
    isFreeTimeWithTimer && remainingSeconds <= 120 && remainingSeconds > 0;
  const showThirtySecJokerButton =
    isFreeTimeWithTimer &&
    remainingSeconds <= 30 &&
    !student.grace_used_today &&
    !inGraceSession;

  const mins = Math.floor(remainingSeconds / 60);
  const secs = remainingSeconds % 60;

  if (!showTwoMinuteWarning && !inGraceSession && !feedbackBanner) {
    return null;
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0, y: -12, scale: 0.98 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: -12 }}
        className="bg-gradient-to-r from-amber-950/90 via-orange-950/90 to-rose-950/90 border-2 border-amber-400 rounded-3xl p-4 sm:p-5 shadow-2xl space-y-3"
      >
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-start gap-3">
            <div className="w-12 h-12 rounded-2xl bg-amber-400 text-slate-950 flex items-center justify-center shrink-0 font-black shadow-lg">
              <Timer className="w-7 h-7 animate-bounce" />
            </div>
            <div>
              <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-400/20 text-amber-300 text-[11px] font-black mb-1">
                <Sparkles className="w-3.5 h-3.5" />
                <span>KRİZ ÖNLEYİCİ OYUN KAYDETME & İRADE ASİSTANI</span>
              </div>
              <h4 className="text-base sm:text-lg font-black text-white">
                {inGraceSession
                  ? '⏱️ +3 Dakika Uzatma Süresi Aktif! Oyununu Rahatça Kaydet'
                  : remainingSeconds <= 30
                  ? '🚨 Son 30 Saniye! Ekran Kilitlenmek Üzere!'
                  : '⏳ Son 2 dakika! Oyununu kaydetmeye hazırlan.'}
              </h4>
              <p className="text-xs text-amber-100/90 mt-0.5">
                {inGraceSession
                  ? 'Süre bitmeden kendi isteğinle çıkarsan harcadığın 10 puanın tamamı iade edilir ve üstüne +5 İrade Bonusu (Toplam +15 Puan) kazanırsın!'
                  : 'Serbest oyun süren bitmek üzere. Yarıda kalmaması için oyununu veya çalışmanı şimdi kaydet.'}
              </p>
            </div>
          </div>

          {/* Live Countdown Badge */}
          <div className="px-4 py-2 rounded-2xl bg-slate-950 border border-amber-400/50 text-amber-300 font-mono font-black text-xl text-center shrink-0">
            {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
          </div>
        </div>

        {/* Rescue & Willpower Action Buttons */}
        <div className="flex flex-wrap items-center gap-3 pt-1">
          {showThirtySecJokerButton && (
            <button
              type="button"
              onClick={handleUseGraceExtension}
              className="flex-1 min-w-[260px] py-3.5 px-5 rounded-2xl bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-slate-950 font-black text-sm flex items-center justify-center gap-2 shadow-xl transition"
            >
              <Clock className="w-5 h-5" />
              <span>⏱️ Oyunu Kaydetmek İçin +3 Dakika Uzatma Al (10 Puan)</span>
            </button>
          )}

          {(inGraceSession || student.grace_used_today) &&
            student.current_state === 'FREE_TIME' && (
              <button
                type="button"
                onClick={handleVoluntaryEarlyExit}
                className="flex-1 min-w-[280px] py-3.5 px-5 rounded-2xl bg-gradient-to-r from-emerald-400 to-teal-500 hover:from-emerald-300 hover:to-teal-400 text-slate-950 font-black text-sm flex items-center justify-center gap-2 shadow-xl transition"
              >
                <ShieldCheck className="w-5 h-5" />
                <span>
                  ✅ Oyunu Kaydettim, Kendi İsteğimle Çıkıyorum (10 Puanımı İade Al + 5 Bonus!)
                </span>
              </button>
            )}
        </div>

        {feedbackBanner && (
          <div className="bg-slate-950/90 border border-emerald-400/40 rounded-2xl px-4 py-2.5 text-xs font-bold text-emerald-300">
            {feedbackBanner}
          </div>
        )}
      </motion.div>
    </AnimatePresence>
  );
};
