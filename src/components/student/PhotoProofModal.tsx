'use client';

import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Camera,
  Upload,
  CheckCircle2,
  X,
  Trash2,
  Music,
  Sparkles,
  Play,
  FastForward,
  Eye,
  KeyRound,
  ShieldCheck,
} from 'lucide-react';
import { TaskItem, TaskSubmissionMethod } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { soundEngine } from '@/lib/soundEngine';
import { QRScannerBox } from '@/components/shared/QRCodeScannerAndPrint';
import { useDesktopBridge } from '@/lib/useDesktopBridge';

interface PhotoProofModalProps {
  task: TaskItem;
  studentId: string;
  onClose: () => void;
  autoStartBrush?: boolean;
}

const SAMPLE_PROOF_PHOTOS = [
  'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=600&q=80',
  'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=600&q=80',
];

export const PhotoProofModal: React.FC<PhotoProofModalProps> = ({
  task,
  studentId,
  onClose,
  autoStartBrush = false,
}) => {
  const {
    submissions,
    qrStations,
    submitTaskCompletion,
    approveTaskOnSpotWithPin,
  } = useFamilyRealtime();

  useDesktopBridge(true);

  const existingPendingSub = submissions.find(
    (s) =>
      s.task_id === task.id &&
      s.user_id === studentId &&
      s.status === 'pending'
  );

  const [photos, setPhotos] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [createdSubmissionId, setCreatedSubmissionId] = useState<string | null>(
    existingPendingSub?.id || null
  );
  const [parentPin, setParentPin] = useState('');
  const [pinFeedback, setPinFeedback] = useState<{
    ok: boolean;
    text: string;
  } | null>(null);

  // 2-Minute Musical Toothbrush Timer State
  const isToothbrushTask =
    task.id.includes('tooth') || task.title.toLowerCase().includes('diş');
  const [brushSecondsLeft, setBrushSecondsLeft] = useState(120);
  const [isBrushing, setIsBrushing] = useState(Boolean(autoStartBrush));

  const isDirectSubmit = task.verification_type === 'direct_submit';
  const isQrScanTask = task.verification_type === 'qr_scan';
  const targetQrStation =
    qrStations.find((q) => q.id === task.required_qr_station_id) ||
    qrStations.find((q) => q.linked_action === 'complete_task') ||
    qrStations[0];

  useEffect(() => {
    if (!isBrushing) {
      soundEngine.stopToothbrushMusic();
      return;
    }
    soundEngine.startToothbrushMusic();
    const interval = setInterval(() => {
      setBrushSecondsLeft((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          setIsBrushing(false);
          soundEngine.stopToothbrushMusic();
          soundEngine.playVictoryFanfare();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      clearInterval(interval);
      soundEngine.stopToothbrushMusic();
    };
  }, [isBrushing]);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const files = e.target.files;
      if (!files) return;

      Array.from(files).forEach((file) => {
        const reader = new FileReader();
        reader.onload = () => {
          if (typeof reader.result === 'string') {
            setPhotos((prev) => [...prev, reader.result as string]);
          }
        };
        reader.readAsDataURL(file);
      });
    } catch (err) {
      console.error('[PhotoProofModal.handleFileUpload] Hata:', err);
    }
  };

  const handleInstantCameraCapture = () => {
    const nextPhoto =
      SAMPLE_PROOF_PHOTOS[photos.length % SAMPLE_PROOF_PHOTOS.length];
    setPhotos((prev) => [...prev, nextPhoto]);
  };

  const removePhoto = (index: number) => {
    setPhotos((prev) => prev.filter((_, idx) => idx !== index));
  };

  const handleFlexibleSubmit = async (method: TaskSubmissionMethod) => {
    try {
      setIsSubmitting(true);
      soundEngine.stopToothbrushMusic();

      const res = await submitTaskCompletion(
        task.id,
        studentId,
        method === 'photo_uploaded' ? photos : [],
        method
      );

      confetti({
        particleCount: 90,
        spread: 70,
        origin: { y: 0.6 },
      });

      setIsSubmitting(false);

      // Eğer fiziksel kontrol için ebeveyn çağrıldıysa, yerinde PIN onay ekranını göster
      if (method === 'called_parent_for_check' && !res.autoApproved) {
        setCreatedSubmissionId(res.submissionId);
        return;
      }

      onClose();
    } catch (err) {
      console.error('[PhotoProofModal.handleFlexibleSubmit] Hata:', err);
      setIsSubmitting(false);
    }
  };

  const handleOnSpotPinApproval = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createdSubmissionId || !parentPin.trim()) return;
    try {
      const res = await approveTaskOnSpotWithPin(
        createdSubmissionId,
        parentPin.trim()
      );
      setPinFeedback({ ok: res.success, text: res.message });
      if (res.success) {
        confetti({
          particleCount: 120,
          spread: 85,
          origin: { y: 0.5 },
        });
        setTimeout(() => {
          onClose();
        }, 1400);
      }
    } catch (err) {
      console.error('[PhotoProofModal.handleOnSpotPinApproval] Hata:', err);
    }
  };

  return (
    <div
      data-allow-touch="true"
      className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4 overflow-y-auto"
    >
      <motion.div
        initial={{ scale: 0.9, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        className="bg-slate-900 border border-indigo-500/40 rounded-3xl max-w-xl w-full p-6 text-white shadow-2xl relative my-auto"
      >
        <button
          type="button"
          onClick={() => {
            soundEngine.stopToothbrushMusic();
            onClose();
          }}
          className="absolute top-4 right-4 p-2 rounded-full bg-slate-800 hover:bg-slate-700 text-slate-300"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-indigo-500/20 text-indigo-300 text-xs font-bold mb-2">
          <Sparkles className="w-3.5 h-3.5" />
          <span>+{task.points} Puan Değerinde Görev</span>
        </div>

        <h2 className="text-xl font-extrabold mb-1">{task.title}</h2>
        <p className="text-xs sm:text-sm text-slate-300 mb-5">
          {task.description}
        </p>

        {/* EĞER FİZİKSEL KONTROL ÇAĞRISI YAPILDIYSA: YERİNDE EBEVEYN PIN ONAYI EKRANI */}
        {createdSubmissionId ? (
          <div className="bg-gradient-to-br from-emerald-950/90 via-slate-900 to-indigo-950 border-2 border-emerald-400/50 rounded-2xl p-5 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 border border-emerald-400/40 flex items-center justify-center text-2xl shrink-0">
                🏃‍♂️
              </div>
              <div>
                <h3 className="text-base font-black text-emerald-300">
                  Anne ve Babana Haber Verildi!
                </h3>
                <p className="text-xs text-slate-300">
                  Ebeveynin kendi telefonundan onaylayabilir veya yanına geldiğinde
                  aşağıdaki kutuya <strong>Ebeveyn PIN</strong> kodunu girerek
                  anında onaylayabilir!
                </p>
              </div>
            </div>

            <form
              onSubmit={handleOnSpotPinApproval}
              className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-3"
            >
              <label className="block text-xs font-extrabold text-amber-300 uppercase tracking-wider flex items-center gap-1.5">
                <KeyRound className="w-4 h-4" />
                <span>Yanımdaki Ebeveyn Hızlı PIN Onayı (Demo PIN: 1923)</span>
              </label>

              <div className="flex items-center gap-2">
                <input
                  type="password"
                  maxLength={6}
                  value={parentPin}
                  onChange={(e) => setParentPin(e.target.value)}
                  placeholder="4 Haneli PIN (1923)"
                  className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-4 py-2.5 text-center font-mono text-base font-black tracking-widest text-white focus:outline-none focus:border-emerald-400"
                />
                <button
                  type="submit"
                  className="px-5 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs sm:text-sm flex items-center gap-1.5 shadow-lg transition"
                >
                  <ShieldCheck className="w-4 h-4" />
                  <span>Şimdi Onayla</span>
                </button>
              </div>

              {pinFeedback && (
                <div
                  className={`text-xs font-bold px-3 py-2 rounded-xl ${
                    pinFeedback.ok
                      ? 'bg-emerald-500/20 text-emerald-300'
                      : 'bg-rose-500/20 text-rose-300'
                  }`}
                >
                  {pinFeedback.text}
                </div>
              )}
            </form>

            <button
              type="button"
              onClick={onClose}
              className="w-full py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold text-xs transition"
            >
              Pencereyi Kapat (Ebeveynim Telefonundan Onaylayacak)
            </button>
          </div>
        ) : (
          <>
            {/* Special 2-Minute Animated Toothbrush Counter */}
            {isToothbrushTask && (
              <div className="bg-gradient-to-br from-cyan-950 to-indigo-950 border border-cyan-500/40 rounded-2xl p-5 mb-5 text-center">
                <div className="text-4xl mb-2 animate-bounce">🪥✨🫧</div>
                <div className="text-3xl font-black font-mono text-cyan-300 mb-1">
                  {String(Math.floor(brushSecondsLeft / 60)).padStart(2, '0')}:
                  {String(brushSecondsLeft % 60).padStart(2, '0')}
                </div>
                <p className="text-xs text-cyan-200 mb-4">
                  {isBrushing
                    ? '🎵 Müzikli fırçalama devam ediyor! Üst, alt ve arka dişleri unutma!'
                    : brushSecondsLeft === 0
                    ? 'Harika! 2 dakikalık fırçalama tamamlandı!'
                    : 'Sayacı başlat ve müzik eşliğinde 2 dakika dişlerini fırçala!'}
                </p>
                <div className="flex items-center justify-center gap-2">
                  {brushSecondsLeft > 0 && (
                    <button
                      type="button"
                      onClick={() => setIsBrushing((b) => !b)}
                      className="px-4 py-2 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs flex items-center gap-1.5 transition"
                    >
                      {isBrushing ? (
                        <>
                          <Music className="w-4 h-4 animate-spin" /> Duraklat
                        </>
                      ) : (
                        <>
                          <Play className="w-4 h-4" /> 2 Dk Müzikli Sayacı Başlat
                        </>
                      )}
                    </button>
                  )}
                  {brushSecondsLeft > 0 && (
                    <button
                      type="button"
                      onClick={() => {
                        setIsBrushing(false);
                        setBrushSecondsLeft(0);
                        soundEngine.playVictoryFanfare();
                      }}
                      title="Demo için sayacı hızlı bitir"
                      className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs flex items-center gap-1"
                    >
                      <FastForward className="w-3.5 h-3.5" /> Hızlı Tamamla
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* EĞER QR_SCAN GÖREVİ İSE FİZİKSEL QR OKUYUCUYU AÇ */}
            {isQrScanTask && targetQrStation && (
              <div className="mb-5">
                <QRScannerBox
                  expectedStation={targetQrStation}
                  onScanSuccess={() => handleFlexibleSubmit('qr_scanned')}
                  buttonLabel={`📷 "${targetQrStation.title}" QR Kodunu Okut ve Tamamla`}
                />
              </div>
            )}

            {/* ESNEK DOĞRULAMA: FOTOĞRAF YÜKLEME HER ZAMAN İSTEĞE BAĞLIDIR */}
            {!isDirectSubmit && !isQrScanTask && (
              <div className="mb-5 bg-slate-950/70 border border-slate-800 rounded-2xl p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-bold text-amber-300 uppercase tracking-wider">
                    📸 Seçenek 1: Fotoğraf Çek ve Gönder (İsteğe Bağlı)
                  </span>
                  <span className="text-xs text-slate-400">
                    {photos.length} Sayfa Eklendi
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 mb-3">
                  <label className="cursor-pointer flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg transition">
                    <Upload className="w-4 h-4" />
                    <span>Kamera Aç / Fotoğraf Seç</span>
                    <input
                      type="file"
                      accept="image/*"
                      multiple
                      capture="environment"
                      onChange={handleFileUpload}
                      className="hidden"
                    />
                  </label>

                  <button
                    type="button"
                    onClick={handleInstantCameraCapture}
                    className="flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 border border-amber-400/40 text-amber-300 font-bold text-xs transition"
                  >
                    <Camera className="w-4 h-4" />
                    <span>Anlık Örnek Sayfa Çek (+1)</span>
                  </button>
                </div>

                {photos.length > 0 ? (
                  <div className="grid grid-cols-3 gap-2 max-h-36 overflow-y-auto p-1 mb-3">
                    {photos.map((url, idx) => (
                      <div
                        key={idx}
                        className="relative group rounded-xl overflow-hidden border border-slate-700 aspect-video bg-slate-800"
                      >
                        <img
                          src={url}
                          alt={`Kanıt Sayfa ${idx + 1}`}
                          className="w-full h-full object-cover"
                        />
                        <div className="absolute bottom-1 left-1 bg-slate-950/80 text-[10px] px-1.5 py-0.5 rounded text-white font-bold">
                          Sayfa {idx + 1}
                        </div>
                        <button
                          type="button"
                          onClick={() => removePhoto(idx)}
                          className="absolute top-1 right-1 p-1 rounded-lg bg-rose-600 text-white opacity-90 hover:opacity-100"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-[11px] text-slate-400 mb-2">
                    İstersen ödev sayfalarının veya odanın fotoğrafını çekebilirsin.{' '}
                    <strong className="text-emerald-300">
                      Fotoğraf çekmek istemiyorsan aşağıdaki &ldquo;Annemi/Babamı Kontrole Çağır&rdquo; butonuna basman yeterli!
                    </strong>
                  </p>
                )}

                {photos.length > 0 && (
                  <button
                    type="button"
                    disabled={isSubmitting}
                    onClick={() => handleFlexibleSubmit('photo_uploaded')}
                    className="w-full py-3 rounded-xl bg-amber-400 hover:bg-amber-300 text-slate-950 font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-lg transition"
                  >
                    <Camera className="w-4 h-4" />
                    <span>
                      📸 Fotoğraf Çektim, Anne/Babama Gönder ({photos.length}{' '}
                      Fotoğraf)
                    </span>
                  </button>
                )}
              </div>
            )}

            {/* ANA TAMAMLAMA BUTONLARI (2 DOSTANE SEÇENEK VEYA DOĞRUDAN ONAY) */}
            {isQrScanTask ? null : isDirectSubmit ? (
              <button
                type="button"
                disabled={
                  isSubmitting || (isToothbrushTask && brushSecondsLeft > 0)
                }
                onClick={() => handleFlexibleSubmit('just_marked_done')}
                className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 disabled:opacity-40 disabled:cursor-not-allowed text-slate-950 font-black text-sm sm:text-base flex items-center justify-center gap-2 shadow-xl transition"
              >
                <CheckCircle2 className="w-5 h-5" />
                <span>Görevi Tamamladım! Puanımı Al 🎉</span>
              </button>
            ) : (
              <div className="space-y-2.5">
                <button
                  type="button"
                  disabled={isSubmitting}
                  onClick={() => handleFlexibleSubmit('called_parent_for_check')}
                  className="w-full py-3.5 px-4 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 disabled:opacity-40 text-slate-950 font-black text-sm sm:text-base flex items-center justify-center gap-2 shadow-xl transition"
                >
                  <Eye className="w-5 h-5" />
                  <span>👀 Tamamladım! (Annemi/Babamı Kontrole Çağır)</span>
                </button>
                <p className="text-[11px] text-center text-slate-400">
                  Bu butona bastığında annene ve babana{' '}
                  <strong className="text-emerald-300">
                    &ldquo;🏃‍♂️ Fiziksel Kontrol Zamanı! Yanına gidip kontrol etmenizi bekliyor!&rdquo;
                  </strong>{' '}
                  bildirimi gider.
                </p>
              </div>
            )}
          </>
        )}
      </motion.div>
    </div>
  );
};
