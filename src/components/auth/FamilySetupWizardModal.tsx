'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, Users, UserPlus, Trash2, CheckCircle2, ShieldCheck, ArrowRight } from 'lucide-react';

interface MemberDraft {
  name: string;
  role: 'parent' | 'child';
  grade: string;
  ageGroup: 'kid' | 'preteen' | 'teen' | 'adult';
  emoji: string;
}

interface FamilySetupWizardModalProps {
  isOpen: boolean;
  ownerEmail?: string | null;
  onComplete: (data: {
    familyName: string;
    parentPin: string;
    members: MemberDraft[];
  }) => Promise<void>;
}

const EMOJI_OPTIONS = ['👨‍✈️', '👩‍🚀', '🦁', '🦄', '🦖', '🦋', '🦊', '🐼', '🚀', '⭐'];

export const FamilySetupWizardModal: React.FC<FamilySetupWizardModalProps> = ({
  isOpen,
  ownerEmail,
  onComplete,
}) => {
  const [step, setStep] = useState<1 | 2>(1);
  const [familyName, setFamilyName] = useState('');
  const [parentPin, setParentPin] = useState('1234');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [members, setMembers] = useState<MemberDraft[]>([
    {
      name: 'Ebeveyn (Ben)',
      role: 'parent',
      grade: 'Yetişkin',
      ageGroup: 'adult',
      emoji: '👨‍✈️',
    },
    {
      name: 'Eşim',
      role: 'parent',
      grade: 'Yetişkin',
      ageGroup: 'adult',
      emoji: '👩‍🚀',
    },
    {
      name: 'Öğrenci 1',
      role: 'child',
      grade: '4. Sınıf',
      ageGroup: 'kid',
      emoji: '🦁',
    },
  ]);

  if (!isOpen) return null;

  const handleAddChild = () => {
    setMembers((prev) => [
      ...prev,
      {
        name: `Çocuk ${prev.filter((m) => m.role === 'child').length + 1}`,
        role: 'child',
        grade: '3. Sınıf',
        ageGroup: 'kid',
        emoji: '🦄',
      },
    ]);
  };

  const handleRemoveMember = (idx: number) => {
    if (members.length <= 1) return;
    setMembers((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleUpdateMember = (
    idx: number,
    field: keyof MemberDraft,
    val: string
  ) => {
    setMembers((prev) =>
      prev.map((m, i) => (i === idx ? { ...m, [field]: val } : m))
    );
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!familyName.trim()) {
      setErrorMsg('Lütfen aileniz için bir isim girin (Örn: Kaya Ailesi)');
      return;
    }
    if (members.length === 0) {
      setErrorMsg('Lütfen en az bir aile bireyi ekleyin.');
      return;
    }

    setIsSubmitting(true);
    setErrorMsg(null);
    try {
      await onComplete({
        familyName: familyName.trim(),
        parentPin: parentPin || '1234',
        members,
      });
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Aile kurulumu sırasında bir hata oluştu.');
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-950/90 backdrop-blur-md">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 15 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        className="w-full max-w-2xl bg-slate-900 border border-indigo-500/30 rounded-3xl p-5 sm:p-7 shadow-2xl space-y-6 text-white max-h-[92vh] overflow-y-auto"
      >
        {/* Wizard Header */}
        <div className="flex items-center gap-3 border-b border-slate-800 pb-4">
          <div className="w-12 h-12 rounded-2xl overflow-hidden bg-slate-950 border border-indigo-400/40 flex items-center justify-center p-1 shadow-lg shrink-0">
            <img
              src="family-logo.png"
              alt="Family Logo"
              className="w-full h-full object-contain rounded-xl"
              onError={(e) => {
                (e.currentTarget as HTMLImageElement).src = 'icon-192.png';
              }}
            />
          </div>
          <div>
            <div className="flex items-center gap-2 text-xs font-bold text-indigo-400 uppercase tracking-wider">
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>Multi-Tenant Güvenli Aile Kurulumu (Faz 6)</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-black">
              {step === 1 ? '🌟 Ailenizi Oluşturun' : '👨‍👩‍👧‍👦 Aile Bireylerini Tanımlayın'}
            </h2>
            {ownerEmail && (
              <p className="text-xs text-slate-400">
                Bağlı Google Hesabı: <span className="text-emerald-400 font-mono">{ownerEmail}</span>
              </p>
            )}
          </div>
        </div>

        {errorMsg && (
          <div className="p-3.5 rounded-2xl bg-rose-500/20 border border-rose-500/40 text-rose-300 text-xs font-bold">
            ⚠️ {errorMsg}
          </div>
        )}

        {/* STEP 1: AİLE ADI VE EBEVEYN KORUMA PİNİ */}
        {step === 1 && (
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                Aile İsmi
              </label>
              <input
                type="text"
                required
                placeholder="Örn: Özdemir Ailesi veya Kaya Hanedanı"
                value={familyName}
                onChange={(e) => setFamilyName(e.target.value)}
                className="w-full px-4 py-3 rounded-2xl bg-slate-950 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-indigo-400 transition"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                Ebeveyn Koruma Pini (4 Haneli)
              </label>
              <input
                type="password"
                maxLength={4}
                value={parentPin}
                onChange={(e) => setParentPin(e.target.value.replace(/\D/g, ''))}
                className="w-full px-4 py-3 rounded-2xl bg-slate-950 border border-slate-700 text-white font-mono font-bold text-base focus:outline-none focus:border-indigo-400 transition tracking-widest text-center"
              />
              <span className="text-[11px] text-slate-400 block mt-1">
                Çocukların ebeveyn paneline izinsiz geçişini engellemek için kullanılır.
              </span>
            </div>

            <div className="p-4 rounded-2xl bg-indigo-950/40 border border-indigo-500/20 text-xs text-indigo-200 leading-relaxed space-y-1">
              <p className="font-bold text-white flex items-center gap-1.5">
                <ShieldCheck className="w-4 h-4 text-emerald-400" /> Tam Aile İzolasyonu & Güvenlik
              </p>
              <p>
                Sistem yalnızca sizin ailenize özel şifreli bir kimlik (`family_id`) oluşturacaktır.
                Dışarıdan kimse verilerinizi veya çocuklarınızın görevlerini göremez.
              </p>
            </div>

            <button
              type="button"
              onClick={() => {
                if (!familyName.trim()) {
                  setErrorMsg('Lütfen aileniz için bir isim girin.');
                  return;
                }
                setErrorMsg(null);
                setStep(2);
              }}
              className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-400 hover:to-purple-500 text-white font-black text-sm flex items-center justify-center gap-2 shadow-lg transition"
            >
              <span>Sonraki Adım: Bireyleri Ekle</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* STEP 2: AİLE BİREYLERİNİ EKLEME VE ÖZELLEŞTİRME */}
        {step === 2 && (
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-300">
                Bireyler ({members.length})
              </span>
              <button
                type="button"
                onClick={handleAddChild}
                className="px-3 py-1.5 rounded-xl bg-indigo-600/30 hover:bg-indigo-600/50 border border-indigo-500/40 text-indigo-200 text-xs font-bold flex items-center gap-1.5 transition"
              >
                <UserPlus className="w-3.5 h-3.5" />
                <span>+ Çocuk Ekle</span>
              </button>
            </div>

            <div className="space-y-3">
              {members.map((member, idx) => (
                <div
                  key={idx}
                  className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 flex flex-wrap items-center gap-2 sm:gap-3"
                >
                  {/* Emoji selector */}
                  <select
                    value={member.emoji}
                    onChange={(e) => handleUpdateMember(idx, 'emoji', e.target.value)}
                    className="w-12 h-10 rounded-xl bg-slate-900 border border-slate-700 text-xl text-center focus:outline-none"
                  >
                    {EMOJI_OPTIONS.map((em) => (
                      <option key={em} value={em}>
                        {em}
                      </option>
                    ))}
                  </select>

                  {/* Name Input */}
                  <input
                    type="text"
                    required
                    placeholder="Birey Adı"
                    value={member.name}
                    onChange={(e) => handleUpdateMember(idx, 'name', e.target.value)}
                    className="flex-1 min-w-[130px] px-3 py-2 rounded-xl bg-slate-900 border border-slate-700 text-xs font-bold text-white focus:outline-none focus:border-indigo-400"
                  />

                  {/* Role Selector */}
                  <select
                    value={member.role}
                    onChange={(e) => handleUpdateMember(idx, 'role', e.target.value as 'parent' | 'child')}
                    className="px-2.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-xs font-bold text-slate-200 focus:outline-none"
                  >
                    <option value="parent">Ebeveyn</option>
                    <option value="child">Öğrenci</option>
                  </select>

                  {/* Grade / Info */}
                  {member.role === 'child' && (
                    <input
                      type="text"
                      placeholder="Sınıf / Yaş"
                      value={member.grade}
                      onChange={(e) => handleUpdateMember(idx, 'grade', e.target.value)}
                      className="w-24 px-2.5 py-2 rounded-xl bg-slate-900 border border-slate-700 text-xs text-white font-medium focus:outline-none"
                    />
                  )}

                  {members.length > 1 && (
                    <button
                      type="button"
                      onClick={() => handleRemoveMember(idx)}
                      className="p-2 rounded-xl text-rose-400 hover:bg-rose-500/20 transition"
                      title="Kaldır"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
            </div>

            <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-200 text-xs font-medium space-y-1">
              <p className="font-bold text-amber-100">
                🔑 Otomatik Şifre & Sihirli Linkler Hazırlanacak
              </p>
              <p>
                Her aile bireyine özel 6 haneli şifre, hazır giriş linki ve masaüstü eşleştirme kodu
                kurulum tamamlandığında otomatik oluşturulacaktır.
              </p>
            </div>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setStep(1)}
                className="w-1/3 py-3 rounded-2xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold text-xs transition"
              >
                Geri
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex-1 py-3.5 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-black text-sm flex items-center justify-center gap-2 shadow-lg transition disabled:opacity-50"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>{isSubmitting ? 'Kuruluyor...' : 'Aileyi Kur ve Başlat'}</span>
              </button>
            </div>
          </form>
        )}
      </motion.div>
    </div>
  );
};
