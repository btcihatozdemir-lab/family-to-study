'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Calendar, Save, Plus, Trash2, X, Sparkles, BookOpen } from 'lucide-react';
import { SchoolScheduleItem, SchoolScheduleLesson, UserProfile } from '@/types/database';

const DAY_NAMES: Record<number, string> = {
  1: 'Pazartesi',
  2: 'Salı',
  3: 'Çarşamba',
  4: 'Perşembe',
  5: 'Cuma',
  6: 'Cumartesi',
  7: 'Pazar',
};

const COMMON_LESSONS = [
  'Matematik',
  'Türkçe',
  'Fen Bilimleri',
  'Sosyal Bilgiler',
  'İngilizce',
  'Bilişim Teknolojileri',
  'Görsel Sanatlar',
  'Müzik',
  'Beden Eğitimi',
  'Din Kültürü',
  'Rehberlik / Kulüp',
];

interface WeeklyScheduleEditorModalProps {
  isOpen: boolean;
  onClose: () => void;
  student: UserProfile;
  schedules: SchoolScheduleItem[];
  onSaveSchedule: (schedule: Omit<SchoolScheduleItem, 'id' | 'family_id'>) => Promise<void>;
}

export const WeeklyScheduleEditorModal: React.FC<WeeklyScheduleEditorModalProps> = ({
  isOpen,
  onClose,
  student,
  schedules,
  onSaveSchedule,
}) => {
  const [activeDay, setActiveDay] = useState<number>(1);
  const [isSaving, setIsSaving] = useState(false);
  const [saveFeedback, setSaveFeedback] = useState<string | null>(null);

  // Find existing schedule for current day
  const currentSchedule = schedules.find(
    (s) => s.user_id === student.id && s.day_of_week === activeDay
  );

  // Period slots 1 to 8
  const [lessonsDraft, setLessonsDraft] = useState<Record<number, string>>(() => {
    const map: Record<number, string> = {};
    for (let p = 1; p <= 8; p++) {
      const match = currentSchedule?.lessons?.find((l) => l.period === p);
      map[p] = match ? match.name : '';
    }
    return map;
  });

  const [extraMaterialsDraft, setExtraMaterialsDraft] = useState<string>(
    (currentSchedule?.extra_materials || currentSchedule?.custom_items_to_pack || []).join(', ')
  );
  const [reminderNoteDraft, setReminderNoteDraft] = useState<string>(
    currentSchedule?.reminder_note || ''
  );

  // When activeDay changes, re-populate draft
  const handleSelectDay = (day: number) => {
    setActiveDay(day);
    setSaveFeedback(null);
    const sch = schedules.find(
      (s) => s.user_id === student.id && s.day_of_week === day
    );
    const map: Record<number, string> = {};
    for (let p = 1; p <= 8; p++) {
      const match = sch?.lessons?.find((l) => l.period === p);
      map[p] = match ? match.name : '';
    }
    setLessonsDraft(map);
    setExtraMaterialsDraft(
      (sch?.extra_materials || sch?.custom_items_to_pack || []).join(', ')
    );
    setReminderNoteDraft(sch?.reminder_note || '');
  };

  if (!isOpen) return null;

  const handleLessonChange = (period: number, value: string) => {
    setLessonsDraft((prev) => ({ ...prev, [period]: value }));
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setSaveFeedback(null);

    const lessonsList: SchoolScheduleLesson[] = [];
    for (let p = 1; p <= 8; p++) {
      const name = (lessonsDraft[p] || '').trim();
      if (name) {
        lessonsList.push({ period: p, name });
      }
    }

    const extraMats = extraMaterialsDraft
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    const hasPe = lessonsList.some((l) =>
      l.name.toLowerCase().includes('beden')
    );
    const hasArt = lessonsList.some(
      (l) =>
        l.name.toLowerCase().includes('resim') ||
        l.name.toLowerCase().includes('görsel') ||
        l.name.toLowerCase().includes('müzik')
    );

    try {
      await onSaveSchedule({
        user_id: student.id,
        day_of_week: activeDay,
        lessons: lessonsList,
        extra_materials: extraMats,
        has_pe_class: hasPe,
        has_art_class: hasArt,
        custom_items_to_pack: extraMats,
        reminder_note: reminderNoteDraft,
      });

      setSaveFeedback(`✅ ${DAY_NAMES[activeDay]} ders programı başarıyla kaydedildi!`);
      setTimeout(() => setSaveFeedback(null), 3000);
    } catch {
      setSaveFeedback('❌ Kaydedilirken bir hata meydana geldi.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/85 backdrop-blur-md">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-3xl bg-slate-900 border border-indigo-500/30 rounded-3xl p-5 sm:p-7 shadow-2xl space-y-5 text-white max-h-[92vh] overflow-y-auto"
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-slate-800 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-2xl shadow-lg">
              📚
            </div>
            <div>
              <div className="flex items-center gap-2 text-xs font-bold text-indigo-400 uppercase tracking-wider">
                <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                <span>Haftalık Ders Çizelgesi & Akıllı Çanta Editörü</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-black">
                {student.name} - Okul Ders Programı
              </h2>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-2xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Day Selector Buttons */}
        <div className="flex flex-wrap items-center gap-1.5 sm:gap-2">
          {[1, 2, 3, 4, 5, 6, 7].map((d) => (
            <button
              key={d}
              type="button"
              onClick={() => handleSelectDay(d)}
              className={`px-3.5 py-2 rounded-2xl text-xs sm:text-sm font-black transition ${
                activeDay === d
                  ? 'bg-gradient-to-r from-indigo-500 to-purple-600 text-white shadow-lg'
                  : 'bg-slate-950 text-slate-400 hover:text-slate-200 border border-slate-800'
              }`}
            >
              {DAY_NAMES[d]}
            </button>
          ))}
        </div>

        {saveFeedback && (
          <div className="p-3.5 rounded-2xl bg-indigo-950/70 border border-indigo-500/40 text-indigo-200 text-xs font-bold">
            {saveFeedback}
          </div>
        )}

        <form onSubmit={handleSave} className="space-y-5">
          {/* 8 Periods Grid */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-bold text-slate-300">
                {DAY_NAMES[activeDay]} Günlük Dersler (1 - 8. Ders)
              </span>
              <span className="text-[11px] text-slate-500">
                Seçin veya istediğiniz dersi yazın
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {[1, 2, 3, 4, 5, 6, 7, 8].map((period) => (
                <div
                  key={period}
                  className="p-2.5 rounded-2xl bg-slate-950 border border-slate-800 flex items-center gap-2"
                >
                  <span className="w-7 h-7 rounded-xl bg-indigo-500/20 text-indigo-300 font-black text-xs flex items-center justify-center shrink-0">
                    {period}
                  </span>
                  <input
                    type="text"
                    list={`common-lessons-${period}`}
                    placeholder={`${period}. Ders (Boş ise boş bırakın)`}
                    value={lessonsDraft[period] || ''}
                    onChange={(e) => handleLessonChange(period, e.target.value)}
                    className="flex-1 bg-transparent text-xs font-bold text-white placeholder-slate-600 focus:outline-none"
                  />
                  <datalist id={`common-lessons-${period}`}>
                    {COMMON_LESSONS.map((cl) => (
                      <option key={cl} value={cl} />
                    ))}
                  </datalist>
                </div>
              ))}
            </div>
          </div>

          {/* Extra Materials & Notes */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                🎒 Çantaya Konulacak Ekstra Malzemeler (Virgülle Ayırın)
              </label>
              <input
                type="text"
                placeholder="Örn: Resim Çantası, Pergel-Cetvel, Eşofman, Suluğun"
                value={extraMaterialsDraft}
                onChange={(e) => setExtraMaterialsDraft(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-slate-950 border border-slate-700 text-xs text-white font-bold focus:outline-none focus:border-indigo-400"
              />
              <span className="text-[11px] text-slate-500 mt-1 block">
                Sesli çanta asistanı bu malzemeleri öğrenciye sesli okur.
              </span>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                📌 Günlük Özel Not / Hatırlatma
              </label>
              <input
                type="text"
                placeholder="Örn: Yarın Proje ödevi teslim günü!"
                value={reminderNoteDraft}
                onChange={(e) => setReminderNoteDraft(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-slate-950 border border-slate-700 text-xs text-white font-bold focus:outline-none focus:border-indigo-400"
              />
            </div>
          </div>

          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 rounded-2xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold text-xs transition"
            >
              Kapat
            </button>
            <button
              type="submit"
              disabled={isSaving}
              className="px-6 py-2.5 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-black text-xs sm:text-sm flex items-center gap-2 shadow-lg transition disabled:opacity-50"
            >
              <Save className="w-4 h-4" />
              <span>{isSaving ? 'Kaydediliyor...' : `${DAY_NAMES[activeDay]} Programını Kaydet`}</span>
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};
