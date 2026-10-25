'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Trophy,
  Film,
  X,
  ChevronLeft,
  ChevronRight,
  Sparkles,
  Award,
  Heart,
  Pause,
  Play,
  Radio,
  Volume2,
  Calendar,
} from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { useDesktopBridge } from '@/lib/useDesktopBridge';

interface SuccessAlbumModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SuccessAlbumModal: React.FC<SuccessAlbumModalProps> = ({
  isOpen,
  onClose,
}) => {
  const { activeFamily, users, tasks, submissions, weeklyInterviews } =
    useFamilyRealtime();

  useDesktopBridge(isOpen);

  const [activeTab, setActiveTab] = useState<'photos' | 'audio_memories'>(
    'photos'
  );
  const [isSlideshowActive, setIsSlideshowActive] = useState(false);
  const [slideIndex, setSlideIndex] = useState(0);
  const musicTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);

  const featuredSubmissions = useMemo(() => {
    const featured = submissions.filter(
      (s) =>
        s.status === 'approved' &&
        (s.is_featured_in_album || (s.photo_urls && s.photo_urls.length > 0))
    );
    return featured;
  }, [submissions]);

  const childrenUsers = useMemo(
    () => users.filter((u) => u.role === 'child'),
    [users]
  );

  // Cheerful synthesized Web Audio API background melody for Movie Night Slideshow
  const startCheerfulSlideshowMusic = () => {
    if (typeof window === 'undefined') return;
    try {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext })
          .webkitAudioContext;
      const ctx = new AudioCtx();
      audioCtxRef.current = ctx;

      const melodyNotes = [523.25, 659.25, 783.99, 1046.5, 783.99, 659.25];
      let noteIdx = 0;

      const playNote = () => {
        if (!audioCtxRef.current) return;
        try {
          const osc = audioCtxRef.current.createOscillator();
          const gain = audioCtxRef.current.createGain();
          osc.type = 'triangle';
          osc.frequency.setValueAtTime(
            melodyNotes[noteIdx % melodyNotes.length],
            audioCtxRef.current.currentTime
          );
          gain.gain.setValueAtTime(0.06, audioCtxRef.current.currentTime);
          gain.gain.exponentialRampToValueAtTime(
            0.001,
            audioCtxRef.current.currentTime + 0.55
          );
          osc.connect(gain);
          gain.connect(audioCtxRef.current.destination);
          osc.start();
          osc.stop(audioCtxRef.current.currentTime + 0.6);
          noteIdx += 1;
        } catch {}
      };

      playNote();
      musicTimerRef.current = setInterval(playNote, 650);
    } catch {}
  };

  const stopCheerfulSlideshowMusic = () => {
    if (musicTimerRef.current) {
      clearInterval(musicTimerRef.current);
      musicTimerRef.current = null;
    }
    if (audioCtxRef.current) {
      audioCtxRef.current.close().catch(() => {});
      audioCtxRef.current = null;
    }
  };

  useEffect(() => {
    if (!isSlideshowActive || featuredSubmissions.length === 0) {
      stopCheerfulSlideshowMusic();
      return;
    }

    startCheerfulSlideshowMusic();
    try {
      confetti({ particleCount: 90, spread: 75, origin: { y: 0.6 } });
    } catch {}

    const slideTimer = setInterval(() => {
      setSlideIndex((prev) => (prev + 1) % featuredSubmissions.length);
    }, 4500);

    return () => {
      clearInterval(slideTimer);
      stopCheerfulSlideshowMusic();
    };
  }, [isSlideshowActive, featuredSubmissions.length]);

  useEffect(() => {
    if (!isOpen) {
      setIsSlideshowActive(false);
      stopCheerfulSlideshowMusic();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const activeSlideSub =
    featuredSubmissions[slideIndex] || featuredSubmissions[0];
  const activeSlideChild = users.find((u) => u.id === activeSlideSub?.user_id);
  const activeSlideTask = tasks.find((t) => t.id === activeSlideSub?.task_id);
  const activeSlideParent = users.find(
    (u) => u.id === activeSlideSub?.approved_by
  );

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/90 backdrop-blur-xl flex items-center justify-center p-4 overflow-y-auto">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-5xl bg-gradient-to-b from-slate-900 via-indigo-950/90 to-slate-950 border-2 border-amber-400/50 rounded-3xl p-5 sm:p-7 shadow-2xl space-y-6 max-h-[92vh] overflow-y-auto"
      >
        {/* Top Header & "🎬 Film Gecesi Slayt Gösterisini Başlat" Button */}
        <div className="flex flex-wrap items-center justify-between gap-4 pb-4 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-amber-400 to-orange-500 text-slate-950 flex items-center justify-center shadow-lg">
              <Trophy className="w-7 h-7" />
            </div>
            <div>
              <div className="text-xs font-black text-amber-300 uppercase tracking-wider flex items-center gap-1">
                <Sparkles className="w-3.5 h-3.5" />
                <span>{activeFamily.name} • AYIN ŞAMPİYONLARI & GURUR TABLOSU</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-black text-white">
                🏆 Aile Başarı Albümü
              </h2>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            {featuredSubmissions.length > 0 && (
              <button
                type="button"
                onClick={() => {
                  setSlideIndex(0);
                  setIsSlideshowActive(!isSlideshowActive);
                }}
                className={`px-4 py-2.5 rounded-2xl font-black text-xs sm:text-sm flex items-center gap-2 shadow-xl transition ${
                  isSlideshowActive
                    ? 'bg-rose-500 text-white'
                    : 'bg-gradient-to-r from-amber-400 via-orange-400 to-pink-500 text-slate-950 hover:scale-105'
                }`}
              >
                {isSlideshowActive ? (
                  <>
                    <Pause className="w-4 h-4" />
                    <span>Slayt Gösterisini Durdur</span>
                  </>
                ) : (
                  <>
                    <Film className="w-4 h-4" />
                    <span>🎬 Film Gecesi Slayt Gösterisini Başlat</span>
                  </>
                )}
              </button>
            )}

            <button
              type="button"
              onClick={onClose}
              className="p-2.5 rounded-2xl bg-slate-800 hover:bg-slate-700 text-slate-300"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Phase 4 Tab Switcher: Başarı Fotoğrafları vs. 📻 Sesli Anılarımız (Zaman Kapsülü) */}
        <div className="flex flex-wrap items-center gap-2 border-b border-slate-800 pb-3">
          <button
            type="button"
            onClick={() => setActiveTab('photos')}
            className={`px-4 py-2 rounded-2xl text-xs sm:text-sm font-black flex items-center gap-2 transition ${
              activeTab === 'photos'
                ? 'bg-amber-400 text-slate-950 shadow-lg shadow-amber-500/20'
                : 'bg-slate-900 text-slate-300 hover:bg-slate-800 border border-slate-800'
            }`}
          >
            <Trophy className="w-4 h-4" />
            <span>🏆 Başarı Fotoğrafları ({featuredSubmissions.length})</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('audio_memories')}
            className={`px-4 py-2 rounded-2xl text-xs sm:text-sm font-black flex items-center gap-2 transition ${
              activeTab === 'audio_memories'
                ? 'bg-gradient-to-r from-fuchsia-400 to-rose-500 text-slate-950 shadow-lg shadow-fuchsia-500/25'
                : 'bg-slate-900 text-fuchsia-300 hover:bg-slate-800 border border-fuchsia-500/30'
            }`}
          >
            <Radio className="w-4 h-4" />
            <span>
              📻 Sesli Anılarımız (Zaman Kapsülü • {weeklyInterviews.length})
            </span>
          </button>
        </div>

        {activeTab === 'audio_memories' ? (
          <div className="space-y-4">
            <div className="rounded-2xl border border-fuchsia-500/30 bg-fuchsia-950/30 p-4 flex flex-wrap items-center justify-between gap-3">
              <div>
                <h3 className="text-base font-black text-white flex items-center gap-2">
                  <Radio className="w-5 h-5 text-fuchsia-400" />
                  <span>🎙️ Pazar Röportajları & Sesli Zaman Kapsülü</span>
                </h3>
                <p className="text-xs text-slate-300 mt-0.5">
                  Çocuklarınızın her hafta pedagojik sorulara verdiği samimi ses
                  kayıtları ve büyürken bıraktıkları hatıra notları burada
                  saklanır.
                </p>
              </div>
              <span className="px-3 py-1 rounded-full bg-fuchsia-500/20 border border-fuchsia-400/40 text-fuchsia-200 text-xs font-black">
                Toplam {weeklyInterviews.length} Sesli Anı
              </span>
            </div>

            {weeklyInterviews.length === 0 ? (
              <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-8 text-center text-slate-400 text-sm">
                Henüz kaydedilmiş bir Pazar Röportajı bulunmuyor. Öğrenci
                ekranındaki &ldquo;🎙️ Haftanın Röportajı (Zaman Kapsülü)&rdquo;
                butonuyla ilk sesli anıyı kaydedebilirsiniz!
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {weeklyInterviews.map((item) => {
                  const child = users.find((u) => u.id === item.user_id);
                  return (
                    <div
                      key={item.id}
                      className="rounded-3xl border border-fuchsia-400/35 bg-slate-950/90 p-5 shadow-xl flex flex-col justify-between space-y-3"
                    >
                      <div className="space-y-2.5">
                        <div className="flex items-center justify-between gap-2">
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-fuchsia-500/20 border border-fuchsia-400/40 text-fuchsia-200 font-black text-xs">
                            <span>{child?.avatar_config.emoji || '🎙️'}</span>
                            <span>{child?.name || 'Öğrenci'}</span>
                          </span>
                          <span className="inline-flex items-center gap-1 text-[11px] font-bold text-slate-400">
                            <Calendar className="w-3.5 h-3.5 text-fuchsia-400" />
                            <span>
                              {new Date(item.created_at).toLocaleDateString(
                                'tr-TR',
                                {
                                  day: 'numeric',
                                  month: 'long',
                                  year: 'numeric',
                                }
                              )}
                            </span>
                          </span>
                        </div>

                        <div className="rounded-2xl bg-indigo-950/50 border border-indigo-500/30 p-3">
                          <div className="text-[10px] font-black uppercase tracking-wider text-indigo-300 mb-0.5">
                            Haftanın Sorusu:
                          </div>
                          <div className="text-sm font-black text-white">
                            &ldquo;{item.question_text}&rdquo;
                          </div>
                        </div>

                        {item.answer_note && (
                          <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-3 text-xs text-amber-100 italic">
                            💬 &ldquo;{item.answer_note}&rdquo;
                          </div>
                        )}
                      </div>

                      {item.audio_url ? (
                        <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between gap-2">
                          <span className="inline-flex items-center gap-1 text-xs font-bold text-emerald-300">
                            <Volume2 className="w-4 h-4" />
                            <span>Ses Kaydı:</span>
                          </span>
                          <audio
                            src={item.audio_url}
                            controls
                            className="h-8 max-w-[230px]"
                          />
                        </div>
                      ) : (
                        <div className="pt-2 border-t border-slate-800/80 text-[11px] text-slate-400 flex items-center justify-between">
                          <span>📝 Yazılı Zaman Kapsülü Hatırası</span>
                          <span>Hafta: {item.week_start_date}</span>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ) : (
          <>
            {/* CINEMATIC SLIDESHOW MODE */}
        <AnimatePresence mode="wait">
          {isSlideshowActive && activeSlideSub && (
            <motion.div
              key={activeSlideSub.id + '-' + slideIndex}
              initial={{ opacity: 0, scale: 0.94, y: 15 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 1.03, y: -15 }}
              transition={{ duration: 0.55 }}
              className="bg-gradient-to-br from-amber-950/70 via-slate-950 to-indigo-950 border-2 border-amber-400 rounded-3xl p-6 shadow-2xl space-y-4 relative overflow-hidden"
            >
              <div className="flex items-center justify-between text-xs font-black text-amber-300">
                <span>
                  🍿 SİNEMATİK SLAYT MODU (Müzikli) • Kare {slideIndex + 1} /{' '}
                  {featuredSubmissions.length}
                </span>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() =>
                      setSlideIndex(
                        (prev) =>
                          (prev - 1 + featuredSubmissions.length) %
                          featuredSubmissions.length
                      )
                    }
                    className="p-1.5 rounded-xl bg-slate-900 border border-slate-700 text-white"
                  >
                    <ChevronLeft className="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() =>
                      setSlideIndex((prev) => (prev + 1) % featuredSubmissions.length)
                    }
                    className="p-1.5 rounded-xl bg-slate-900 border border-slate-700 text-white"
                  >
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-center">
                <div className="md:col-span-7 rounded-2xl overflow-hidden border-4 border-amber-400/70 shadow-2xl aspect-video bg-slate-900">
                  <img
                    src={
                      activeSlideSub.photo_urls[0] ||
                      'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=900&q=80'
                    }
                    alt={activeSlideTask?.title || 'Başarı Anısı'}
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="md:col-span-5 space-y-4">
                  <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-400 text-slate-950 font-black text-xs">
                    <span>{activeSlideChild?.avatar_config.emoji}</span>
                    <span>{activeSlideChild?.name} • Ayın Şampiyonu</span>
                  </div>
                  <h3 className="text-2xl font-black text-white">
                    {activeSlideTask?.title || 'Özel Başarı Görevi'}
                  </h3>
                  <div className="bg-slate-900/90 border border-amber-400/40 rounded-2xl p-4 space-y-2">
                    <div className="text-xs font-bold text-pink-300 flex items-center gap-1.5">
                      <Heart className="w-4 h-4 fill-current" />
                      <span>
                        {activeSlideParent?.name || 'Anne & Baba'} Gurur Notu:
                      </span>
                    </div>
                    <p className="text-sm font-bold text-amber-100 italic">
                      &ldquo;
                      {activeSlideSub.parent_praise_note ||
                        'Harika bir emek ve disiplinle tamamlanmış örnek bir çalışma, seninle gurur duyuyoruz!'}
                      &rdquo;
                    </p>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Children Badges & Evolution Showcase */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {childrenUsers.map((child) => {
            const badges =
              child.badges && child.badges.length > 0
                ? child.badges
                : ['💛 Altın Kalp Rozeti', '🛡️ Kalkan Muhafızı', '☀️ Sabah Şampiyonu'];
            return (
              <div
                key={child.id}
                className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 flex items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-2xl">
                    {child.avatar_config.emoji}
                  </div>
                  <div>
                    <div className="font-black text-white text-sm">
                      {child.name} — Kazanılan Rozetler
                    </div>
                    <div className="flex flex-wrap gap-1.5 mt-1">
                      {badges.map((b, i) => (
                        <span
                          key={i}
                          className="px-2.5 py-0.5 rounded-full bg-amber-400/20 border border-amber-400/40 text-amber-300 text-[11px] font-bold"
                        >
                          {b}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
                <Award className="w-7 h-7 text-amber-400 shrink-0" />
              </div>
            );
          })}
        </div>

        {/* Framed Gallery Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {featuredSubmissions.map((sub) => {
            const student = users.find((u) => u.id === sub.user_id);
            const task = tasks.find((t) => t.id === sub.task_id);
            const parent = users.find((u) => u.id === sub.approved_by);
            const photoUrl =
              sub.photo_urls[0] ||
              'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=900&q=80';

            return (
              <div
                key={sub.id}
                className="bg-slate-950/90 border-2 border-amber-400/40 rounded-3xl overflow-hidden shadow-xl flex flex-col"
              >
                <div className="relative aspect-video bg-slate-900 overflow-hidden">
                  <img
                    src={photoUrl}
                    alt={task?.title || 'Başarı Fotoğrafı'}
                    className="w-full h-full object-cover hover:scale-105 transition duration-500"
                  />
                  <span className="absolute top-3 left-3 px-3 py-1 rounded-full bg-slate-950/85 border border-amber-400/50 text-amber-300 font-black text-xs">
                    {student?.avatar_config.emoji} {student?.name}
                  </span>
                  {sub.is_featured_in_album && (
                    <span className="absolute top-3 right-3 px-2.5 py-1 rounded-full bg-amber-400 text-slate-950 font-black text-[11px]">
                      ⭐ Seçilmiş Albüm Eseri
                    </span>
                  )}
                </div>

                <div className="p-4 space-y-2.5 flex-1 flex flex-col justify-between">
                  <div>
                    <div className="text-sm font-black text-white">
                      {task?.title || 'Özel Etkinlik & Sorumluluk'}
                    </div>
                    <div className="mt-2 bg-amber-500/10 border border-amber-400/30 rounded-2xl p-3 text-xs text-amber-100 font-semibold">
                      💛 <strong>{parent?.name || 'Ebeveyn'} Notu:</strong> &ldquo;
                      {sub.parent_praise_note ||
                        'Çok özenli ve harika bir çalışma, tebrik ederiz!'}
                      &rdquo;
                    </div>
                  </div>

                  <div className="flex items-center justify-between text-[11px] text-slate-400 pt-2 border-t border-slate-800/80">
                    <span>+{task?.points || 45} Başarı Puanı</span>
                    <span>
                      {new Date(sub.created_at).toLocaleDateString('tr-TR')}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
          </>
        )}
      </motion.div>
    </div>
  );
};
