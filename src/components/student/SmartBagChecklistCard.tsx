'use client';

import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { Backpack, CheckCircle2, Sparkles } from 'lucide-react';
import { UserProfile } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';

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

  // Tomorrow's day of week (1 = Monday ... 7 = Sunday)
  // JS getDay(): 0 = Sunday, 1 = Monday ... 6 = Saturday -> ISO 1..7: jsDay === 0 ? 7 : jsDay
  // Tomorrow ISO day: (currentDay % 7) + 1
  const defaultTomorrowIsoDay = useMemo(() => {
    const jsDay = new Date().getDay();
    const currentDay = jsDay === 0 ? 7 : jsDay;
    return (currentDay % 7) + 1;
  }, []);

  const [selectedDay, setSelectedDay] = useState<number>(
    defaultTomorrowIsoDay > 5 ? 1 : defaultTomorrowIsoDay
  );
  const [checkedItems, setCheckedItems] = useState<Record<string, boolean>>({});
  const [bagCompletedToday, setBagCompletedToday] = useState(false);

  const scheduleForDay = useMemo(() => {
    return (
      schoolSchedules.find(
        (s) => s.user_id === student.id && s.day_of_week === selectedDay
      ) || {
        id: 'default-sch',
        family_id: student.family_id,
        user_id: student.id,
        day_of_week: selectedDay,
        has_pe_class: true,
        has_art_class: true,
        custom_items_to_pack: ['Eşofman Takımı', 'Suluk', 'Resim Çantası'],
        reminder_note:
          'Yarın Beden Eğitimi ve Resim var! Eşofman takımı, suluk ve resim çantanı koydun mu?',
      }
    );
  }, [schoolSchedules, student.id, student.family_id, selectedDay]);

  const itemsList = useMemo(() => {
    const base = [...(scheduleForDay.custom_items_to_pack || [])];
    if (scheduleForDay.has_pe_class && !base.includes('Eşofman Takımı')) {
      base.unshift('Eşofman Takımı');
    }
    if (scheduleForDay.has_art_class && !base.includes('Resim Çantası')) {
      base.push('Resim Çantası');
    }
    if (!base.includes('Suluk')) {
      base.push('Suluk');
    }
    return base;
  }, [scheduleForDay]);

  const allChecked =
    itemsList.length > 0 && itemsList.every((it) => checkedItems[it]);

  const toggleItem = (item: string) => {
    setCheckedItems((prev) => ({ ...prev, [item]: !prev[item] }));
  };

  const handleCompleteBagPack = async () => {
    if (bagCompletedToday) return;
    setBagCompletedToday(true);
    try {
      confetti({ particleCount: 70, spread: 65, origin: { y: 0.7 } });
    } catch {}
    await awardHealthPoints(
      student.id,
      10,
      `🎒 ${student.name} yarının okul çantasını (${itemsList.join(', ')}) eksiksiz hazırladı!`
    );
  };

  const specialClassesText = [
    scheduleForDay.has_pe_class ? '🤸 Beden Eğitimi' : null,
    scheduleForDay.has_art_class ? '🎨 Resim / Müzik' : null,
  ]
    .filter(Boolean)
    .join(' ve ');

  return (
    <div className="bg-gradient-to-r from-indigo-950/85 via-slate-900 to-purple-950/80 border border-indigo-500/40 rounded-3xl p-4 sm:p-5 shadow-xl space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2.5">
          <div className="w-10 h-10 rounded-2xl bg-indigo-500/20 border border-indigo-400/40 flex items-center justify-center text-xl">
            🎒
          </div>
          <div>
            <div className="flex items-center gap-1.5 text-[11px] font-black text-indigo-300 uppercase">
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>AKILLI OKUL ÇANTASI HAZIRLAMA ASİSTANI (YARININ PROGRAMI)</span>
            </div>
            <h4 className="text-sm sm:text-base font-black text-white">
              🎒 Yarın ({DAY_NAMES[selectedDay]}){' '}
              {specialClassesText
                ? `${specialClassesText} var!`
                : 'Okul Günü!'}{' '}
              {itemsList.join(', ')} koydun mu?
            </h4>
          </div>
        </div>

        {/* Day Selector for previewing any weekday */}
        <div className="flex items-center gap-1">
          {[1, 2, 3, 4, 5].map((d) => (
            <button
              key={d}
              type="button"
              onClick={() => {
                setSelectedDay(d);
                setCheckedItems({});
              }}
              className={`px-2.5 py-1 rounded-xl text-[11px] font-bold transition ${
                selectedDay === d
                  ? 'bg-indigo-500 text-white'
                  : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
              }`}
            >
              {DAY_NAMES[d].slice(0, 3)}
            </button>
          ))}
        </div>
      </div>

      {scheduleForDay.reminder_note && (
        <p className="text-xs text-indigo-200/90 font-semibold">
          📌 Hatırlatma: {scheduleForDay.reminder_note}
        </p>
      )}

      {/* Checklist Items */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        {itemsList.map((item) => {
          const isDone = Boolean(checkedItems[item]);
          return (
            <button
              key={item}
              type="button"
              onClick={() => toggleItem(item)}
              className={`px-3 py-2.5 rounded-2xl border text-left text-xs font-bold flex items-center gap-2 transition ${
                isDone
                  ? 'bg-emerald-500/20 border-emerald-400 text-emerald-200'
                  : 'bg-slate-950/80 border-slate-800 text-slate-300 hover:border-indigo-400/50'
              }`}
            >
              <span
                className={`w-5 h-5 rounded-lg flex items-center justify-center text-xs ${
                  isDone
                    ? 'bg-emerald-400 text-slate-950 font-black'
                    : 'bg-slate-800 text-slate-500'
                }`}
              >
                {isDone ? '✓' : '○'}
              </span>
              <span className={isDone ? 'line-through opacity-90' : ''}>
                {item}
              </span>
            </button>
          );
        })}
      </div>

      {allChecked && !bagCompletedToday && (
        <motion.button
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          type="button"
          onClick={handleCompleteBagPack}
          className="w-full py-2.5 rounded-2xl bg-gradient-to-r from-emerald-400 to-teal-500 text-slate-950 font-black text-xs sm:text-sm flex items-center justify-center gap-2 shadow-lg"
        >
          <CheckCircle2 className="w-4 h-4" />
          <span>🎒 Tüm Eşyalarımı Çantama Koydum! (+10 Bonus Puan Kazan)</span>
        </motion.button>
      )}

      {bagCompletedToday && (
        <div className="text-xs font-black text-emerald-300 bg-emerald-500/15 border border-emerald-400/30 rounded-2xl px-3.5 py-2 text-center">
          ✅ Harikasın! Yarının okul çantası eksiksiz hazır (+10 Puan eklendi)!
        </div>
      )}
    </div>
  );
};
