'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ShieldCheck,
  Monitor,
  Tablet,
  Smartphone,
  Lock,
  ExternalLink,
  Bell,
  X,
  Radio,
  Users,
  Plus,
  KeyRound,
  LogOut,
} from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { DevicePlatform, UserProfile } from '@/types/database';

export const TopFamilyBar: React.FC = () => {
  const {
    families,
    activeFamily,
    switchFamilyById,
    switchFamilyByCode,
    createNewFamily,
    users,
    activeUser,
    activeDeviceType,
    setActiveUserById,
    setActiveDeviceType,
    liveAlerts,
    dismissAlert,
    isLiveSupabase,
    logout,
  } = useFamilyRealtime();

  const [pendingParentTarget, setPendingParentTarget] =
    useState<UserProfile | null>(null);
  const [pinInput, setPinInput] = useState('');
  const [pinError, setPinError] = useState(false);

  // Multi-Tenant Family Switcher & Onboarding Modal State
  const [showFamilyModal, setShowFamilyModal] = useState(false);
  const [familyModalTab, setFamilyModalTab] = useState<'switch' | 'create'>('switch');
  const [joinCodeInput, setJoinCodeInput] = useState('');
  const [newFamName, setNewFamName] = useState('');
  const [newFamCode, setNewFamCode] = useState('');
  const [newFamPin, setNewFamPin] = useState('1234');
  const [newMomName, setNewMomName] = useState('Anne');
  const [newDadName, setNewDadName] = useState('Baba');
  const [familyModalFeedback, setFamilyModalFeedback] = useState<string | null>(null);

  const expectedPin =
    activeFamily?.parent_pin || process.env.NEXT_PUBLIC_PARENT_PIN || '1234';

  const handleSelectProfile = (target: UserProfile) => {
    if (activeUser.role === 'child' && target.role === 'parent') {
      setPendingParentTarget(target);
      setPinInput('');
      setPinError(false);
      return;
    }
    setActiveUserById(target.id);
  };

  const handleVerifyPin = (e: React.FormEvent) => {
    e.preventDefault();
    if (pinInput === expectedPin && pendingParentTarget) {
      setActiveUserById(pendingParentTarget.id);
      setPendingParentTarget(null);
      setPinInput('');
    } else {
      setPinError(true);
    }
  };

  const handleJoinByCode = (e: React.FormEvent) => {
    e.preventDefault();
    if (!joinCodeInput.trim()) return;
    const res = switchFamilyByCode(joinCodeInput);
    setFamilyModalFeedback(res.message);
    if (res.success) {
      setTimeout(() => {
        setShowFamilyModal(false);
        setFamilyModalFeedback(null);
      }, 900);
    }
  };

  const handleCreateFamily = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFamName.trim() || !newFamCode.trim()) return;
    const res = await createNewFamily({
      name: newFamName,
      familyCode: newFamCode,
      parentPin: newFamPin,
      momName: newMomName,
      dadName: newDadName,
    });
    setFamilyModalFeedback(res.message);
    if (res.success) {
      setNewFamName('');
      setNewFamCode('');
      setTimeout(() => {
        setShowFamilyModal(false);
        setFamilyModalFeedback(null);
      }, 900);
    }
  };

  const openParallelDeviceWindow = () => {
    if (typeof window !== 'undefined') {
      window.open(window.location.href, '_blank');
    }
  };

  return (
    <>
      <header
        data-allow-touch="true"
        className="sticky top-0 z-40 bg-slate-950/90 backdrop-blur-xl border-b border-slate-800 px-3 sm:px-6 py-2.5 text-white"
      >
        <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3">
          {/* Brand, Active Family Badge & Realtime Engine Status */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl overflow-hidden bg-slate-900 border border-slate-700/60 shadow-lg flex items-center justify-center shrink-0">
              <img
                src={activeUser.role === 'student' ? 'kids-logo.png' : 'family-logo.png'}
                alt="FamilyOS Logo"
                className="w-full h-full object-cover"
                onError={(e) => {
                  (e.currentTarget as HTMLImageElement).src = 'icon-192.png';
                }}
              />
            </div>
            <div>
              <div className="font-black text-sm sm:text-base tracking-tight flex flex-wrap items-center gap-2">
                <span>FamilyToStudy</span>
                <button
                  type="button"
                  onClick={() => {
                    setShowFamilyModal(true);
                    setFamilyModalFeedback(null);
                  }}
                  className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-indigo-500/20 hover:bg-indigo-500/35 border border-indigo-400/40 text-indigo-200 text-[11px] font-extrabold transition"
                >
                  <Users className="w-3 h-3 text-indigo-300" />
                  <span>{activeFamily.name}</span>
                  <span className="text-[10px] text-amber-300 font-mono">
                    [{activeFamily.family_code}]
                  </span>
                </button>
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 text-[10px] font-bold">
                  <Radio className="w-3 h-3 animate-pulse" />
                  {isLiveSupabase
                    ? 'Supabase Realtime Aktif'
                    : 'Canlı Çoklu-Cihaz Senkron Aktif'}
                </span>
              </div>
              <p className="text-[11px] text-slate-400 hidden sm:block">
                Çoklu Aile (Multi-Tenant) Oyunlaştırılmış Akademi & Kalkan Sistemi
              </p>
            </div>
          </div>

          {/* Fast Family Profile Switcher (Scoped to Active Family & PIN Protected for Parents) */}
          <div className="flex items-center gap-1.5 bg-slate-900 p-1 rounded-2xl border border-slate-800 overflow-x-auto">
            {users.map((u) => {
              const isSelected = u.id === activeUser.id;
              return (
                <button
                  key={u.id}
                  type="button"
                  onClick={() => handleSelectProfile(u)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-extrabold transition flex items-center gap-1.5 shrink-0 ${
                    isSelected
                      ? u.role === 'parent'
                        ? 'bg-gradient-to-r from-rose-600 to-indigo-600 text-white shadow'
                        : 'bg-gradient-to-r from-indigo-600 to-violet-600 text-white shadow'
                      : 'text-slate-400 hover:text-white hover:bg-slate-800'
                  }`}
                >
                  <span>{u.avatar_config.emoji}</span>
                  <span>{u.name.split(' ')[0]}</span>
                  {u.role === 'parent' && activeUser.role === 'child' && (
                    <Lock className="w-3 h-3 text-amber-400" />
                  )}
                </button>
              );
            })}
          </div>

          {/* Device Type Simulator & Open Parallel Tab Button */}
          <div className="flex items-center gap-2">
            <div className="hidden md:flex items-center gap-1 bg-slate-900 p-1 rounded-xl border border-slate-800 text-xs">
              {(
                [
                  { id: 'windows_pc', label: 'PC', icon: Monitor },
                  { id: 'tablet', label: 'Tablet', icon: Tablet },
                  { id: 'ios_phone', label: 'iOS', icon: Smartphone },
                ] as { id: DevicePlatform; label: string; icon: typeof Monitor }[]
              ).map((plat) => {
                const IconComp = plat.icon;
                return (
                  <button
                    key={plat.id}
                    type="button"
                    onClick={() => setActiveDeviceType(plat.id)}
                    className={`px-2 py-1 rounded-lg flex items-center gap-1 font-bold transition ${
                      activeDeviceType === plat.id
                        ? 'bg-indigo-600 text-white'
                        : 'text-slate-400 hover:text-white'
                    }`}
                  >
                    <IconComp className="w-3.5 h-3.5" />
                    <span>{plat.label}</span>
                  </button>
                );
              })}
            </div>

            <button
              type="button"
              onClick={openParallelDeviceWindow}
              title="Senkronizasyonu test etmek için yan sekmede ikinci bir cihaz aç"
              className="px-2.5 py-1.5 rounded-xl bg-indigo-500/20 hover:bg-indigo-500/30 border border-indigo-400/30 text-indigo-200 text-xs font-bold flex items-center gap-1.5 transition"
            >
              <ExternalLink className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">2. Cihaz Sekmesi Aç</span>
            </button>

            {/* Logout Button */}
            <button
              type="button"
              onClick={logout}
              title="Oturumu Kapat (Cihaz Mührünü Kaldır)"
              className="px-2.5 py-1.5 rounded-xl bg-rose-500/15 hover:bg-rose-500/30 border border-rose-500/30 text-rose-300 text-xs font-bold flex items-center gap-1.5 transition"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Çıkış</span>
            </button>
          </div>
        </div>
      </header>

      {/* Live Realtime Alert Banners */}
      <div
        data-allow-touch="true"
        className="max-w-7xl mx-auto px-3 sm:px-6 pt-2 space-y-2"
      >
        <AnimatePresence>
          {liveAlerts.slice(0, 2).map((alert) => (
            <motion.div
              key={alert.id}
              initial={{ opacity: 0, y: -15 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -15 }}
              className={`rounded-2xl px-4 py-3 border shadow-lg flex items-center justify-between gap-3 text-xs sm:text-sm ${
                alert.type === 'violation'
                  ? 'bg-rose-950/95 border-rose-500 text-rose-100'
                  : alert.type === 'wakeup'
                  ? 'bg-amber-950/95 border-amber-400 text-amber-100'
                  : alert.type === 'flash_quest'
                  ? 'bg-orange-950/95 border-orange-400 text-orange-100'
                  : 'bg-indigo-950/95 border-indigo-400 text-indigo-100'
              }`}
            >
              <div className="flex items-center gap-2.5">
                <Bell className="w-4 h-4 shrink-0 animate-bounce" />
                <div>
                  <span className="font-black mr-2">{alert.title}</span>
                  <span className="opacity-90">{alert.message}</span>
                  <span className="ml-2 text-[10px] opacity-60">
                    ({alert.timestamp})
                  </span>
                </div>
              </div>
              <button
                type="button"
                onClick={() => dismissAlert(alert.id)}
                className="p-1 rounded-lg hover:bg-white/10"
              >
                <X className="w-4 h-4" />
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

      {/* Multi-Tenant Family Switcher & New Family Onboarding Modal */}
      {showFamilyModal && (
        <div
          data-allow-touch="true"
          className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4"
        >
          <motion.div
            initial={{ scale: 0.92, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-slate-900 border border-indigo-500/40 rounded-3xl max-w-lg w-full p-6 text-white shadow-2xl relative"
          >
            <button
              type="button"
              onClick={() => setShowFamilyModal(false)}
              className="absolute top-4 right-4 p-2 rounded-full bg-slate-800 hover:bg-slate-700 text-slate-300"
            >
              <X className="w-4 h-4" />
            </button>

            <div className="flex items-center gap-2.5 mb-4">
              <div className="p-2.5 rounded-2xl bg-indigo-500/20 text-indigo-300">
                <Users className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-lg font-black">
                  Çoklu Aile (Multi-Tenant) Yönetimi
                </h3>
                <p className="text-xs text-slate-400">
                  Her ailenin çocukları, görevleri, ödülleri ve PIN kodu tamamen izoledir.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 bg-slate-950 p-1 rounded-2xl border border-slate-800 mb-4">
              <button
                type="button"
                onClick={() => setFamilyModalTab('switch')}
                className={`flex-1 py-2 rounded-xl text-xs font-bold transition ${
                  familyModalTab === 'switch'
                    ? 'bg-indigo-600 text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Kayıtlı Aile Seç / Kodla Katıl
              </button>
              <button
                type="button"
                onClick={() => setFamilyModalTab('create')}
                className={`flex-1 py-2 rounded-xl text-xs font-bold flex items-center justify-center gap-1 transition ${
                  familyModalTab === 'create'
                    ? 'bg-emerald-500 text-slate-950 font-black'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                <Plus className="w-3.5 h-3.5" /> Yeni Aile Kaydı Oluştur
              </button>
            </div>

            {familyModalFeedback && (
              <div className="mb-4 px-3.5 py-2.5 rounded-xl bg-indigo-500/20 border border-indigo-400/40 text-indigo-200 text-xs font-bold">
                {familyModalFeedback}
              </div>
            )}

            {familyModalTab === 'switch' ? (
              <div className="space-y-4">
                <div>
                  <div className="text-xs font-bold text-slate-400 uppercase mb-2">
                    Hızlı Aile Seçimi (Demo & Aktif Aileler)
                  </div>
                  <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                    {families.map((fam) => {
                      const isCurrent = fam.id === activeFamily.id;
                      return (
                        <button
                          key={fam.id}
                          type="button"
                          onClick={() => {
                            switchFamilyById(fam.id);
                            setShowFamilyModal(false);
                          }}
                          className={`w-full p-3.5 rounded-2xl border text-left flex items-center justify-between transition ${
                            isCurrent
                              ? 'bg-indigo-600/25 border-indigo-400 text-white'
                              : 'bg-slate-950/80 border-slate-800 hover:border-slate-700 text-slate-200'
                          }`}
                        >
                          <div>
                            <div className="font-black text-sm">{fam.name}</div>
                            <div className="text-xs text-slate-400">
                              Davet Kodu:{' '}
                              <code className="text-amber-300 font-bold">
                                {fam.family_code}
                              </code>{' '}
                              • PIN: <code className="text-emerald-300">{fam.parent_pin}</code>
                            </div>
                          </div>
                          <span className="text-xs font-bold px-3 py-1 rounded-xl bg-white/10">
                            {isCurrent ? 'Aktif Aile' : 'Geçiş Yap →'}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <form
                  onSubmit={handleJoinByCode}
                  className="pt-3 border-t border-slate-800 flex items-center gap-2"
                >
                  <div className="relative flex-1">
                    <KeyRound className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                    <input
                      type="text"
                      value={joinCodeInput}
                      onChange={(e) => setJoinCodeInput(e.target.value)}
                      placeholder="Aile Kodu ile Katıl (Örn: YILMAZ-2026)"
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl pl-9 pr-3 py-2 text-xs text-white"
                    />
                  </div>
                  <button
                    type="submit"
                    className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs"
                  >
                    Bağlan
                  </button>
                </form>
              </div>
            ) : (
              <form onSubmit={handleCreateFamily} className="space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1">
                      Aile Adı
                    </label>
                    <input
                      type="text"
                      required
                      value={newFamName}
                      onChange={(e) => setNewFamName(e.target.value)}
                      placeholder="Örn: Kaya Ailesi"
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1">
                      Benzersiz Aile Kodu
                    </label>
                    <input
                      type="text"
                      required
                      value={newFamCode}
                      onChange={(e) => setNewFamCode(e.target.value.toUpperCase())}
                      placeholder="Örn: KAYA-2026"
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2.5">
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1">
                      Anne Adı
                    </label>
                    <input
                      type="text"
                      value={newMomName}
                      onChange={(e) => setNewMomName(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1">
                      Baba Adı
                    </label>
                    <input
                      type="text"
                      value={newDadName}
                      onChange={(e) => setNewDadName(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1">
                      Ebeveyn PIN (4 Hane)
                    </label>
                    <input
                      type="text"
                      maxLength={4}
                      value={newFamPin}
                      onChange={(e) => setNewFamPin(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono text-center"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  className="w-full py-3 rounded-2xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-black text-xs sm:text-sm shadow-lg transition"
                >
                  🚀 Yeni Aileyi Oluştur & Başlat
                </button>
              </form>
            )}
          </motion.div>
        </div>
      )}

      {/* 4-Digit Parent PIN Protection Modal */}
      {pendingParentTarget && (
        <div
          data-allow-touch="true"
          className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4"
        >
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-slate-900 border border-indigo-500/40 rounded-3xl max-w-sm w-full p-6 text-white text-center shadow-2xl"
          >
            <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center mx-auto mb-3">
              <ShieldCheck className="w-7 h-7" />
            </div>
            <h3 className="text-lg font-black mb-1">
              {activeFamily.name} — Ebeveyn PIN Koruması
            </h3>
            <p className="text-xs text-slate-400 mb-4">
              <strong>{pendingParentTarget.name}</strong> ekranına geçmek için 4
              haneli Ebeveyn PIN kodunu girin (Aile PIN:{' '}
              <code className="text-amber-300 font-bold">{expectedPin}</code>)
            </p>

            <form onSubmit={handleVerifyPin} className="space-y-3">
              <input
                type="password"
                maxLength={4}
                autoFocus
                value={pinInput}
                onChange={(e) => {
                  setPinInput(e.target.value);
                  setPinError(false);
                }}
                placeholder="••••"
                className="w-full text-center text-2xl tracking-[0.5em] font-black bg-slate-950 border border-slate-700 rounded-2xl py-3 text-white focus:outline-none focus:border-indigo-500"
              />
              {pinError && (
                <p className="text-xs text-rose-400 font-bold">
                  Hatalı PIN kodu! ({activeFamily.name} PIN: {expectedPin})
                </p>
              )}

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setPendingParentTarget(null)}
                  className="flex-1 py-2.5 rounded-xl bg-slate-800 text-slate-300 font-bold text-xs"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-black text-xs"
                >
                  Giriş Yap
                </button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </>
  );
};
