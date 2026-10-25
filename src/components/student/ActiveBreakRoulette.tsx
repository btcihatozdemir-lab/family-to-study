'use client';

import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  RefreshCw,
  CheckCircle2,
  Sparkles,
  Zap,
  Wind,
  Droplets,
  Activity,
} from 'lucide-react';

interface ActiveBreakRouletteProps {
  studentId: string;
  studentName: string;
  isBreakTime: boolean;
  onCompleteChallenge: (
    studentId: string,
    challengeTitle: string
  ) => Promise<void>;
}

const BREAK_CHALLENGES = [
  {
    id: 'jump-breathe',
    emoji: '🌬️',
    title: 'Pencereyi aç, 5 derin nefes al ve 10 kez zıpla! (+5 Enerji Puanı)',
    badge: 'Oksijen & Kardiyo',
    icon: Wind,
  },
  {
    id: 'water-eyes',
    emoji: '💧',
    title:
      'Mutfağa git, bir bardak su iç ve gözlerini dinlendir! (+5 Enerji Puanı)',
    badge: 'Hidrasyon & Göz',
    icon: Droplets,
  },
  {
    id: 'shoulder-stretch',
    emoji: '🧘‍♂️',
    title: 'Omuzlarını 10 kez geriye çevir ve esne! (+5 Enerji Puanı)',
    badge: 'Duruş & Esneme',
    icon: Activity,
  },
  {
    id: 'neck-march',
    emoji: '🏃‍♂️',
    title:
      'Ayağa kalk, 30 saniye olduğun yerde tempolu yürü ve kollarını salla! (+5 Enerji Puanı)',
    badge: 'Kan Dolaşımı',
    icon: Zap,
  },
];

export const ActiveBreakRoulette: React.FC<ActiveBreakRouletteProps> = ({
  studentId,
  studentName,
  isBreakTime,
  onCompleteChallenge,
}) => {
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [isSpinning, setIsSpinning] = useState(false);
  const [completedThisBreak, setCompletedThisBreak] = useState(false);

  const spinWheel = () => {
    setIsSpinning(true);
    setCompletedThisBreak(false);
    let ticks = 0;
    const interval = setInterval(() => {
      setSelectedIndex((prev) => (prev + 1) % BREAK_CHALLENGES.length);
      ticks += 1;
      if (ticks >= 10) {
        clearInterval(interval);
        const finalIndex = Math.floor(Math.random() * BREAK_CHALLENGES.length);
        setSelectedIndex(finalIndex);
        setIsSpinning(false);
      }
    }, 95);
  };

  useEffect(() => {
    if (isBreakTime) {
      spinWheel();
    } else {
      setCompletedThisBreak(false);
    }
  }, [isBreakTime]);

  const currentChallenge = BREAK_CHALLENGES[selectedIndex];

  const handleComplete = async () => {
    if (completedThisBreak || isSpinning) return;
    setCompletedThisBreak(true);
    try {
      if (typeof window !== 'undefined') {
        confetti({
          particleCount: 55,
          spread: 65,
          origin: { y: 0.7 },
        });
      }
      await onCompleteChallenge(studentId, currentChallenge.title);
    } catch (err) {
      console.error('[ActiveBreakRoulette] Hata:', err);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      className={`rounded-3xl border p-5 shadow-xl transition-all ${
        isBreakTime
          ? 'border-emerald-400/60 bg-gradient-to-br from-emerald-950/90 via-teal-950/85 to-slate-900 text-white shadow-emerald-500/20 ring-2 ring-emerald-400/40'
          : 'border-cyan-500/30 bg-gradient-to-br from-slate-900/90 via-cyan-950/40 to-slate-900 text-white'
      }`}
    >
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2.5">
          <motion.div
            animate={isSpinning ? { rotate: 360 } : { rotate: 0 }}
            transition={
              isSpinning
                ? { duration: 0.5, repeat: Infinity, ease: 'linear' }
                : { duration: 0.3 }
            }
            className="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-400 to-cyan-500 text-slate-950 text-xl font-black shadow-lg shadow-emerald-500/30"
          >
            🏃‍♂️
          </motion.div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="inline-flex items-center gap-1 rounded-full bg-emerald-400/20 px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider text-emerald-300 border border-emerald-400/30">
                <Sparkles className="h-3 w-3" />
                {isBreakTime
                  ? 'AKTİF MOLA MODU AÇIK!'
                  : 'BİLİŞSEL YORGUNLUK SIFIRLAYICI'}
              </span>
            </div>
            <h3 className="text-base font-black text-white">
              🏃‍♂️ Mola Enerji Çarkı ({studentName})
            </h3>
          </div>
        </div>

        <button
          type="button"
          onClick={spinWheel}
          disabled={isSpinning}
          className="inline-flex items-center gap-1.5 rounded-xl border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-bold text-emerald-200 hover:bg-white/20 disabled:opacity-50 transition"
        >
          <RefreshCw
            className={`h-3.5 w-3.5 ${isSpinning ? 'animate-spin' : ''}`}
          />
          <span>Çarkı Çevir</span>
        </button>
      </div>

      <motion.div
        key={currentChallenge.id}
        initial={{ scale: 0.96, opacity: 0.6 }}
        animate={{ scale: 1, opacity: 1 }}
        className="rounded-2xl border border-emerald-400/30 bg-slate-950/60 p-4 mb-3"
      >
        <div className="flex items-start gap-3">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-emerald-500/20 text-2xl border border-emerald-400/30">
            {currentChallenge.emoji}
          </div>
          <div className="flex-1">
            <span className="inline-block rounded-lg bg-cyan-500/20 px-2 py-0.5 text-[10px] font-bold text-cyan-300 mb-1">
              {currentChallenge.badge} • 2-3 Dakika
            </span>
            <p className="text-sm font-extrabold text-white leading-snug">
              {currentChallenge.title}
            </p>
            <p className="mt-1 text-[11px] text-emerald-200/80">
              Tamamladığında <strong>+5 Enerji Puanı</strong> ve Dijital
              Yoldaşına <strong>+10 Enerji ⚡</strong> yüklenir!
            </p>
          </div>
        </div>
      </motion.div>

      <div className="flex items-center justify-between gap-3">
        <div className="text-[11px] text-slate-300">
          {completedThisBreak ? (
            <span className="font-bold text-emerald-300">
              🎉 Harika! Beynin ve dijital yoldaşın enerjiyle doldu!
            </span>
          ) : (
            <span>
              Hareketi tamamladıktan sonra butona bas ve ödülünü topla:
            </span>
          )}
        </div>

        <button
          type="button"
          onClick={handleComplete}
          disabled={completedThisBreak || isSpinning}
          className={`inline-flex items-center gap-1.5 rounded-2xl px-4 py-2.5 text-xs font-black transition shadow-lg ${
            completedThisBreak
              ? 'bg-emerald-500/25 text-emerald-200 border border-emerald-400/40 cursor-default'
              : 'bg-gradient-to-r from-emerald-400 to-teal-400 text-slate-950 hover:brightness-110 shadow-emerald-500/30'
          }`}
        >
          <CheckCircle2 className="h-4 w-4" />
          <span>
            {completedThisBreak
              ? '✅ Yaptım (+5 Puan & +10 Enerji Alındı)'
              : '🏃‍♂️ Yaptım! (+5 Puan & +10 Yoldaş Enerjisi)'}
          </span>
        </button>
      </div>
    </motion.div>
  );
};
