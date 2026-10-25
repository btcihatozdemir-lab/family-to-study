'use client';

import React, { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Eye, Droplets, Volume2, Mic, MicOff, Sparkles } from 'lucide-react';
import { UserProfile } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { isRunningInsideWindowsAgent } from '@/lib/ttsAnnouncer';

interface HealthAndNoiseMonitorProps {
  student: UserProfile;
}

export const HealthAndNoiseMonitor: React.FC<HealthAndNoiseMonitorProps> = ({
  student,
}) => {
  const { familySettings, awardHealthPoints, recordViolation } =
    useFamilyRealtime();

  const isWindowsAgent = isRunningInsideWindowsAgent();
  const noiseThresholdDb = familySettings?.noise_threshold_db ?? 75;

  // 1) Module D: 20-20-20 Eye & Posture Shield + Water Break State
  const [eyeBreakRemaining, setEyeBreakRemaining] = useState<number>(0);
  const [showWaterBreakPrompt, setShowWaterBreakPrompt] = useState<boolean>(false);
  const [healthToast, setHealthToast] = useState<string | null>(null);

  // 2) Module E: Web Audio Decibel Meter State (Zero Audio Recording!)
  const [micActive, setMicActive] = useState<boolean>(false);
  const [currentDb, setCurrentDb] = useState<number>(42);
  const [loudSecondsCount, setLoudSecondsCount] = useState<number>(0);
  const [showNoiseCalmingBanner, setShowNoiseCalmingBanner] =
    useState<boolean>(false);

  const audioCtxRef = useRef<AudioContext | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animFrameRef = useRef<number | null>(null);
  const loudSecRef = useRef<number>(0);
  const lastViolationEpochRef = useRef<number>(0);

  const isEligibleForHealthTimers =
    student.current_state === 'FREE_TIME' ||
    student.current_state === 'COMPUTER_STUDY';

  // Background 20-minute (20-20-20 Eye Shield) & 60-minute (Water Break) Timers
  useEffect(() => {
    if (!isEligibleForHealthTimers) return;

    const eyeInterval = setInterval(() => {
      setEyeBreakRemaining(20);
    }, 20 * 60 * 1000); // Every 20 minutes

    const waterInterval = setInterval(() => {
      setShowWaterBreakPrompt(true);
    }, 60 * 60 * 1000); // Every 60 minutes

    return () => {
      clearInterval(eyeInterval);
      clearInterval(waterInterval);
    };
  }, [isEligibleForHealthTimers]);

  // 20-second countdown for the 20-20-20 Eye & Posture Shield
  useEffect(() => {
    if (eyeBreakRemaining <= 0) return;

    const timer = setInterval(() => {
      setEyeBreakRemaining((prev) => {
        if (prev <= 1) {
          awardHealthPoints(
            student.id,
            2,
            '👀 20-20-20 Göz ve Duruş Kalkanı tamamlandı (+2 Sağlık Puanı)!'
          );
          setHealthToast('👀 Harika! Gözlerini dinlendirdin ve +2 Sağlık Puanı kazandın!');
          setTimeout(() => setHealthToast(null), 4000);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [eyeBreakRemaining, awardHealthPoints, student.id]);

  // Web Audio API Decibel Meter (AnalyserNode - NO MediaRecorder, NO audio saved)
  // ÇAKIŞMA ÖNLEYİCİ KURAL: Windows Masaüstü Ajanı (FamilyOS-Windows-Agent) içinde
  // çalışırken tarayıcı içi Web Audio mikrofonu devre dışı bırakılır.
  const startDecibelSensor = async () => {
    if (
      isWindowsAgent ||
      typeof window === 'undefined' ||
      !navigator.mediaDevices?.getUserMedia
    ) {
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: false,
          autoGainControl: false,
        },
        video: false,
      });
      streamRef.current = stream;

      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext })
          .webkitAudioContext;
      const ctx = new AudioCtx();
      audioCtxRef.current = ctx;

      const source = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.75;
      source.connect(analyser);
      analyserRef.current = analyser;
      setMicActive(true);

      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      const measureLoop = () => {
        if (!analyserRef.current) return;
        analyserRef.current.getByteTimeDomainData(dataArray);
        let sumSquares = 0;
        for (let i = 0; i < dataArray.length; i++) {
          const normalized = (dataArray[i] - 128) / 128;
          sumSquares += normalized * normalized;
        }
        const rms = Math.sqrt(sumSquares / dataArray.length);
        // Convert RMS amplitude to approximate SPL dB range (35 dB quiet room .. 95 dB shouting)
        const estimatedDb = Math.min(
          98,
          Math.max(35, Math.round(38 + rms * 145))
        );
        setCurrentDb(estimatedDb);
        animFrameRef.current = requestAnimationFrame(measureLoop);
      };
      animFrameRef.current = requestAnimationFrame(measureLoop);
    } catch {
      setMicActive(false);
    }
  };

  const stopDecibelSensor = () => {
    if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    if (audioCtxRef.current) {
      audioCtxRef.current.close().catch(() => {});
      audioCtxRef.current = null;
    }
    analyserRef.current = null;
    setMicActive(false);
  };

  useEffect(() => {
    return () => {
      stopDecibelSensor();
    };
  }, []);

  // 1-second check for sustained high noise (> noise_threshold_db for 8 seconds)
  useEffect(() => {
    if (
      student.current_state !== 'FREE_TIME' &&
      student.current_state !== 'STUDY_TIME' &&
      student.current_state !== 'COMPUTER_STUDY'
    ) {
      return;
    }

    const secTimer = setInterval(() => {
      if (currentDb >= noiseThresholdDb) {
        loudSecRef.current += 1;
        setLoudSecondsCount(loudSecRef.current);

        if (loudSecRef.current >= 8) {
          setShowNoiseCalmingBanner(true);
        }
        // If high noise continues to 11+ seconds, log `high_noise_detected` (30s cooldown)
        if (
          loudSecRef.current >= 11 &&
          Date.now() - lastViolationEpochRef.current > 30000
        ) {
          lastViolationEpochRef.current = Date.now();
          recordViolation(
            student.id,
            'high_noise_detected',
            `${currentDb} dB Ses Seviyesi`
          );
        }
      } else {
        loudSecRef.current = Math.max(0, loudSecRef.current - 1);
        setLoudSecondsCount(loudSecRef.current);
        if (loudSecRef.current === 0) {
          setShowNoiseCalmingBanner(false);
        }
      }
    }, 1000);

    return () => clearInterval(secTimer);
  }, [currentDb, noiseThresholdDb, recordViolation, student.current_state, student.id]);

  const handleClaimWaterPoints = async () => {
    setShowWaterBreakPrompt(false);
    await awardHealthPoints(
      student.id,
      5,
      '💧 Su İçme Molası tamamlandı! 1 bardak su içildi (+5 Puan)!'
    );
    setHealthToast('💧 Afiyet olsun! 1 bardak su içtin ve +5 Puan kazandın!');
    setTimeout(() => setHealthToast(null), 4000);
  };

  const handleSimulateHighNoise = () => {
    setCurrentDb(noiseThresholdDb + 10);
    loudSecRef.current = 8;
    setLoudSecondsCount(8);
    setShowNoiseCalmingBanner(true);
  };

  return (
    <div className="space-y-3">
      {/* 1. Top-Center 20-20-20 Eye & Posture Shield Overlay (20 Seconds) */}
      <AnimatePresence>
        {eyeBreakRemaining > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -25, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -25 }}
            className="fixed top-5 left-1/2 -translate-x-1/2 z-50 w-[92%] max-w-xl bg-slate-950/95 backdrop-blur-xl border-2 border-cyan-400 rounded-3xl p-5 shadow-2xl text-center space-y-3"
          >
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-500/20 text-cyan-300 text-xs font-black">
              <Eye className="w-4 h-4 animate-pulse" />
              <span>20-20-20 GÖZ VE DURUŞ KALKANI</span>
            </div>
            <h3 className="text-lg sm:text-xl font-black text-white">
              👀 Gözlerini Koruma Zamanı! Şimdi 20 saniye boyunca pencereden uzağa bak ve omuzlarını dikleştir!
            </h3>
            <div className="flex items-center justify-center gap-3">
              <div className="px-5 py-2 rounded-2xl bg-cyan-500 text-slate-950 font-mono font-black text-2xl">
                {eyeBreakRemaining} sn
              </div>
              <span className="text-xs font-bold text-emerald-300">
                Bitince otomatik kapanır ve +2 Sağlık Puanı verir! 💚
              </span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* 2. Water Break Prompt Banner (Every 60 mins or on trigger) */}
      <AnimatePresence>
        {showWaterBreakPrompt && (
          <motion.div
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.96 }}
            className="bg-gradient-to-r from-sky-900/90 via-cyan-900/90 to-blue-900/90 border-2 border-sky-400 rounded-3xl p-4 flex flex-wrap items-center justify-between gap-3 shadow-xl"
          >
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-sky-400 text-slate-950 flex items-center justify-center text-2xl font-black">
                💧
              </div>
              <div>
                <h4 className="text-sm sm:text-base font-black text-white">
                  💧 Su Molası! 1 bardak su içip gelene anında +5 Puan!
                </h4>
                <p className="text-xs text-sky-200">
                  Beyninin ve Dijital Yoldaşının yüksek enerjiyle çalışması için su içmeyi unutma!
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={handleClaimWaterPoints}
                className="px-4 py-2.5 rounded-2xl bg-sky-400 hover:bg-sky-300 text-slate-950 font-black text-xs transition shadow-lg"
              >
                💧 1 Bardak Suyumu İçtim (+5 Puan Al)
              </button>
              <button
                type="button"
                onClick={() => setShowWaterBreakPrompt(false)}
                className="px-3 py-2 rounded-xl bg-slate-900/80 text-slate-300 text-xs font-bold"
              >
                Sonra
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* 3. Full-Width Calming Noise Warning Banner (>75 dB for 8s) */}
      <AnimatePresence>
        {showNoiseCalmingBanner && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="w-full bg-gradient-to-r from-rose-900/95 via-amber-900/95 to-rose-900/95 border-2 border-amber-400 rounded-3xl p-4 flex flex-wrap items-center justify-between gap-3 shadow-2xl"
          >
            <div className="flex items-center gap-3">
              <Volume2 className="w-8 h-8 text-amber-300 animate-bounce shrink-0" />
              <div>
                <div className="text-sm sm:text-base font-black text-white">
                  🔊 Hop! Ses seviyesi çok yükseldi ({currentDb} dB), biraz daha sakin konuşalım :)
                </div>
                <p className="text-xs text-amber-200">
                  Yüksek ses 3 saniye daha devam ederse kalkan ihlali (high_noise_detected) olarak ebeveyne bildirilir.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => {
                loudSecRef.current = 0;
                setLoudSecondsCount(0);
                setCurrentDb(45);
                setShowNoiseCalmingBanner(false);
              }}
              className="px-4 py-2 rounded-xl bg-emerald-400 text-slate-950 font-black text-xs"
            >
              🤫 Tamam, Sakinleştik
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {healthToast && (
        <div className="bg-emerald-500/20 border border-emerald-400 text-emerald-200 font-bold text-xs px-4 py-2.5 rounded-2xl">
          {healthToast}
        </div>
      )}

      {/* Compact Health & Ambient Decibel Sensor Bar */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-2xl px-4 py-2.5 flex flex-wrap items-center justify-between gap-3 text-xs">
        <div className="flex flex-wrap items-center gap-3">
          <span className="font-black text-cyan-300 flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-amber-400" />
            Sağlık & Ortam Sensörü:
          </span>

          <button
            type="button"
            onClick={() => setEyeBreakRemaining(20)}
            className="px-2.5 py-1 rounded-xl bg-cyan-500/15 hover:bg-cyan-500/25 border border-cyan-500/30 text-cyan-200 font-bold flex items-center gap-1 transition"
          >
            <Eye className="w-3.5 h-3.5" />
            <span>👀 20-20-20 Göz Kalkanı Başlat (+2 P)</span>
          </button>

          <button
            type="button"
            onClick={() => setShowWaterBreakPrompt(true)}
            className="px-2.5 py-1 rounded-xl bg-sky-500/15 hover:bg-sky-500/25 border border-sky-500/30 text-sky-200 font-bold flex items-center gap-1 transition"
          >
            <Droplets className="w-3.5 h-3.5" />
            <span>💧 Su Molası (+5 P)</span>
          </button>
        </div>

        {/* Web Audio Decibel Meter Controls (No recording, amplitude only) */}
        <div className="flex flex-wrap items-center gap-2">
          <span
            className={`px-2.5 py-1 rounded-xl font-mono font-bold border ${
              currentDb >= noiseThresholdDb
                ? 'bg-rose-500/20 border-rose-400 text-rose-300 animate-pulse'
                : 'bg-slate-950 border-slate-800 text-emerald-300'
            }`}
          >
            🔊 {currentDb} dB / Sınır: {noiseThresholdDb} dB
            {loudSecondsCount > 0 ? ` (${loudSecondsCount}/8sn)` : ''}
          </span>

          {isWindowsAgent ? (
            <span className="px-2.5 py-1 rounded-xl font-bold border bg-indigo-500/20 border-indigo-400/40 text-indigo-200 flex items-center gap-1">
              <MicOff className="w-3.5 h-3.5" />
              <span>🖥️ Windows Ajanı Donanımsal dB Sensörü Aktif</span>
            </span>
          ) : (
            <button
              type="button"
              onClick={micActive ? stopDecibelSensor : startDecibelSensor}
              className={`px-2.5 py-1 rounded-xl font-bold flex items-center gap-1 border transition ${
                micActive
                  ? 'bg-emerald-500/20 border-emerald-400/40 text-emerald-300'
                  : 'bg-slate-800 border-slate-700 text-slate-300 hover:text-white'
              }`}
              title="Kesinlikle ses kaydı almaz; yalnızca Web Audio AnalyserNode ile anlık dB genliğini ölçer"
            >
              {micActive ? (
                <>
                  <Mic className="w-3.5 h-3.5" />
                  <span>dB Sensörü Açık</span>
                </>
              ) : (
                <>
                  <MicOff className="w-3.5 h-3.5" />
                  <span>dB Ölçeri Aç</span>
                </>
              )}
            </button>
          )}

          <button
            type="button"
            onClick={handleSimulateHighNoise}
            className="px-2 py-1 rounded-lg bg-amber-500/15 hover:bg-amber-500/25 border border-amber-400/30 text-amber-300 font-bold text-[11px]"
          >
            🧪 Gürültü Testi
          </button>
        </div>
      </div>
    </div>
  );
};
