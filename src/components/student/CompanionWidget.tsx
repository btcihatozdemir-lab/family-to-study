'use client';

import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, CloudRain, Sun, CloudSnow, Wind, Heart, Zap, Utensils } from 'lucide-react';
import { CompanionConfig, CompanionType, UserProfile } from '@/types/database';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';

interface WeatherState {
  tempC: number;
  weatherCode: number;
  conditionLabel: string;
  outfitEmoji: string;
  adviceText: string;
}

const COMPANION_SPECIES: Record<
  CompanionType,
  {
    label: string;
    stages: { stage: number; title: string; emoji: string }[];
    bgGradient: string;
  }
> = {
  dragon: {
    label: 'Ateş Ejderhası',
    stages: [
      { stage: 1, title: 'Lv.1 Ejderha Yumurtası', emoji: '🥚🔥' },
      { stage: 2, title: 'Lv.2 Bebek Ejderha', emoji: '🐲✨' },
      { stage: 3, title: 'Lv.3 Genç Kanatlı Ejder', emoji: '🐉🔥' },
      { stage: 4, title: 'Lv.5+ Efsanevi Koruyucu Ejder', emoji: '🐉👑⚡' },
    ],
    bgGradient: 'from-amber-500/25 via-orange-600/20 to-rose-600/25 border-amber-400/50',
  },
  cat: {
    label: 'Kozmik Kedi',
    stages: [
      { stage: 1, title: 'Lv.1 Işıltılı Puset', emoji: '🥚🐾' },
      { stage: 2, title: 'Lv.2 Minik Yavru Kedi', emoji: '🐱🌸' },
      { stage: 3, title: 'Lv.3 Çevik Yıldız Kedisi', emoji: '🐈✨' },
      { stage: 4, title: 'Lv.5+ Efsanevi Galaksi Aslanı', emoji: '🦁👑🌟' },
    ],
    bgGradient: 'from-pink-500/25 via-fuchsia-600/20 to-purple-600/25 border-pink-400/50',
  },
  robot: {
    label: 'Siber Robot',
    stages: [
      { stage: 1, title: 'Lv.1 Çekirdek Modül', emoji: '🔋⚙️' },
      { stage: 2, title: 'Lv.2 Mini Bot', emoji: '🤖💡' },
      { stage: 3, title: 'Lv.3 Siber Muhafız', emoji: '🤖🚀' },
      { stage: 4, title: 'Lv.5+ Efsanevi Kuantum Titan', emoji: '🤖👑⚡' },
    ],
    bgGradient: 'from-cyan-500/25 via-blue-600/20 to-indigo-600/25 border-cyan-400/50',
  },
  alien: {
    label: 'Neşeli Uzaylı',
    stages: [
      { stage: 1, title: 'Lv.1 Kozmik Kapsül', emoji: '🛸🥚' },
      { stage: 2, title: 'Lv.2 Bebek Nebula', emoji: '👾💫' },
      { stage: 3, title: 'Lv.3 Galaksi Kaşifi', emoji: '👽🛸' },
      { stage: 4, title: 'Lv.5+ Efsanevi Yıldız Lordu', emoji: '👽👑🌌' },
    ],
    bgGradient: 'from-emerald-500/25 via-teal-600/20 to-cyan-600/25 border-emerald-400/50',
  },
};

interface CompanionWidgetProps {
  student: UserProfile;
  isBrushingTeeth?: boolean;
  onStartQuickTask?: () => void;
}

export const CompanionWidget: React.FC<CompanionWidgetProps> = ({
  student,
  isBrushingTeeth = false,
  onStartQuickTask,
}) => {
  const { familySettings, submissions, updateCompanionConfig } = useFamilyRealtime();

  const companion: CompanionConfig = student.companion_config || {
    type: 'dragon',
    name: 'Ateş Kanat',
    xp: 140,
    level: 2,
    evolution_stage: 2,
    hunger: 90,
    energy: 95,
  };

  const [weather, setWeather] = useState<WeatherState | null>(null);
  const [isCelebrating, setIsCelebrating] = useState(false);
  const [showCustomize, setShowCustomize] = useState(false);
  const [customName, setCustomName] = useState(companion.name);
  const [customType, setCustomType] = useState<CompanionType>(companion.type);

  // Check if student completed any task today
  const completedTodayCount = submissions.filter(
    (s) => s.user_id === student.id && s.status === 'approved'
  ).length;

  const isHungryOrSleepy =
    completedTodayCount === 0 ||
    student.daily_shields < 3 ||
    (companion.hunger || 80) < 50;

  // Trigger jump celebration when XP increases
  useEffect(() => {
    setIsCelebrating(true);
    const t = setTimeout(() => setIsCelebrating(false), 2600);
    return () => clearTimeout(t);
  }, [companion.xp]);

  // Open-Meteo Free Weather API Integration (No API Key required)
  useEffect(() => {
    let isMounted = true;
    const lat = familySettings?.city_lat ?? 41.08;
    const lon = familySettings?.city_lon ?? 31.12;

    const fetchWeather = async () => {
      try {
        const res = await fetch(
          `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true`
        );
        if (!res.ok) throw new Error('Weather API unavailable');
        const data = await res.json();
        const cw = data?.current_weather;
        if (!cw || !isMounted) return;

        const tempC = Math.round(Number(cw.temperature ?? 16));
        const code = Number(cw.weathercode ?? 0);

        let conditionLabel = 'Açık ve Güneşli';
        let outfitEmoji = '🕶️☀️';
        let adviceText = `☀️ Bugün hava güneşli ve ${tempC}°C! Enerji dolu harika bir okul günü seni bekliyor!`;

        if ([51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96].includes(code)) {
          conditionLabel = 'Yağmurlu';
          outfitEmoji = '☔🧥';
          adviceText = `🌧️ Bugün hava yağmurlu ve ${tempC}°C! Okula giderken yağmurluğunu ve şemsiyeni almayı unutma!`;
        } else if ([71, 73, 75, 77, 85, 86].includes(code) || tempC <= 6) {
          conditionLabel = 'Soğuk / Karlı';
          outfitEmoji = '🧣🧤❄️';
          adviceText = `❄️ Bugün hava oldukça soğuk (${tempC}°C)! Kalın montunu, atkını ve bereni mutlaka tak!`;
        } else if ([1, 2, 3, 45, 48].includes(code)) {
          conditionLabel = 'Parçalı Bulutlu';
          outfitEmoji = '🧢🌤️';
          adviceText = `🌤️ Bugün hava bulutlu ve ${tempC}°C! Çantana ince bir hırka koymayı unutma!`;
        }

        setWeather({
          tempC,
          weatherCode: code,
          conditionLabel,
          outfitEmoji,
          adviceText,
        });
      } catch {
        if (!isMounted) return;
        setWeather({
          tempC: 14,
          weatherCode: 61,
          conditionLabel: 'Serin & Yağışlı',
          outfitEmoji: '☔🧣',
          adviceText:
            '🌧️ Bugün hava yağmurlu ve 14°C! Okula giderken yağmurluğunu almayı unutma!',
        });
      }
    };

    fetchWeather();
    return () => {
      isMounted = false;
    };
  }, [familySettings?.city_lat, familySettings?.city_lon]);

  const speciesInfo =
    COMPANION_SPECIES[companion.type] || COMPANION_SPECIES.dragon;
  const stageInfo =
    speciesInfo.stages.find((s) => s.stage === companion.evolution_stage) ||
    speciesInfo.stages[1];

  const xpInCurrentLevel = (companion.xp || 0) % 100;

  // Dynamic speech bubble message
  let speechBubble =
    weather?.adviceText ||
    `Merhaba ${student.name}! Bugün birlikte yeni görevler tamamlayıp evrimleşelim! 🚀`;

  if (isBrushingTeeth) {
    speechBubble = `🪥✨ Şup şup! Dişlerimizi 2 dakika boyunca birlikte fırçalıyoruz, tertemiz oluyor!`;
  } else if (isCelebrating) {
    speechBubble = `🍖🎉 Yaşasın! Görev tamamlandı, karnım doydu ve +20 XP kazandım!`;
  } else if (isHungryOrSleepy) {
    speechBubble = `🥺💤 Karnım acıktı ve enerjim düştü, hadi birlikte bir görev tamamlayalım!`;
  }

  const handleSaveCustomization = async (e: React.FormEvent) => {
    e.preventDefault();
    await updateCompanionConfig(student.id, {
      name: customName.trim() || companion.name,
      type: customType,
    });
    setShowCustomize(false);
  };

  return (
    <div
      className={`bg-gradient-to-br ${speciesInfo.bgGradient} border rounded-3xl p-4 sm:p-5 shadow-xl relative overflow-hidden`}
    >
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Left: Breathing & Jumping Animated Companion Avatar + Weather Outfit */}
        <div className="flex items-center gap-4">
          <motion.div
            animate={
              isBrushingTeeth
                ? { rotate: [-8, 8, -8, 8, 0], scale: [1, 1.08, 1] }
                : isCelebrating
                ? { y: [0, -18, 0, -12, 0], scale: [1, 1.15, 1] }
                : isHungryOrSleepy
                ? { y: [0, 3, 0], opacity: [0.85, 1, 0.85] }
                : { y: [0, -6, 0], scale: [1, 1.04, 1] }
            }
            transition={{
              duration: isCelebrating ? 0.9 : 2.8,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
            className="relative w-20 h-20 sm:w-24 sm:h-24 rounded-3xl bg-slate-950/80 border-2 border-white/20 flex flex-col items-center justify-center shadow-2xl shrink-0"
          >
            <div className="text-4xl sm:text-5xl select-none">
              {stageInfo.emoji}
            </div>
            {/* Weather Outfit Badge */}
            {weather && (
              <span
                title={`Hava Durumu Kıyafeti: ${weather.conditionLabel} (${weather.tempC}°C)`}
                className="absolute -top-2 -right-2 px-2 py-0.5 rounded-full bg-slate-900 border border-amber-400/50 text-xs shadow-lg"
              >
                {weather.outfitEmoji}
              </span>
            )}
            {/* Toothbrush or Food Reaction Badge */}
            {isBrushingTeeth && (
              <span className="absolute -bottom-2 px-2 py-0.5 rounded-full bg-cyan-500 text-slate-950 font-black text-[10px]">
                🪥 Fırçalıyor!
              </span>
            )}
            {!isBrushingTeeth && isHungryOrSleepy && (
              <span className="absolute -bottom-2 px-2 py-0.5 rounded-full bg-amber-500 text-slate-950 font-black text-[10px]">
                🥺 Acıkmış
              </span>
            )}
          </motion.div>

          {/* Center: Companion Info, Speech Bubble & XP Progress */}
          <div className="space-y-1.5">
            <div className="flex flex-wrap items-center gap-2">
              <span className="px-2.5 py-0.5 rounded-full bg-slate-950/70 text-amber-300 text-[11px] font-black border border-amber-400/30">
                🐾 DİJİTAL YOLDAŞIM • {stageInfo.title}
              </span>
              {weather && (
                <span className="px-2.5 py-0.5 rounded-full bg-sky-500/20 text-sky-200 text-[11px] font-bold border border-sky-400/30">
                  {weather.outfitEmoji} {weather.tempC}°C {weather.conditionLabel}
                </span>
              )}
              <button
                type="button"
                onClick={() => setShowCustomize(!showCustomize)}
                className="text-[11px] text-slate-300 hover:text-white underline font-semibold"
              >
                {showCustomize ? 'Kapat' : '✏️ Yoldaşı Özelleştir'}
              </button>
            </div>

            <h3 className="text-lg sm:text-xl font-black text-white flex items-center gap-2">
              <span>{companion.name}</span>
              <span className="text-xs font-bold text-emerald-300">
                (Seviye {companion.level} • {companion.xp} XP)
              </span>
            </h3>

            {/* Speech Bubble */}
            <div className="bg-slate-950/85 border border-white/15 rounded-2xl px-3.5 py-2 text-xs sm:text-sm text-amber-100 font-semibold shadow-inner">
              💬 &ldquo;{speechBubble}&rdquo;
            </div>
          </div>
        </div>

        {/* Right: XP Bar, Hunger & Energy Meters */}
        <div className="w-full md:w-64 bg-slate-950/70 border border-white/10 rounded-2xl p-3 space-y-2 shrink-0">
          <div>
            <div className="flex justify-between text-[11px] font-bold text-slate-300 mb-1">
              <span className="flex items-center gap-1">
                <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                Evrim XP ({xpInCurrentLevel}/100)
              </span>
              <span className="text-amber-300">
                Sonraki Evrim: Lv.{companion.level + 1}
              </span>
            </div>
            <div className="w-full h-2.5 bg-slate-800 rounded-full overflow-hidden">
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${xpInCurrentLevel}%` }}
                className="h-full bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 rounded-full"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 pt-1 text-[11px]">
            <div className="bg-slate-900/90 rounded-xl px-2.5 py-1.5 flex items-center justify-between border border-slate-800">
              <span className="text-slate-400 flex items-center gap-1">
                <Utensils className="w-3 h-3 text-emerald-400" /> Tokluk
              </span>
              <span
                className={`font-black ${
                  isHungryOrSleepy ? 'text-amber-400' : 'text-emerald-400'
                }`}
              >
                %{isHungryOrSleepy ? 45 : companion.hunger || 95}
              </span>
            </div>
            <div className="bg-slate-900/90 rounded-xl px-2.5 py-1.5 flex items-center justify-between border border-slate-800">
              <span className="text-slate-400 flex items-center gap-1">
                <Zap className="w-3 h-3 text-cyan-400" /> Enerji
              </span>
              <span className="font-black text-cyan-300">
                %{isHungryOrSleepy ? 50 : companion.energy || 100}
              </span>
            </div>
          </div>

          {isHungryOrSleepy && onStartQuickTask && (
            <button
              type="button"
              onClick={onStartQuickTask}
              className="w-full py-1.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-black text-xs transition"
            >
              🍖 Görev Yap & Yoldaşını Besle (+20 XP)
            </button>
          )}
        </div>
      </div>

      {/* Customize Companion Drawer */}
      <AnimatePresence>
        {showCustomize && (
          <motion.form
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            onSubmit={handleSaveCustomization}
            className="mt-4 pt-3 border-t border-white/15 flex flex-wrap items-center justify-between gap-3"
          >
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-bold text-slate-300">Tür Seç:</span>
              {(['dragon', 'cat', 'robot', 'alien'] as CompanionType[]).map(
                (tKey) => (
                  <button
                    key={tKey}
                    type="button"
                    onClick={() => setCustomType(tKey)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-bold border transition ${
                      customType === tKey
                        ? 'bg-amber-400 text-slate-950 border-amber-200'
                        : 'bg-slate-900 text-slate-300 border-slate-700'
                    }`}
                  >
                    {COMPANION_SPECIES[tKey].stages[1].emoji}{' '}
                    {COMPANION_SPECIES[tKey].label}
                  </button>
                )
              )}
            </div>

            <div className="flex items-center gap-2">
              <input
                type="text"
                value={customName}
                onChange={(e) => setCustomName(e.target.value)}
                placeholder="Yoldaş Adı"
                className="bg-slate-950 border border-slate-700 rounded-xl px-3 py-1.5 text-xs text-white font-bold"
              />
              <button
                type="submit"
                className="px-4 py-1.5 rounded-xl bg-emerald-500 text-slate-950 font-black text-xs"
              >
                Kaydet
              </button>
            </div>
          </motion.form>
        )}
      </AnimatePresence>
    </div>
  );
};
