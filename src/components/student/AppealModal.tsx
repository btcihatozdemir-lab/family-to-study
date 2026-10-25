'use client';

import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Scale,
  Mic,
  Square,
  Send,
  X,
  ShieldCheck,
  AlertTriangle,
  Volume2,
  Sparkles,
  CheckCircle2,
} from 'lucide-react';
import { ViolationLog, TaskSubmission } from '@/types/database';
import { useDesktopBridge } from '@/lib/useDesktopBridge';
import { uploadAudioToSupabaseStorageOrDataUrl } from '@/lib/supabase';

interface AppealModalProps {
  isOpen: boolean;
  onClose: () => void;
  studentId: string;
  studentName: string;
  appealUsedToday?: boolean;
  latestViolation?: ViolationLog | null;
  rejectedSubmission?: TaskSubmission | null;
  onSubmitAppeal: (params: {
    studentId: string;
    violationId?: string | null;
    submissionId?: string | null;
    reasonText: string;
    audioUrl?: string | null;
  }) => Promise<{ success: boolean; message: string }>;
}

const QUICK_DEFENSE_REASONS = [
  '🖱️ Yanlışlıkla elim çarptı, hemen kapattım!',
  '🔊 Ben bağırmadım, odada kardeşim ses çıkardı!',
  '📚 Ödevimle ilgili öğretmenimizin verdiği kaynağı açmıştım.',
  '📸 Fotoğraf bulanık çıkmış ama ödevimi eksiksiz tamamladım!',
];

export const AppealModal: React.FC<AppealModalProps> = ({
  isOpen,
  onClose,
  studentId,
  studentName,
  appealUsedToday = false,
  latestViolation = null,
  rejectedSubmission = null,
  onSubmitAppeal,
}) => {
  const [reasonText, setReasonText] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [audioDataUrl, setAudioDataUrl] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<{
    type: 'success' | 'error';
    text: string;
  } | null>(null);

  useDesktopBridge(isOpen);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      if (
        mediaRecorderRef.current &&
        mediaRecorderRef.current.state !== 'inactive'
      ) {
        try {
          mediaRecorderRef.current.stop();
        } catch {
          // ignore cleanup stop errors
        }
      }
    };
  }, []);

  const startVoiceRecording = async () => {
    try {
      setFeedback(null);
      if (
        typeof navigator === 'undefined' ||
        !navigator.mediaDevices ||
        !navigator.mediaDevices.getUserMedia
      ) {
        setFeedback({
          type: 'error',
          text: 'Cihazında mikrofon erişimi desteklenmiyor. Lütfen yazılı savunma gönder.',
        });
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      audioChunksRef.current = [];

      recorder.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) {
          audioChunksRef.current.push(e.data);
        }
      };

      recorder.onstop = () => {
        stream.getTracks().forEach((track) => track.stop());
        const blob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
        const reader = new FileReader();
        reader.onloadend = async () => {
          if (typeof reader.result === 'string') {
            const finalUrl = await uploadAudioToSupabaseStorageOrDataUrl(
              blob,
              'appeals',
              reader.result
            );
            setAudioDataUrl(finalUrl);
          }
        };
        reader.readAsDataURL(blob);
      };

      mediaRecorderRef.current = recorder;
      recorder.start();
      setIsRecording(true);
      setRecordingSeconds(0);

      timerRef.current = setInterval(() => {
        setRecordingSeconds((prev) => {
          if (prev >= 14) {
            stopVoiceRecording();
            return 15;
          }
          return prev + 1;
        });
      }, 1000);
    } catch (err) {
      console.error('[AppealModal] Mikrofon hatası:', err);
      setFeedback({
        type: 'error',
        text: 'Mikrofon izni alınamadı. Savunmanı aşağıya yazarak gönderebilirsin.',
      });
    }
  };

  const stopVoiceRecording = () => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    if (
      mediaRecorderRef.current &&
      mediaRecorderRef.current.state !== 'inactive'
    ) {
      try {
        mediaRecorderRef.current.stop();
      } catch {
        // ignore
      }
    }
    setIsRecording(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (appealUsedToday) return;

    try {
      setSubmitting(true);
      setFeedback(null);
      const res = await onSubmitAppeal({
        studentId,
        violationId: latestViolation?.id || null,
        submissionId: rejectedSubmission?.id || null,
        reasonText,
        audioUrl: audioDataUrl,
      });

      if (res.success) {
        setFeedback({ type: 'success', text: res.message });
        setReasonText('');
        setAudioDataUrl(null);
        setTimeout(() => {
          onClose();
          setFeedback(null);
        }, 1800);
      } else {
        setFeedback({ type: 'error', text: res.message });
      }
    } catch (err) {
      console.error('[AppealModal] Gönderim hatası:', err);
      setFeedback({
        type: 'error',
        text: 'İtiraz gönderilirken beklenmeyen bir hata oluştu.',
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 backdrop-blur-md p-4"
        >
          <motion.div
            initial={{ scale: 0.92, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.92, y: 20 }}
            className="relative w-full max-w-lg rounded-3xl border border-amber-400/40 bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900 p-6 text-white shadow-2xl"
          >
            <button
              onClick={onClose}
              className="absolute right-4 top-4 rounded-full bg-white/10 p-2 text-slate-300 hover:bg-white/20 hover:text-white transition"
            >
              <X className="h-5 w-5" />
            </button>

            <div className="flex items-center gap-3 mb-4">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-400 to-orange-600 text-slate-950 shadow-lg shadow-amber-500/30">
                <Scale className="h-6 w-6" />
              </div>
              <div>
                <span className="inline-flex items-center gap-1 rounded-full bg-amber-500/20 px-2.5 py-0.5 text-[11px] font-bold text-amber-300 border border-amber-400/30">
                  ⚖️ ADALET DİVANI • GÜNDE 1 HAK
                </span>
                <h3 className="text-xl font-black tracking-tight text-white">
                  Hakem Heyetine İtiraz Et
                </h3>
              </div>
            </div>

            {latestViolation && (
              <div className="mb-4 rounded-2xl border border-rose-500/30 bg-rose-950/40 p-3.5 text-xs text-rose-200">
                <div className="flex items-center gap-2 font-bold text-rose-300 mb-1">
                  <AlertTriangle className="h-4 w-4 shrink-0" />
                  <span>İtiraz Edilen Son Kalkan Kırılması:</span>
                </div>
                <p className="text-rose-100/90">
                  {latestViolation.violation_type} ({latestViolation.device_id})
                </p>
              </div>
            )}

            {appealUsedToday ? (
              <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-center">
                <p className="text-sm font-bold text-amber-200">
                  ⚖️ Bugünkü 1 kez Hakem Heyetine İtiraz hakkını zaten kullandın!
                </p>
                <p className="mt-1 text-xs text-slate-300">
                  Anne ve baban savunmanı incelediğinde bildirim alacaksın.
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-2">
                    Hızlı Savunma Seçenekleri ({studentName}):
                  </label>
                  <div className="flex flex-wrap gap-1.5">
                    {QUICK_DEFENSE_REASONS.map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() => setReasonText(preset)}
                        className="rounded-xl border border-white/15 bg-white/5 px-2.5 py-1.5 text-left text-xs text-slate-200 hover:border-amber-400/50 hover:bg-amber-500/15 transition"
                      >
                        {preset}
                      </button>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                    Savunma Açıklaman:
                  </label>
                  <textarea
                    rows={3}
                    value={reasonText}
                    onChange={(e) => setReasonText(e.target.value)}
                    placeholder="Neden haksız yere kalkanının kırıldığını veya görevinin reddedildiğini kibarca açıkla..."
                    className="w-full rounded-2xl border border-white/15 bg-slate-950/70 p-3 text-sm text-white placeholder-slate-400 focus:border-amber-400 focus:outline-none"
                  />
                </div>

                {/* 15 Saniyelik Sesli Savunma Kaydedici */}
                <div className="rounded-2xl border border-indigo-400/30 bg-indigo-950/40 p-3.5">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-xs font-bold text-indigo-200">
                        🎙️ 15 Saniyelik Sesli Savunma (Opsiyonel)
                      </p>
                      <p className="text-[11px] text-slate-400">
                        Kendini sesinle ifade etmek istersen mikrofona bas.
                      </p>
                    </div>
                    {!isRecording ? (
                      <button
                        type="button"
                        onClick={startVoiceRecording}
                        className="flex items-center gap-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 px-3 py-2 text-xs font-bold text-white shadow-lg shadow-rose-600/30 transition"
                      >
                        <Mic className="h-4 w-4" />
                        <span>Ses Kaydet</span>
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={stopVoiceRecording}
                        className="flex items-center gap-1.5 rounded-xl bg-amber-500 hover:bg-amber-400 px-3 py-2 text-xs font-black text-slate-950 animate-pulse transition"
                      >
                        <Square className="h-4 w-4" />
                        <span>Durdur ({15 - recordingSeconds}sn)</span>
                      </button>
                    )}
                  </div>

                  {audioDataUrl && (
                    <div className="mt-3 flex items-center justify-between gap-2 rounded-xl bg-slate-900/80 p-2 border border-emerald-400/30">
                      <div className="flex items-center gap-2 text-xs text-emerald-300 font-semibold">
                        <Volume2 className="h-4 w-4 shrink-0" />
                        <span>Sesli savunman hazır!</span>
                      </div>
                      <audio
                        src={audioDataUrl}
                        controls
                        className="h-8 max-w-[200px]"
                      />
                      <button
                        type="button"
                        onClick={() => setAudioDataUrl(null)}
                        className="text-[11px] text-rose-300 hover:text-rose-200 underline px-1"
                      >
                        Sil
                      </button>
                    </div>
                  )}
                </div>

                {feedback && (
                  <div
                    className={`rounded-2xl p-3 text-xs font-bold ${
                      feedback.type === 'success'
                        ? 'bg-emerald-500/20 text-emerald-200 border border-emerald-400/40'
                        : 'bg-rose-500/20 text-rose-200 border border-rose-400/40'
                    }`}
                  >
                    {feedback.text}
                  </div>
                )}

                <div className="flex items-center justify-end gap-2 pt-2">
                  <button
                    type="button"
                    onClick={onClose}
                    className="rounded-xl bg-white/10 px-4 py-2.5 text-xs font-bold text-slate-300 hover:bg-white/15"
                  >
                    Vazgeç
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-amber-400 to-orange-500 px-5 py-2.5 text-xs font-black text-slate-950 shadow-lg shadow-amber-500/25 hover:brightness-110 disabled:opacity-50 transition"
                  >
                    <Send className="h-4 w-4" />
                    <span>
                      {submitting
                        ? 'Hakem Heyetine İletiliyor...'
                        : '⚖️ Savunmamı Gönder'}
                    </span>
                  </button>
                </div>
              </form>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

interface ShieldRestoredCelebrationProps {
  isVisible: boolean;
  studentName: string;
  onDismiss: () => void;
}

export const ShieldRestoredCelebrationModal: React.FC<
  ShieldRestoredCelebrationProps
> = ({ isVisible, studentName, onDismiss }) => {
  useEffect(() => {
    if (isVisible && typeof window !== 'undefined') {
      try {
        confetti({
          particleCount: 90,
          spread: 75,
          origin: { y: 0.6 },
        });
      } catch {
        // ignore confetti error
      }
    }
  }, [isVisible]);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 backdrop-blur-md p-4"
        >
          <motion.div
            initial={{ scale: 0.7, rotate: -4 }}
            animate={{ scale: 1, rotate: 0 }}
            exit={{ scale: 0.8, opacity: 0 }}
            className="relative max-w-md w-full rounded-3xl border-2 border-emerald-400 bg-gradient-to-br from-emerald-950 via-slate-900 to-teal-950 p-6 text-center text-white shadow-[0_0_60px_rgba(16,185,129,0.5)]"
          >
            <motion.div
              animate={{
                scale: [1, 1.18, 1],
                rotate: [0, 8, -8, 0],
              }}
              transition={{ duration: 1.6, repeat: Infinity }}
              className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-3xl bg-gradient-to-br from-emerald-400 to-teal-500 text-slate-950 shadow-2xl shadow-emerald-400/50"
            >
              <ShieldCheck className="h-12 w-12" />
            </motion.div>

            <div className="inline-flex items-center gap-1 rounded-full bg-emerald-400/20 px-3 py-1 text-xs font-black text-emerald-300 border border-emerald-400/40 mb-2">
              <Sparkles className="h-3.5 w-3.5" />
              <span>ADALET DİVANI KARARI: HAKLI BULUNDUN!</span>
            </div>

            <h3 className="text-2xl font-black text-white mb-2">
              🛡️ Kalkanın Parlayarak Tamir Edildi!
            </h3>
            <p className="text-sm text-emerald-100/90 mb-5">
              Tebrikler <strong>{studentName}</strong>! Anne/Baban savunmanı
              dinledi ve seni haklı buldu. Kırılan kalkanın geri yüklendi{' '}
              <strong>(+1 🛡️)</strong> ve <strong>+10 Adalet Puanı</strong>{' '}
              hesabına eklendi!
            </p>

            <button
              onClick={onDismiss}
              className="inline-flex items-center justify-center gap-2 w-full rounded-2xl bg-gradient-to-r from-emerald-400 to-teal-400 py-3 text-sm font-black text-slate-950 shadow-lg shadow-emerald-500/30 hover:brightness-110 transition"
            >
              <CheckCircle2 className="h-5 w-5" />
              <span>Harika! Teşekkürler!</span>
            </button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};
