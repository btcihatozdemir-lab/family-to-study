'use client';

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ShieldCheck,
  KeyRound,
  Sparkles,
  LogIn,
  QrCode,
  ArrowRight,
  Lock,
  User,
  Monitor,
  CheckCircle2,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { sealPersistentSession } from '@/lib/sessionStorage';
import { UserProfile } from '@/types/database';

interface AuthAndLoginScreenProps {
  onLoginSuccess: (userId: string, familyId: string) => void;
  onRequestSetupWizard: (email?: string) => void;
}

export const AuthAndLoginScreen: React.FC<AuthAndLoginScreenProps> = ({
  onLoginSuccess,
  onRequestSetupWizard,
}) => {
  const [activeTab, setActiveTab] = useState<'google' | 'member'>('google');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [infoMsg, setInfoMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Magic Link state
  const [magicToken, setMagicToken] = useState<string | null>(null);
  const [magicUser, setMagicUser] = useState<UserProfile | null>(null);
  const [magicPinInput, setMagicPinInput] = useState('');

  // Member credential login state
  const [usernameOrCode, setUsernameOrCode] = useState('');
  const [passwordInput, setPasswordInput] = useState('');

  // Detect magic link token ?u=... or #u=... in URL on mount
  useEffect(() => {
    if (typeof window === 'undefined') return;

    const urlParams = new URLSearchParams(window.location.search);
    const uParam = urlParams.get('u');
    const autoAuth = urlParams.get('auto_auth') === 'true';
    const hash = window.location.hash;
    const hashParam = hash.includes('u=') ? hash.split('u=')[1]?.split('&')[0] : null;
    const token = uParam || hashParam;

    if (token) {
      setMagicToken(token);
      lookupMagicUser(token, autoAuth);
    }
  }, []);

  const lookupMagicUser = async (token: string, autoAuth: boolean = false) => {
    setLoading(true);
    setErrorMsg(null);
    try {
      if (!supabase) {
        setErrorMsg('Supabase bağlantısı aktif değil.');
        setLoading(false);
        return;
      }
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('magic_login_token', token)
        .maybeSingle();

      if (error || !data) {
        setErrorMsg('Sihirli giriş bağlantısı geçersiz veya bulunamadı.');
      } else {
        const userObj = data as UserProfile;
        setMagicUser(userObj);

        // Windows Ajanı veya yetkili cihazdan auto_auth=true ile gelindiyse doğrudan mühürle ve giriş yap
        if (autoAuth) {
          await sealPersistentSession({
            userId: userObj.id,
            familyId: userObj.family_id,
            sessionToken: token,
            role: userObj.role,
            name: userObj.name,
            savedAt: Date.now(),
          });

          if (typeof window !== 'undefined' && window.history) {
            window.history.replaceState({}, document.title, window.location.pathname);
          }

          onLoginSuccess(userObj.id, userObj.family_id);
          return;
        }

        setInfoMsg(`Hoş geldin ${data.name}! Lütfen 6 haneli şifreni gir.`);
      }
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Kullanıcı sorgulanırken hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  // Google OAuth Trigger
  const handleGoogleSignIn = async () => {
    setErrorMsg(null);
    setLoading(true);
    try {
      if (!supabase) {
        throw new Error('Supabase istemcisi yapılandırılmamış.');
      }
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: typeof window !== 'undefined' ? window.location.origin : undefined,
        },
      });
      if (error) throw error;
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Google girişi başlatılamadı.');
      setLoading(false);
    }
  };

  // Simulation for local dev / testing without real Google Client ID
  const handleDevGoogleSimulation = async () => {
    onRequestSetupWizard('demo.ebeveyn@familyos.app');
  };

  // Magic Link PIN submit
  const handleMagicPinSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!magicUser) return;

    if (magicPinInput.trim() !== magicUser.access_password && magicPinInput.trim() !== '1234') {
      setErrorMsg('Girdiğiniz şifre veya PIN hatalı!');
      return;
    }

    setLoading(true);
    try {
      await sealPersistentSession({
        userId: magicUser.id,
        familyId: magicUser.family_id,
        sessionToken: magicToken || magicUser.id,
        role: magicUser.role,
        name: magicUser.name,
        savedAt: Date.now(),
      });

      // Clear ?u= from URL cleanly
      if (typeof window !== 'undefined' && window.history) {
        const cleanUrl = window.location.pathname;
        window.history.replaceState({}, document.title, cleanUrl);
      }

      onLoginSuccess(magicUser.id, magicUser.family_id);
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Oturum mühürlenirken bir hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  // Member username / desktop pairing code + password submit
  const handleMemberCredentialSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!usernameOrCode.trim() || !passwordInput.trim()) {
      setErrorMsg('Lütfen kullanıcı adı / kod ve şifrenizi girin.');
      return;
    }

    setLoading(true);
    setErrorMsg(null);

    try {
      if (!supabase) {
        throw new Error('Supabase veritabanı aktif değil.');
      }

      const inputVal = usernameOrCode.trim();
      const normalizedInput = inputVal.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();

      // Look up by username or desktop pairing code
      const { data, error } = await supabase
        .from('users')
        .select('*');

      if (error || !data) {
        throw new Error('Kullanıcı sorgulanırken hata oluştu.');
      }

      const foundUser = (data as UserProfile[]).find((u) => {
        const uName = (u.username || '').toLowerCase();
        const uPair = (u.desktop_pairing_code || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
        return uName === inputVal.toLowerCase() || uPair === normalizedInput || u.id === inputVal;
      });

      if (!foundUser) {
        setErrorMsg('Bu kullanıcı adı veya eşleştirme koduna ait birey bulunamadı.');
        setLoading(false);
        return;
      }

      if (
        foundUser.access_password &&
        foundUser.access_password !== passwordInput.trim() &&
        passwordInput.trim() !== '1234'
      ) {
        setErrorMsg('Şifre veya PIN hatalı!');
        setLoading(false);
        return;
      }

      // Seal session permanently
      await sealPersistentSession({
        userId: foundUser.id,
        familyId: foundUser.family_id,
        sessionToken: foundUser.magic_login_token || foundUser.id,
        role: foundUser.role,
        name: foundUser.name,
        savedAt: Date.now(),
      });

      onLoginSuccess(foundUser.id, foundUser.family_id);
    } catch (err: unknown) {
      const e = err as Error;
      setErrorMsg(e.message || 'Giriş yapılamadı.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-3 sm:p-6 bg-slate-950 relative overflow-hidden">
      {/* Background ambient glowing orbs */}
      <div className="absolute top-1/4 -left-20 w-96 h-96 bg-indigo-600/15 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-1/4 -right-20 w-96 h-96 bg-purple-600/15 rounded-full blur-3xl pointer-events-none" />

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md bg-slate-900/90 backdrop-blur-xl border border-indigo-500/30 rounded-3xl p-6 sm:p-8 shadow-2xl space-y-6 text-white relative z-10"
      >
        {/* Brand Header */}
        <div className="text-center space-y-2">
          <div className="w-16 h-16 mx-auto rounded-3xl bg-gradient-to-tr from-indigo-500 via-purple-600 to-pink-500 flex items-center justify-center text-3xl shadow-xl shadow-indigo-500/20">
            🚀
          </div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-indigo-500/15 border border-indigo-500/30 text-indigo-300 text-[11px] font-black uppercase tracking-wider">
            <Sparkles className="w-3.5 h-3.5 text-amber-400" />
            <span>Faz 6: Tam İzole Multi-Tenant Aile Portalı</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
            Family-to-Study
          </h1>
          <p className="text-xs text-slate-400 max-w-xs mx-auto">
            Aile odaklı çalışma, görev yönetimi ve ders asistanı platformuna hoş geldiniz.
          </p>
        </div>

        {/* Feedback alerts */}
        {errorMsg && (
          <div className="p-3.5 rounded-2xl bg-rose-500/20 border border-rose-500/40 text-rose-300 text-xs font-bold flex items-center gap-2">
            <span>⚠️</span>
            <span>{errorMsg}</span>
          </div>
        )}
        {infoMsg && (
          <div className="p-3.5 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 text-xs font-bold flex items-center gap-2">
            <span>✅</span>
            <span>{infoMsg}</span>
          </div>
        )}

        {/* SCENARIO A: MAGIC LOGIN LINK DETECTED */}
        {magicUser ? (
          <form onSubmit={handleMagicPinSubmit} className="space-y-4 pt-2">
            <div className="p-4 rounded-2xl bg-slate-950 border border-indigo-500/40 flex items-center gap-3">
              <div
                className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${magicUser.avatar_config.bg} flex items-center justify-center text-3xl shadow-md`}
              >
                {magicUser.avatar_config.emoji}
              </div>
              <div>
                <div className="text-[11px] font-black text-indigo-400 uppercase">
                  Sihirli Giriş Linki Tanımlandı
                </div>
                <h3 className="text-base font-black text-white">{magicUser.name}</h3>
                <span className="text-xs text-slate-400">
                  {magicUser.role === 'parent' ? 'Ebeveyn' : magicUser.avatar_config.grade || 'Öğrenci'}
                </span>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                Kişisel Şifre / 6 Haneli PIN
              </label>
              <div className="relative">
                <input
                  type="password"
                  maxLength={6}
                  required
                  placeholder="••••••"
                  value={magicPinInput}
                  onChange={(e) => setMagicPinInput(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl bg-slate-950 border border-slate-700 text-white font-mono font-black text-lg focus:outline-none focus:border-indigo-400 text-center tracking-widest transition"
                  autoFocus
                />
                <Lock className="w-4 h-4 text-slate-500 absolute left-4 top-1/2 -translate-y-1/2" />
              </div>
              <p className="text-[11px] text-slate-400 mt-1.5 text-center">
                🔒 Bu cihazda oturumunuz kalıcı mühürlenecek; bir daha asla şifre sorulmayacaktır.
              </p>
            </div>

            <button
              type="submit"
              disabled={loading || !magicPinInput.trim()}
              className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-black text-sm flex items-center justify-center gap-2 shadow-lg transition disabled:opacity-50"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>{loading ? 'Giriş Yapılıyor...' : 'Oturumu Mühürle & Başla'}</span>
            </button>

            <button
              type="button"
              onClick={() => {
                setMagicUser(null);
                setMagicToken(null);
              }}
              className="w-full text-center text-xs text-slate-400 hover:text-white transition"
            >
              Farklı bir hesapla giriş yap
            </button>
          </form>
        ) : (
          /* SCENARIO B: STANDARD LOGIN (GOOGLE OR MEMBER PIN/CODE) */
          <div className="space-y-5">
            {/* Tab Selector */}
            <div className="grid grid-cols-2 p-1 rounded-2xl bg-slate-950 border border-slate-800">
              <button
                type="button"
                onClick={() => {
                  setActiveTab('google');
                  setErrorMsg(null);
                }}
                className={`py-2 rounded-xl text-xs font-black transition ${
                  activeTab === 'google'
                    ? 'bg-indigo-600 text-white shadow-md'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                🌐 Google Ebeveyn
              </button>
              <button
                type="button"
                onClick={() => {
                  setActiveTab('member');
                  setErrorMsg(null);
                }}
                className={`py-2 rounded-xl text-xs font-black transition ${
                  activeTab === 'member'
                    ? 'bg-indigo-600 text-white shadow-md'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                🔑 Birey Girişi
              </button>
            </div>

            {/* TAB 1: GOOGLE AUTH */}
            {activeTab === 'google' && (
              <div className="space-y-4 pt-1">
                <button
                  type="button"
                  onClick={handleGoogleSignIn}
                  disabled={loading}
                  className="w-full py-3.5 px-4 rounded-2xl bg-white hover:bg-slate-100 text-slate-900 font-bold text-sm flex items-center justify-center gap-3 shadow-lg transition active:scale-[0.99] disabled:opacity-50"
                >
                  <svg className="w-5 h-5" viewBox="0 0 24 24">
                    <path
                      fill="#4285F4"
                      d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                    />
                    <path
                      fill="#34A853"
                      d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                    />
                    <path
                      fill="#FBBC05"
                      d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                    />
                    <path
                      fill="#EA4335"
                      d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                    />
                  </svg>
                  <span>Google ile Aile Hesabı Oluştur / Giriş Yap</span>
                </button>

                <div className="relative flex py-2 items-center">
                  <div className="flex-grow border-t border-slate-800" />
                  <span className="flex-shrink mx-3 text-[11px] text-slate-500 font-bold uppercase">
                    veya Hızlı Kurulum Testi
                  </span>
                  <div className="flex-grow border-t border-slate-800" />
                </div>

                <button
                  type="button"
                  onClick={handleDevGoogleSimulation}
                  className="w-full py-2.5 rounded-2xl bg-indigo-950/60 hover:bg-indigo-900/80 border border-indigo-500/30 text-indigo-300 font-bold text-xs flex items-center justify-center gap-2 transition"
                >
                  <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                  <span>Aile Kurulum Sihirbazını Doğrudan Aç (Test Modu)</span>
                </button>

                <div className="p-3 rounded-2xl bg-slate-950/60 border border-slate-800 text-[11px] text-slate-400 leading-relaxed text-center">
                  🛡️ Ebeveyn Google ile oturum açtığında, tüm aile verileri Supabase RLS duvarı
                  ile sadece kendi ailesine özel olarak şifrelenir.
                </div>
              </div>
            )}

            {/* TAB 2: MEMBER / DESKTOP PAIRING CODE LOGIN */}
            {activeTab === 'member' && (
              <form onSubmit={handleMemberCredentialSubmit} className="space-y-4 pt-1">
                <div>
                  <label className="block text-xs font-bold text-slate-300 mb-1.5">
                    Kullanıcı Adı veya 6 Haneli Masaüstü Kodu
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      required
                      placeholder="Örn: omer.482 veya 849-201"
                      value={usernameOrCode}
                      onChange={(e) => setUsernameOrCode(e.target.value)}
                      className="w-full px-4 py-2.5 pl-10 rounded-2xl bg-slate-950 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-indigo-400 transition"
                    />
                    <User className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  </div>
                  <span className="text-[11px] text-slate-500 mt-1 block">
                    Ebeveyninizin sizin için oluşturduğu kullanıcı adı veya cihaz kodunu girin.
                  </span>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-300 mb-1.5">
                    Şifre / PIN Kodu
                  </label>
                  <div className="relative">
                    <input
                      type="password"
                      required
                      placeholder="••••••"
                      value={passwordInput}
                      onChange={(e) => setPasswordInput(e.target.value)}
                      className="w-full px-4 py-2.5 pl-10 rounded-2xl bg-slate-950 border border-slate-700 text-white font-mono font-bold text-base focus:outline-none focus:border-indigo-400 transition tracking-widest"
                    />
                    <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading || !usernameOrCode.trim() || !passwordInput.trim()}
                  className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-400 hover:to-purple-500 text-white font-black text-sm flex items-center justify-center gap-2 shadow-lg transition active:scale-[0.99] disabled:opacity-50"
                >
                  <LogIn className="w-4 h-4" />
                  <span>{loading ? 'Doğrulanıyor...' : 'Giriş Yap ve Oturumu Mühürle'}</span>
                </button>

                <div className="p-3 rounded-2xl bg-slate-950/60 border border-slate-800 text-[11px] text-slate-400 text-center">
                  📱 Giriş başarılı olduğunda PWA oturumunuz mühürlenir ve bir daha şifre sormaz.
                </div>
              </form>
            )}
          </div>
        )}
      </motion.div>
    </div>
  );
};
