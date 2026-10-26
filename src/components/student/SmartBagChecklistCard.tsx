'use client';

import React, { useMemo, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Backpack,
  CheckCircle2,
  Sparkles,
  Volume2,
  BookOpen,
  Clock,
  Calendar,
} from 'lucide-react';
import { UserProfile, SchoolScheduleLesson } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { speakTurkishAnnouncement } from '@/lib/ttsAnnouncer';

const DAY_NAMES: Record<number, string> = {
  1: 'Pazartesi',
  2: 'Salı',
  3: 'Çarşamba',
  4: 'Perşembe',
  5: 'Cuma',
  6: 'Cumartesi',
  7: 'Pazar',
};

interface SmartBagChecklistCardProps {
  student: UserProfile;
}

export const SmartBagChecklistCard: React.FC<SmartBagChecklistCardProps> = ({
  student,
}) => {
  const { schoolSchedules, awardHealthPoints } = useFamilyRealtime();

  // Current day and tomorrow ISO day (1..7)
  const { todayIsoDay, tomorrowIsoDay, isAfterSchoolHour } = useMemo(() => {
    const now = new Date();
    const jsDay = now.getDay();
    const currentIso = jsDay === 0 ? 7 : jsDay;
    const tomorrowIso = (currentIso % 7) + 1;
    const currentHour = now.getHours();
    return {
      todayIsoDay: currentIso,
      tomorrowIsoDay: tomorrowIso,
      isAfterSchoolHour: currentHour >= 15, // Saat 15:00'ten sonra otomatik yarın öne çıkar
    };
  }, []);

  // Default mode: if after 15:00, tomorrow is active
  const [activeTab, setActiveTab] = useState<'today' | 'tomorrow'>(
    isAfterSchoolHour ? 'tomorrow' : 'today'
  );

  const selectedDay = activeTab === 'today' ? todayIsoDay : tomorrowIsoDay;

  const [checkedItems, setCheckedItems] = useState<Record<string, boolean>>({});
  const [bagCompletedToday, setBagCompletedToday] = useState(false);
  const [isSpeaking, setIsSpeaking] = useState(false);

  // Find schedule item for selectedDay
  const scheduleForDay = useMemo(() => {
    const found = schoolSchedules.find(
      (s) => s.user_id === student.id && s.day_of_week === selectedDay
    );
    if (found) return found;

    // Smart default if not yet populated
    return {
      id: `default-${student.id}-${selectedDay}`,
      family_id: student.family_id,
      user_id: student.id,
      day_of_week: selectedDay,
      lessons: [
        { period: 1, name: 'Türkçe' },
        { period: 2, name: 'Türkçe' },
        { period: 3, name: 'Matematik' },
        { period: 4, name: 'Matematik' },
        { period: 5, name: 'Fen Bilimleri' },
        { period: 6, name: 'Görsel Sanatlar' },
      ],
      extra_materials: ['Resim Çantası', 'Suluk'],
      has_pe_class: false,
      has_art_class: true,
      custom_items_to_pack: ['Resim Çantası', 'Suluk'],
      reminder_note: 'Yarın Görsel Sanatlar dersi var! Resim çantanı unutma.',
    };
  }, [schoolSchedules, student.id, student.family_id, selectedDay]);

  // Lessons list
  const lessons: SchoolScheduleLesson[] = useMemo(() => {
    return scheduleForDay.lessons || [];
  }, [scheduleForDay]);

  // Unique lessons list for TTS and checklist
  const uniqueLessonNames = useMemo(() => {
    const set = new Set<string>();
    lessons.forEach((l) => {
      if (l.name?.trim()) set.add(l.name.trim());
    });
    return Array.from(set);
  }, [lessons]);

  // Extra materials
  const extraMaterials = useMemo(() => {
    const list = [
      ...(scheduleForDay.extra_materials ||
        scheduleForDay.custom_items_to_pack ||
        []),
    ];
    if (scheduleForDay.has_pe_class && !list.includes('Eşofman Takımı')) {
      list.unshift('Eşofman Takımı');
    }
    if (scheduleForDay.has_art_class && !list.includes('Resim Çantası')) {
      list.push('Resim Çantası');
    }
    if (!list.includes('Suluk')) {
      list.push('Suluk');
    }
    return Array.from(new Set(list));
  }, [scheduleForDay]);

  // Combined checklist items: Each unique lesson book/notebook + materials
  const checklistItems = useMemo(() => {
    const items: string[] = [];
    uniqueLessonNames.forEach((lName) => {
      items.push(`${lName} Defteri & Kitabı`);
    });
    extraMaterials.forEach((mat) => {
      items.push(mat);
    });
    return items;
  }, [uniqueLessonNames, extraMaterials]);

  const allChecked =
    checklistItems.length > 0 &&
    checklistItems.every((it) => checkedItems[it]);

  const toggleItem = (item: string) => {
    setCheckedItems((prev) => ({ ...prev, [item]: !prev[item] }));
  };

  // TTS Voice Backpack Assistant Trigger
  const handleVoiceBackpackAnnouncement = () => {
    setIsSpeaking(true);
    const dayLabel = DAY_NAMES[selectedDay] || 'Yarın';
    const lessonsFormatted =
      uniqueLessonNames.length > 0
        ? uniqueLessonNames.join(', ')
        : 'Genel Okul Dersleri';
    const materialsFormatted =
      extraMaterials.length > 0
        ? extraMaterials.join(', ')
        : 'Suluğunu ve Kalemliğini';

    const speechText = `Hey ${student.name}, yarın ${dayLabel}! Yarınki derslerin: ${lessonsFormatted}. Lütfen bu derslerin kitap ve defterlerini, ayrıca ${materialsFormatted} çantana koymayı unutma!`;

    speakTurkishAnnouncement(speechText, true);

    setTimeout(() => {
      setIsSpeaking(false);
    }, 6000);
  };

  const handleCompleteBagPack = async () => {
    if (bagCompletedToday) return;
    setBagCompletedToday(true);
    try {
      confetti({ particleCount: 75, spread: 70, origin: { y: 0.7 } });
    } catch {}
    await awardHealthPoints(
      student.id,
      10,
      `🎒 ${student.name} ${DAY_NAMES[selectedDay]} okul çantasını eksiksiz hazırladı!`
    );
  };

  return (
    <div className="bg-gradient-to-r from-indigo-950/90 via-slate-900 to-purple-950/80 border border-indigo-500/40 rounded-3xl p-4 sm:p-6 shadow-2xl space-y-4">
      {/* Top Header & Day/Tab Selector */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-2xl bg-indigo-500/25 border border-indigo-400/40 flex items-center justify-center text-2xl shadow-lg">
            🎒
          </div>
          <div>
            <div className="flex items-center gap-1.5 text-[11px] font-black text-indigo-300 uppercase tracking-wider">
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>HAFTALIK DERS PROGRAMI & SESLİ ÇANTA ASİSTANI</span>
            </div>
            <h3 className="text-base sm:text-lg font-black text-white flex items-center gap-2">
              <span>{activeTab === 'today' ? 'Bugünün' : 'Yarının'} Dersleri ({DAY_NAMES[selectedDay]})</span>
              {isAfterSchoolHour && activeTab === 'tomorrow' && (
                <span className="px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-400/30 text-[10px] font-black">
                  Akşam Hazırlık Vakti (15:00+)
                </span>
              )}
            </h3>
          </div>
        </div>

        {/* Tab & Action Buttons */}
        <div className="flex items-center gap-2">
          {/* Today vs Tomorrow Toggle */}
          <div className="flex p-1 rounded-2xl bg-slate-950 border border-slate-800">
            <button
              type="button"
              onClick={() => {
                setActiveTab('today');
                setCheckedItems({});
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-black transition ${
                activeTab === 'today'
                  ? 'bg-indigo-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              Bugün ({DAY_NAMES[todayIsoDay]?.slice(0, 3)})
            </button>
            <button
              type="button"
              onClick={() => {
                setActiveTab('tomorrow');
                setCheckedItems({});
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-black transition ${
                activeTab === 'tomorrow'
                  ? 'bg-purple-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              Yarın ({DAY_NAMES[tomorrowIsoDay]?.slice(0, 3)})
            </button>
          </div>

          {/* Voice backpack button */}
          <button
            type="button"
            onClick={handleVoiceBackpackAnnouncement}
            className={`px-3.5 py-1.5 rounded-2xl font-black text-xs flex items-center gap-1.5 shadow-lg transition active:scale-95 ${
              isSpeaking
                ? 'bg-amber-400 text-slate-950 animate-pulse'
                : 'bg-indigo-500 hover:bg-indigo-400 text-white'
            }`}
            title="Sesli Asistan Çantayı Okusun"
          >
            <Volume2 className="w-4 h-4" />
            <span className="hidden sm:inline">🎒 Çantamı Hazırlıyorum (Sesli Oku)</span>
            <span className="sm:hidden">Sesli Oku</span>
          </button>
        </div>
      </div>

      {/* 1. to 8. Periods Grid View */}
      {lessons.length > 0 ? (
        <div>
          <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-1">
            <BookOpen className="w-3.5 h-3.5 text-indigo-400" />
            <span>Günün Ders Çizelgesi (1. - 8. Dersler)</span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-2">
            {[1, 2, 3, 4, 5, 6, 7, 8].map((period) => {
              const lesson = lessons.find((l) => l.period === period);
              return (
                <div
                  key={period}
                  className={`p-2 rounded-2xl border text-center transition ${
                    lesson
                      ? 'bg-slate-950/80 border-indigo-500/30 text-white shadow'
                      : 'bg-slate-950/40 border-slate-800 text-slate-600 opacity-60'
                  }`}
                >
                  <div className="text-[10px] font-mono text-indigo-400 font-bold mb-0.5">
                    {period}. Ders
                  </div>
                  <div className="text-xs font-black truncate">
                    {lesson ? lesson.name : '—'}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="p-3.5 rounded-2xl bg-slate-950/70 border border-slate-800 text-xs text-slate-400 text-center">
          Bu gün için henüz ders programı girilmedi. Ebeveyn panelinden ders çizelgesi ekleyebilirsiniz.
        </div>
      )}

      {/* Reminder Note */}
      {scheduleForDay.reminder_note && (
        <div className="p-2.5 rounded-2xl bg-indigo-950/50 border border-indigo-500/20 text-xs text-indigo-200 font-semibold flex items-center gap-2">
          <span>📌</span>
          <span>{scheduleForDay.reminder_note}</span>
        </div>
      )}

      {/* Interactive Backpack Checklist */}
      <div>
        <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2">
          Çantaya Koyulacak Defter, Kitap ve Malzemeler ({checklistItems.filter((i) => checkedItems[i]).length}/{checklistItems.length})
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
          {checklistItems.map((item) => {
            const isDone = Boolean(checkedItems[item]);
            return (
              <button
                key={item}
                type="button"
                onClick={() => toggleItem(item)}
                className={`px-3 py-2.5 rounded-2xl border text-left text-xs font-bold flex items-center gap-2 transition active:scale-[0.98] ${
                  isDone
                    ? 'bg-emerald-500/20 border-emerald-400 text-emerald-200 shadow'
                    : 'bg-slate-950/80 border-slate-800 text-slate-300 hover:border-indigo-400/50'
                }`}
              >
                <span
                  className={`w-5 h-5 rounded-lg flex items-center justify-center text-xs shrink-0 ${
                    isDone
                      ? 'bg-emerald-400 text-slate-950 font-black'
                      : 'bg-slate-800 text-slate-500'
                  }`}
                >
                  {isDone ? '✓' : '○'}
                </span>
                <span className={`truncate ${isDone ? 'line-through opacity-80' : ''}`}>
                  {item}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Completion Bonus Action */}
      {allChecked && !bagCompletedToday && (
        <motion.button
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          type="button"
          onClick={handleCompleteBagPack}
          className="w-full py-3 rounded-2xl bg-gradient-to-r from-emerald-400 to-teal-500 text-slate-950 font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-xl hover:opacity-95 transition"
        >
          <CheckCircle2 className="w-5 h-5" />
          <span>🎒 Tüm Kitap & Malzemeleri Çantama Koydum! (+10 Sağlık Bonusu Kazan)</span>
        </motion.button>
      )}

      {bagCompletedToday && (
        <div className="text-xs font-black text-emerald-300 bg-emerald-500/15 border border-emerald-400/30 rounded-2xl px-4 py-2.5 text-center flex items-center justify-center gap-2">
          <CheckCircle2 className="w-4 h-4 text-emerald-400" />
          <span>Harikasın {student.name}! Okul çantan eksiksiz hazır (+10 Puan eklendi)!</span>
        </div>
      )}
    </div>
  );
};
