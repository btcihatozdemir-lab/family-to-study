'use client';

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import { Sun, Sparkles, Volume2, Brain, QrCode } from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { UserProfile } from '@/types/database';
import { getAgeAdaptivePersona } from '@/lib/ageThemeEngine';
import { QRScannerBox } from '@/components/shared/QRCodeScannerAndPrint';

interface WakeUpAlarmOverlayProps {
  student: UserProfile;
  onAutoStartToothbrush?: () => void;
}

export const WakeUpAlarmOverlay: React.FC<WakeUpAlarmOverlayProps> = ({
  student,
  onAutoStartToothbrush,
}) => {
  const { alarms, qrStations, completeWakeUpChallenge } = useFamilyRealtime();
  const persona = getAgeAdaptivePersona(student);
  const isJunior = persona.tier === 'junior';

  // Öğrencinin aktif wake_up alarm kaydında require_qr_station_id var mı?
  const studentWakeAlarm = alarms.find(
    (a) => a.user_id === student.id && a.type === 'wake_up' && a.is_enabled
  );
  const requiredStation = qrStations.find(
    (q) =>
      q.id === studentWakeAlarm?.require_qr_station_id ||
      q.linked_action === 'dismiss_wake_up_alarm'
  );

  const [starsCaught, setStarsCaught] = useState<number>(0);
  const [starPos, setStarPos] = useState<{ top: string; left: string }>({
    top: '35%',
    left: '48%',
  });
  const [riddleIdx] = useState(() =>
    Math.floor(Math.random() * persona.riddles.length)
  );
  const [riddleSolved, setRiddleSolved] = useState(false);
  const [wrongTry, setWrongTry] = useState(false);

  const currentRiddle = persona.riddles[riddleIdx] || persona.riddles[0];

  const randomizeStarPosition = () => {
    const top = `${Math.floor(Math.random() * 55) + 18}%`;
    const left = `${Math.floor(Math.random() * 65) + 15}%`;
    setStarPos({ top, left });
  };

  useEffect(() => {
    if (requiredStation) return;
    const moveTimer = setInterval(
      () => {
        if (starsCaught < 3) {
          randomizeStarPosition();
        }
      },
      isJunior ? 1900 : 1400
    );
    return () => clearInterval(moveTimer);
  }, [starsCaught, isJunior, requiredStation]);

  const handleCatchStar = () => {
    const nextCount = starsCaught + 1;
    setStarsCaught(nextCount);
    randomizeStarPosition();
  };

  const handleQRScannedSuccess = async () => {
    try {
      confetti({
        particleCount: 130,
        spread: 90,
        origin: { y: 0.6 },
      });
      await completeWakeUpChallenge(student.id);
      // Otomatik olarak 2 dakikalık Diş Fırçalama sayacını başlat!
      onAutoStartToothbrush?.();
    } catch (err) {
      console.error('[WakeUpAlarmOverlay.handleQRScannedSuccess] Hata:', err);
    }
  };

  const handleAnswerRiddle = async (idx: number) => {
    if (idx === currentRiddle.correctIndex) {
      setRiddleSolved(true);
      confetti({
        particleCount: 110,
        spread: 80,
        origin: { y: 0.6 },
      });
      await completeWakeUpChallenge(student.id);
      onAutoStartToothbrush?.();
    } else {
      setWrongTry(true);
      setTimeout(() => setWrongTry(false), 1000);
    }
  };

  return (
    <div
      className={`fixed inset-0 z-50 ${
        isJunior
          ? 'bg-gradient-to-br from-amber-500 via-orange-500 to-rose-600'
          : 'bg-gradient-to-br from-indigo-950 via-purple-900 to-fuchsia-900'
      } flex flex-col items-center justify-center p-4 sm:p-8 text-white overflow-y-auto select-none`}
    >
      {/* Main Alarm Card */}
      <div className="relative z-10 max-w-xl w-full bg-slate-950/65 backdrop-blur-xl border-2 border-yellow-300/60 rounded-3xl p-6 sm:p-8 text-center shadow-2xl my-auto">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-yellow-400 text-slate-950 font-extrabold text-xs sm:text-sm mb-4 animate-bounce">
          <Volume2 className="w-4 h-4" />
          {persona.wakeHeaderBadge}
        </div>

        <motion.div
          animate={{ scale: [1, 1.12, 1] }}
          transition={{ repeat: Infinity, duration: 1.5 }}
          className="w-20 h-20 mx-auto mb-3 rounded-full bg-gradient-to-tr from-yellow-300 to-amber-500 flex items-center justify-center shadow-lg shadow-yellow-400/50"
        >
          <Sun className="w-12 h-12 text-slate-950" />
        </motion.div>

        <h1 className="text-2xl sm:text-4xl font-black tracking-tight mb-2">
          Günaydın {student.name}! ☀️
        </h1>
        <p className="text-sm sm:text-base text-amber-100 mb-5">
          Alarmı susturmak ve{' '}
          <strong>+10 Erken Kalkış {isJunior ? 'Yıldızı ⭐' : 'XP 💎'}</strong>{' '}
          kazanmak için sabah istasyon görevini tamamla!
        </p>

        {/* EĞER SABAH ALARMINDA FİZİKSEL QR İSTASYONU ZORUNLUYSA: NORMAL BUTONU GİZLE VE BANYO QR KAMERASINI AÇ */}
        {requiredStation ? (
          <div className="space-y-4">
            <div className="bg-cyan-500/15 border border-cyan-400/40 rounded-2xl p-3.5 text-xs sm:text-sm text-cyan-200 flex items-center justify-center gap-2 font-bold">
              <QrCode className="w-5 h-5 text-cyan-300 shrink-0" />
              <span>
                Sabah alarmını susturmak için banyoya git ve aynadaki QR kodu
                okut! Okuttuğun an 2 dakikalık müzikli diş fırçalama sayacı
                otomatik başlayacak! 🪥🎵
              </span>
            </div>

            <QRScannerBox
              expectedStation={requiredStation}
              onScanSuccess={handleQRScannedSuccess}
              buttonLabel="📷 Banyodaki QR Kodu Okut ve Alarmı Sustur"
            />
          </div>
        ) : starsCaught < 3 ? (
          /* STEP 1: Catch 3 Jumping Targets */
          <div className="relative h-60 w-full bg-slate-900/75 rounded-2xl border border-yellow-400/40 overflow-hidden mb-4 flex flex-col items-center justify-between p-4">
            <div className="flex items-center justify-between w-full text-xs sm:text-sm font-bold text-yellow-300">
              <span>{persona.wakeCatchInstruction}</span>
              <span className="bg-yellow-400/20 px-3 py-1 rounded-full">
                {starsCaught} / 3 {persona.wakeTargetEmoji}
              </span>
            </div>

            <AnimatePresence mode="wait">
              <motion.button
                key={`${starPos.top}-${starPos.left}-${starsCaught}`}
                initial={{ scale: 0.3, opacity: 0 }}
                animate={{ scale: 1.1, opacity: 1 }}
                exit={{ scale: 0, opacity: 0 }}
                whileTap={{ scale: 1.4 }}
                type="button"
                onClick={handleCatchStar}
                style={{ top: starPos.top, left: starPos.left }}
                className="absolute -translate-x-1/2 -translate-y-1/2 p-4 rounded-full bg-gradient-to-r from-yellow-300 to-amber-400 text-slate-950 text-2xl shadow-xl shadow-yellow-400/60 hover:scale-125 transition"
              >
                {persona.wakeTargetEmoji}
              </motion.button>
            </AnimatePresence>

            <p className="text-xs text-slate-300">
              Hedef yer değiştirmeden üzerine dokun! ({3 - starsCaught} tane kaldı)
            </p>
          </div>
        ) : (
          /* STEP 2: Solve Age-Appropriate Morning Brain Question */
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-slate-900/85 rounded-2xl border border-emerald-400/50 p-5 text-left"
          >
            <div className="flex items-center gap-2 text-emerald-300 font-bold text-xs sm:text-sm mb-2">
              <Brain className="w-4 h-4" />
              <span>
                {isJunior
                  ? 'Görev 2/2: Sabah Bilmecesini Seç ve Alarmı Kapat!'
                  : 'Aşama 2/2: Zihin Kalibrasyonu Sorusunu Çöz ve Alarmı Kapat!'}
              </span>
            </div>

            <p className="text-base sm:text-lg font-bold text-white mb-4">
              {currentRiddle.question}
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
              {currentRiddle.options.map((opt, idx) => (
                <button
                  key={idx}
                  type="button"
                  disabled={riddleSolved}
                  onClick={() => handleAnswerRiddle(idx)}
                  className="py-3 px-4 rounded-xl bg-indigo-600 hover:bg-indigo-500 active:scale-95 font-bold text-sm text-white shadow-lg transition flex items-center justify-center gap-1.5"
                >
                  <Sparkles className="w-4 h-4 text-yellow-300" />
                  <span>{opt}</span>
                </button>
              ))}
            </div>

            {wrongTry && (
              <p className="text-xs text-rose-300 font-semibold mt-3 text-center">
                Hmm, tekrar dikkatli bak! 😊
              </p>
            )}
          </motion.div>
        )}
      </div>
    </div>
  );
};
