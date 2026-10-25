'use client';

import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Mic,
  Square,
  Radio,
  Sparkles,
  RefreshCw,
  Send,
  X,
  Volume2,
  Heart,
} from 'lucide-react';
import { useDesktopBridge } from '@/lib/useDesktopBridge';
import { uploadAudioToSupabaseStorageOrDataUrl } from '@/lib/supabase';

interface WeeklyInterviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  studentId: string;
  studentName: string;
  onSaveInterview: (params: {
    studentId: string;
    questionText: string;
    audioUrl?: string | null;
    answerNote?: string | null;
  }) => Promise<{ success: boolean; message: string }>;
}

const PEDAGOGICAL_QUESTIONS = [
  'Bu hafta seni en çok ne güldürdü?',
  'Bu hafta başardığın en zor şey neydi?',
  'Gelecek hafta hangi konuda süper güç kazanmak isterdin?',
  'Bu hafta ailenden veya arkadaşlarından kime teşekkür etmek istersin ve neden?',
  'Bu hafta öğrendiğin en ilginç bilgi neydi?',
];

export const WeeklyInterviewModal: React.FC<WeeklyInterviewModalProps> = ({
  isOpen,
  onClose,
  studentId,
  studentName,
  onSaveInterview,
}) => {
  const [questionIndex, setQuestionIndex] = useState(0);
  const [answerNote, setAnswerNote] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [audioDataUrl, setAudioDataUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
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
          // ignore
        }
      }
    };
  }, []);

  const currentQuestion = PEDAGOGICAL_QUESTIONS[questionIndex];

  const cycleQuestion = () => {
    setQuestionIndex((prev) => (prev + 1) % PEDAGOGICAL_QUESTIONS.length);
  };

  const startRecording = async () => {
    try {
      setFeedback(null);
      if (
        typeof navigator === 'undefined' ||
        !navigator.mediaDevices ||
        !navigator.mediaDevices.getUserMedia
      ) {
        setFeedback({
          type: 'error',
          text: 'Cihazında mikrofon erişimi desteklenmiyor. Cevabını aşağıya yazılı olarak kaydedebilirsin.',
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
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
        const reader = new FileReader();
        reader.onloadend = async () => {
          if (typeof reader.result === 'string') {
            const finalUrl = await uploadAudioToSupabaseStorageOrDataUrl(
              blob,
              'weekly-interviews',
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
          if (prev >= 29) {
            stopRecording();
            return 30;
          }
          return prev + 1;
        });
      }, 1000);
    } catch (err) {
      console.error('[WeeklyInterviewModal] Mikrofon hatası:', err);
      setFeedback({
        type: 'error',
        text: 'Mikrofon izni alınamadı. Cevabını aşağıya not olarak yazabilirsin.',
      });
    }
  };

  const stopRecording = () => {
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
    try {
      setSaving(true);
      setFeedback(null);
      const res = await onSaveInterview({
        studentId,
        questionText: currentQuestion,
        audioUrl: audioDataUrl,
        answerNote,
      });

      if (res.success) {
        if (typeof window !== 'undefined') {
          try {
            confetti({
              particleCount: 70,
              spread: 70,
              origin: { y: 0.6 },
            });
          } catch {
            // ignore
          }
        }
        setFeedback({ type: 'success', text: res.message });
        setAnswerNote('');
        setAudioDataUrl(null);
        setTimeout(() => {
          onClose();
          setFeedback(null);
        }, 1800);
      } else {
        setFeedback({ type: 'error', text: res.message });
      }
    } catch (err) {
      console.error('[WeeklyInterviewModal] Hata:', err);
      setFeedback({
        type: 'error',
        text: 'Zaman kapsülü kaydedilirken bir hata oluştu.',
      });
    } finally {
      setSaving(false);
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
            className="relative w-full max-w-lg rounded-3xl border border-fuchsia-400/40 bg-gradient-to-br from-slate-900 via-fuchsia-950/70 to-indigo-950 p-6 text-white shadow-2xl"
          >
            <button
              onClick={onClose}
              className="absolute right-4 top-4 rounded-full bg-white/10 p-2 text-slate-300 hover:bg-white/20 hover:text-white transition"
            >
              <X className="h-5 w-5" />
            </button>

            <div className="flex items-center gap-3 mb-4">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-fuchsia-400 to-rose-500 text-slate-950 shadow-lg shadow-fuchsia-500/30">
                <Radio className="h-6 w-6" />
              </div>
              <div>
                <span className="inline-flex items-center gap-1 rounded-full bg-fuchsia-500/20 px-2.5 py-0.5 text-[11px] font-bold text-fuchsia-300 border border-fuchsia-400/30">
                  <Sparkles className="h-3 w-3" />
                  PAZAR RÖPORTAJI • +15 HATIRA PUANI
                </span>
                <h3 className="text-xl font-black tracking-tight text-white">
                  🎙️ Haftanın Röportajı (Zaman Kapsülü)
                </h3>
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Pedagojik Soru Kartı */}
              <div className="rounded-2xl border border-fuchsia-400/35 bg-slate-950/60 p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-[11px] font-bold uppercase tracking-wider text-fuchsia-300">
                    {studentName} İçin Haftanın Sorusu:
                  </span>
                  <button
                    type="button"
                    onClick={cycleQuestion}
                    className="inline-flex items-center gap-1 rounded-lg bg-white/10 px-2.5 py-1 text-[11px] font-bold text-fuchsia-200 hover:bg-white/20 transition"
                  >
                    <RefreshCw className="h-3 w-3" />
                    <span>Başka Soru Seç</span>
                  </button>
                </div>
                <p className="text-base font-black text-white leading-snug">
                  “{currentQuestion}”
                </p>
              </div>

              {/* 15-30 Saniyelik Sesli Anı Kaydedici */}
              <div className="rounded-2xl border border-rose-400/30 bg-rose-950/30 p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-extrabold text-rose-200">
                      🎙️ 15-30 Saniyelik Sesli Anı Kaydı
                    </p>
                    <p className="text-[11px] text-slate-300">
                      Yıllar sonra dinlediğinde yüzünü güldürecek sesini kaydet!
                    </p>
                  </div>
                  {!isRecording ? (
                    <button
                      type="button"
                      onClick={startRecording}
                      className="flex items-center gap-1.5 rounded-xl bg-gradient-to-r from-rose-500 to-fuchsia-600 px-3.5 py-2.5 text-xs font-black text-white shadow-lg shadow-rose-500/30 hover:brightness-110 transition"
                    >
                      <Mic className="h-4 w-4" />
                      <span>Kayda Başla</span>
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={stopRecording}
                      className="flex items-center gap-1.5 rounded-xl bg-amber-400 px-3.5 py-2.5 text-xs font-black text-slate-950 animate-pulse transition"
                    >
                      <Square className="h-4 w-4" />
                      <span>Durdur ({30 - recordingSeconds}sn)</span>
                    </button>
                  )}
                </div>

                {audioDataUrl && (
                  <div className="mt-3 flex items-center justify-between gap-2 rounded-xl bg-slate-900/90 p-2.5 border border-emerald-400/40">
                    <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-300">
                      <Volume2 className="h-4 w-4 shrink-0" />
                      <span>Ses kaydın hazır!</span>
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

              {/* Yazılı Hatıra Notu */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                  Hatıra Özeti / Yazılı Cevabın:
                </label>
                <textarea
                  rows={3}
                  value={answerNote}
                  onChange={(e) => setAnswerNote(e.target.value)}
                  placeholder="Cevabını buraya da yazabilirsin; Aile Başarı & Anı Albümünde saklanacak..."
                  className="w-full rounded-2xl border border-white/15 bg-slate-950/70 p-3 text-sm text-white placeholder-slate-400 focus:border-fuchsia-400 focus:outline-none"
                />
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

              <div className="flex items-center justify-between pt-2">
                <span className="inline-flex items-center gap-1 text-[11px] text-fuchsia-200">
                  <Heart className="h-3.5 w-3.5 text-rose-400" />
                  <span>📻 Sesli Anılarımız albümüne eklenir</span>
                </span>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={onClose}
                    className="rounded-xl bg-white/10 px-4 py-2.5 text-xs font-bold text-slate-300 hover:bg-white/15"
                  >
                    Kapat
                  </button>
                  <button
                    type="submit"
                    disabled={saving}
                    className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-fuchsia-400 to-rose-500 px-5 py-2.5 text-xs font-black text-slate-950 shadow-lg shadow-fuchsia-500/30 hover:brightness-110 disabled:opacity-50 transition"
                  >
                    <Send className="h-4 w-4" />
                    <span>
                      {saving
                        ? 'Kapsüle Ekleniyor...'
                        : '🎙️ Anı Kapsülüne Kaydet (+15 P)'}
                    </span>
                  </button>
                </div>
              </div>
            </form>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};
