'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Users,
  UserCheck,
  UserPlus,
  Trash2,
  Edit3,
  KeyRound,
  QrCode,
  Share2,
  Copy,
  CheckCircle2,
  X,
  Shield,
  Eye,
  EyeOff,
  RefreshCw,
  AlertTriangle,
  Heart,
  Sparkles,
  Smartphone,
  Monitor,
  GraduationCap,
} from 'lucide-react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import { buildMagicLoginUrl } from '@/lib/urlHelper';
import { UserProfile } from '@/types/database';

interface FamilyMembersManagerModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialSelectedUserId?: string | null;
}

const CHILD_EMOJIS = ['🦁', '🦄', '🦊', '🦖', '🦋', '🐼', '🚀', '⚡', '🦉', '🐬'];
const PARENT_EMOJIS = ['👩‍💼', '👨‍💼', '🧑‍✈️', '👑', '🦸‍♀️', '🦸‍♂️', '👩‍🏫', '👨‍🏫'];

export const FamilyMembersManagerModal: React.FC<FamilyMembersManagerModalProps> = ({
  isOpen,
  onClose,
  initialSelectedUserId,
}) => {
  const {
    activeFamily,
    users,
    activeUser,
    addParentToFamily,
    addChildToFamily,
    updateFamilyMember,
    deleteFamilyMember,
    regenerateMemberCredentials,
  } = useFamilyRealtime();

  const [activeTab, setActiveTab] = useState<'all' | 'parents' | 'children' | 'add'>('all');
  const [feedback, setFeedback] = useState<string | null>(null);

  // Düzenleme durumu
  const [editingUserId, setEditingUserId] = useState<string | null>(initialSelectedUserId || null);
  const [editName, setEditName] = useState('');
  const [editGrade, setEditGrade] = useState('');
  const [editEmoji, setEditEmoji] = useState('🦁');
  const [editPassword, setEditPassword] = useState('');
  const [editAgeGroup, setEditAgeGroup] = useState<'kid' | 'preteen' | 'teen'>('kid');

  // Silme onay durumu
  const [deletingUser, setDeletingUser] = useState<UserProfile | null>(null);

  // QR Modal durumu
  const [qrUser, setQrUser] = useState<UserProfile | null>(null);

  // Şifre görünürlüğü haritası (userId -> boolean)
  const [visiblePasswords, setVisiblePasswords] = useState<Record<string, boolean>>({});

  // Yeni Üye Ekleme Form Durumu
  const [newMemberRole, setNewMemberRole] = useState<'parent' | 'child'>('child');
  const [newMemberName, setNewMemberName] = useState('');
  const [newMemberTitle, setNewMemberTitle] = useState('Anne'); // Ebeveyn için
  const [newMemberGrade, setNewMemberGrade] = useState('5. Sınıf'); // Çocuk için
  const [newMemberAgeGroup, setNewMemberAgeGroup] = useState<'kid' | 'preteen' | 'teen'>('kid');
  const [newMemberEmoji, setNewMemberEmoji] = useState('🦁');
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const showToast = (msg: string) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3000);
  };

  const copyToClipboard = (text: string, label: string) => {
    if (typeof navigator !== 'undefined') {
      navigator.clipboard.writeText(text);
      showToast(`📋 ${label} panoya kopyalandı!`);
    }
  };

  const togglePasswordVisibility = (userId: string) => {
    setVisiblePasswords((prev) => ({
      ...prev,
      [userId]: !prev[userId],
    }));
  };

  const startEditing = (user: UserProfile) => {
    setEditingUserId(user.id);
    setEditName(user.name);
    setEditGrade(user.avatar_config?.grade || '');
    setEditEmoji(user.avatar_config?.emoji || (user.role === 'parent' ? '🧑‍✈️' : '🦁'));
    setEditPassword(user.access_password || '');
    setEditAgeGroup((user.avatar_config?.ageGroup as 'kid' | 'preteen' | 'teen') || 'kid');
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUserId || !editName.trim()) return;

    const res = await updateFamilyMember({
      userId: editingUserId,
      name: editName.trim(),
      grade: editGrade.trim(),
      emoji: editEmoji,
      accessPassword: editPassword.trim() || undefined,
      ageGroup: editAgeGroup,
    });

    if (res.success) {
      showToast('✅ Birey bilgileri başarıyla güncellendi!');
      setEditingUserId(null);
    } else {
      showToast(`❌ ${res.message}`);
    }
  };

  const handleConfirmDelete = async () => {
    if (!deletingUser) return;
    const res = await deleteFamilyMember(deletingUser.id);
    if (res.success) {
      showToast(`🗑️ ${deletingUser.name} aileden silindi.`);
      setDeletingUser(null);
      if (editingUserId === deletingUser.id) setEditingUserId(null);
    } else {
      showToast(`❌ ${res.message}`);
    }
  };

  const handleRegenerate = async (userId: string, name: string) => {
    if (!confirm(`${name} için yeni şifre ve sihirli bağlantı oluşturulsun mu?`)) return;
    const res = await regenerateMemberCredentials(userId);
    if (res.success) {
      showToast(`🔑 ${name} için yeni şifre (${res.newPassword}) ve bağlantı oluşturuldu!`);
    } else {
      showToast(`❌ ${res.message}`);
    }
  };

  const handleAddNewMember = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMemberName.trim()) return;
    setIsSubmitting(true);

    try {
      if (newMemberRole === 'parent') {
        const res = await addParentToFamily({
          name: newMemberName.trim(),
          roleTitle: newMemberTitle,
        });
        if (res.success) {
          showToast(`🎉 ${newMemberName} ebeveyn olarak eklendi!`);
          setNewMemberName('');
          setActiveTab('parents');
        } else {
          showToast(`❌ ${res.message}`);
        }
      } else {
        await addChildToFamily({
          name: newMemberName.trim(),
          grade: newMemberGrade,
          ageGroup: newMemberAgeGroup,
          emoji: newMemberEmoji,
        });
        showToast(`🎉 ${newMemberName} öğrenci olarak eklendi!`);
        setNewMemberName('');
        setActiveTab('children');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const parents = users.filter((u) => u.role === 'parent');
  const children = users.filter((u) => u.role === 'child');

  const filteredUsers =
    activeTab === 'parents'
      ? parents
      : activeTab === 'children'
      ? children
      : users;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-slate-950/80 backdrop-blur-md overflow-y-auto">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 15 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 15 }}
        className="w-full max-w-4xl bg-slate-900 border border-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh]"
      >
        {/* MODAL HEADER */}
        <div className="px-5 sm:px-6 py-4 bg-slate-950/90 border-b border-slate-800 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white shadow-lg">
              <Users className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-lg sm:text-xl font-black text-white flex items-center gap-2">
                👨‍👩‍👧‍👦 Aile Bireyleri & Hesap Yönetimi
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                {activeFamily?.name || 'Ailemiz'} • Kod:{' '}
                <span className="font-mono text-indigo-300 font-bold">
                  {activeFamily?.family_code}
                </span>{' '}
                • {users.length} Kayıtlı Birey
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* TOAST FEEDBACK */}
        <AnimatePresence>
          {feedback && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="bg-emerald-600/20 border-b border-emerald-500/30 px-5 py-2 text-xs font-bold text-emerald-300 flex items-center gap-2"
            >
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
              <span>{feedback}</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* TABS */}
        <div className="px-5 sm:px-6 pt-3 pb-2 bg-slate-900/60 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-2 shrink-0">
          <div className="flex items-center gap-1.5 p-1 bg-slate-950 rounded-2xl border border-slate-800">
            <button
              type="button"
              onClick={() => {
                setActiveTab('all');
                setEditingUserId(null);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition ${
                activeTab === 'all'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              👨‍👩‍👧‍👦 Tümü ({users.length})
            </button>
            <button
              type="button"
              onClick={() => {
                setActiveTab('parents');
                setEditingUserId(null);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition ${
                activeTab === 'parents'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              🧑‍✈️ Ebeveynler & Eş ({parents.length})
            </button>
            <button
              type="button"
              onClick={() => {
                setActiveTab('children');
                setEditingUserId(null);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition ${
                activeTab === 'children'
                  ? 'bg-indigo-600 text-white shadow'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              🎒 Öğrenciler ({children.length})
            </button>
          </div>

          <button
            type="button"
            onClick={() => {
              setActiveTab('add');
              setEditingUserId(null);
            }}
            className={`px-3.5 py-2 rounded-xl text-xs font-black flex items-center gap-1.5 transition ${
              activeTab === 'add'
                ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-950/50'
                : 'bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/40'
            }`}
          >
            <UserPlus className="w-4 h-4" />
            <span>+ Yeni Birey (Eş / Çocuk) Ekle</span>
          </button>
        </div>

        {/* MODAL BODY */}
        <div className="p-5 sm:p-6 overflow-y-auto space-y-4 flex-1">
          {/* TAB 1, 2, 3: LIST / EDIT USERS */}
          {activeTab !== 'add' && (
            <div className="space-y-4">
              {filteredUsers.map((member) => {
                const isEditing = editingUserId === member.id;
                const isParent = member.role === 'parent';
                const isCurrentUser = member.id === activeUser.id;
                const isPasswordVisible = !!visiblePasswords[member.id];
                const magicUrl = buildMagicLoginUrl(member.magic_login_token || member.id);

                return (
                  <div
                    key={member.id}
                    className={`rounded-2xl border transition ${
                      isEditing
                        ? 'bg-slate-900 border-indigo-500/80 shadow-2xl p-5'
                        : 'bg-slate-950/70 border-slate-800 hover:border-slate-700/80 p-4 sm:p-5'
                    }`}
                  >
                    {isEditing ? (
                      /* DÜZENLEME FORMU */
                      <form onSubmit={handleSaveEdit} className="space-y-4">
                        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                          <h3 className="text-sm font-black text-white flex items-center gap-2">
                            <Edit3 className="w-4 h-4 text-indigo-400" />
                            <span>{member.name} — Bilgileri Düzenle</span>
                          </h3>
                          <button
                            type="button"
                            onClick={() => setEditingUserId(null)}
                            className="text-xs text-slate-400 hover:text-white"
                          >
                            Vazgeç
                          </button>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                          {/* Ad Soyad */}
                          <div>
                            <label className="block text-xs font-bold text-slate-300 mb-1.5">
                              İsim (Ad / Hitap)
                            </label>
                            <input
                              type="text"
                              value={editName}
                              onChange={(e) => setEditName(e.target.value)}
                              required
                              className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-indigo-500"
                              placeholder="Örn: Ömer Faruk, Anne Fatma"
                            />
                          </div>

                          {/* 6 Haneli Giriş PIN / Şifresi */}
                          <div>
                            <label className="block text-xs font-bold text-slate-300 mb-1.5">
                              6 Haneli Giriş Şifresi (PIN)
                            </label>
                            <div className="flex items-center gap-2">
                              <input
                                type="text"
                                maxLength={6}
                                value={editPassword}
                                onChange={(e) => setEditPassword(e.target.value.replace(/\D/g, ''))}
                                className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-amber-300 font-mono font-black text-sm tracking-widest focus:outline-none focus:border-amber-500"
                                placeholder="123456"
                              />
                              <button
                                type="button"
                                onClick={() =>
                                  setEditPassword(
                                    String(Math.floor(100000 + Math.random() * 900000))
                                  )
                                }
                                className="px-3 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold shrink-0 transition"
                                title="Rastgele 6 haneli üret"
                              >
                                🎲 Üret
                              </button>
                            </div>
                          </div>

                          {/* Çocuk ise: Sınıf / Seviye */}
                          {!isParent && (
                            <div>
                              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                                Sınıf / Eğitim Seviyesi
                              </label>
                              <input
                                type="text"
                                value={editGrade}
                                onChange={(e) => setEditGrade(e.target.value)}
                                className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-indigo-500"
                                placeholder="Örn: 5. Sınıf, Lise 1"
                              />
                            </div>
                          )}

                          {/* Çocuk ise: Yaş Grubu */}
                          {!isParent && (
                            <div>
                              <label className="block text-xs font-bold text-slate-300 mb-1.5">
                                Yaş Modu
                              </label>
                              <div className="flex gap-2">
                                <button
                                  type="button"
                                  onClick={() => setEditAgeGroup('kid')}
                                  className={`flex-1 py-2 rounded-xl text-xs font-bold border transition ${
                                    editAgeGroup === 'kid'
                                      ? 'bg-amber-500/20 text-amber-300 border-amber-400'
                                      : 'bg-slate-950 text-slate-400 border-slate-800'
                                  }`}
                                >
                                  🧸 Çocuk (1-6. Sınıf)
                                </button>
                                <button
                                  type="button"
                                  onClick={() => setEditAgeGroup('teen')}
                                  className={`flex-1 py-2 rounded-xl text-xs font-bold border transition ${
                                    editAgeGroup === 'teen'
                                      ? 'bg-purple-500/20 text-purple-300 border-purple-400'
                                      : 'bg-slate-950 text-slate-400 border-slate-800'
                                  }`}
                                >
                                  ⚡ Genç (7-12. Sınıf)
                                </button>
                              </div>
                            </div>
                          )}

                          {/* Emoji Seçimi */}
                          <div className="sm:col-span-2">
                            <label className="block text-xs font-bold text-slate-300 mb-1.5">
                              Avatar / Emoji Seç
                            </label>
                            <div className="flex flex-wrap gap-2">
                              {(isParent ? PARENT_EMOJIS : CHILD_EMOJIS).map((em) => (
                                <button
                                  key={em}
                                  type="button"
                                  onClick={() => setEditEmoji(em)}
                                  className={`w-10 h-10 rounded-xl text-xl flex items-center justify-center border transition ${
                                    editEmoji === em
                                      ? 'bg-indigo-600 border-indigo-400 scale-110 shadow-lg'
                                      : 'bg-slate-950 border-slate-800 hover:border-slate-700'
                                  }`}
                                >
                                  {em}
                                </button>
                              ))}
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center justify-end gap-2 pt-3 border-t border-slate-800">
                          <button
                            type="button"
                            onClick={() => setEditingUserId(null)}
                            className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold transition"
                          >
                            İptal
                          </button>
                          <button
                            type="submit"
                            className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-black shadow-lg transition"
                          >
                            💾 Değişiklikleri Kaydet
                          </button>
                        </div>
                      </form>
                    ) : (
                      /* STANDART BİREY KARTI */
                      <div className="space-y-4">
                        {/* 1. ÜST KİMLİK SATIRI */}
                        <div className="flex flex-wrap items-center justify-between gap-3">
                          <div className="flex items-center gap-3.5">
                            <div
                              className={`w-12 h-12 rounded-2xl bg-gradient-to-br ${
                                member.avatar_config?.bg || (isParent ? 'from-blue-600 to-indigo-700' : 'from-amber-400 to-orange-500')
                              } flex items-center justify-center text-2xl shadow-md`}
                            >
                              {member.avatar_config?.emoji || (isParent ? '🧑‍✈️' : '🦁')}
                            </div>

                            <div>
                              <div className="flex items-center gap-2 flex-wrap">
                                <h3 className="text-base sm:text-lg font-black text-white">
                                  {member.name}
                                </h3>
                                {isCurrentUser && (
                                  <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                                    BEN (Aktif Hesap)
                                  </span>
                                )}
                                <span
                                  className={`px-2.5 py-0.5 rounded-full text-xs font-bold ${
                                    isParent
                                      ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30'
                                      : 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                                  }`}
                                >
                                  {isParent
                                    ? `🧑‍✈️ Ebeveyn (${member.avatar_config?.roleTitle || 'Yönetici'})`
                                    : `🎒 Öğrenci (${member.avatar_config?.grade || 'Öğrenci'})`}
                                </span>
                              </div>

                              <div className="flex items-center gap-2 mt-1 text-xs text-slate-400">
                                <span>Kullanıcı Adı:</span>
                                <code className="px-2 py-0.5 rounded bg-slate-900 border border-slate-800 text-indigo-300 font-mono font-bold">
                                  {member.username || 'tanımsız'}
                                </code>
                                <button
                                  type="button"
                                  onClick={() => copyToClipboard(member.username || '', 'Kullanıcı adı')}
                                  className="text-slate-500 hover:text-slate-300"
                                  title="Kopyala"
                                >
                                  <Copy className="w-3.5 h-3.5" />
                                </button>
                              </div>
                            </div>
                          </div>

                          {/* İŞLEM BUTONLARI (DÜZENLE, YENİLE, SİL) */}
                          <div className="flex items-center gap-1.5">
                            <button
                              type="button"
                              onClick={() => startEditing(member)}
                              className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition"
                              title="Adı, Sınıfı veya Şifreyi Düzenle"
                            >
                              <Edit3 className="w-3.5 h-3.5 text-indigo-400" />
                              <span>Düzenle</span>
                            </button>

                            <button
                              type="button"
                              onClick={() => handleRegenerate(member.id, member.name)}
                              className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                              title="Yeni Şifre & Bağlantı Üret"
                            >
                              <RefreshCw className="w-3.5 h-3.5 text-amber-400" />
                            </button>

                            {!isCurrentUser && (
                              <button
                                type="button"
                                onClick={() => setDeletingUser(member)}
                                className="p-2 rounded-xl bg-rose-500/10 hover:bg-rose-500/25 border border-rose-500/30 text-rose-300 transition"
                                title="Aileden Sil"
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            )}
                          </div>
                        </div>

                        {/* 2. GİRİŞ VE GÜVENLİK BİLGİLERİ KUTUSU */}
                        <div className="p-3.5 rounded-2xl bg-slate-900/90 border border-slate-800 grid grid-cols-1 md:grid-cols-3 gap-3">
                          {/* 6 Haneli Şifre */}
                          <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between">
                            <div>
                              <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                                <KeyRound className="w-3 h-3 text-amber-400" />
                                <span>6 Haneli Şifre / PIN</span>
                              </div>
                              <div className="font-mono font-black text-amber-300 text-sm tracking-widest mt-0.5">
                                {isPasswordVisible
                                  ? member.access_password || '123456'
                                  : '••••••'}
                              </div>
                            </div>
                            <div className="flex items-center gap-1">
                              <button
                                type="button"
                                onClick={() => togglePasswordVisibility(member.id)}
                                className="p-1.5 rounded-lg text-slate-400 hover:text-white"
                                title={isPasswordVisible ? 'Gizle' : 'Göster'}
                              >
                                {isPasswordVisible ? (
                                  <EyeOff className="w-4 h-4" />
                                ) : (
                                  <Eye className="w-4 h-4" />
                                )}
                              </button>
                              <button
                                type="button"
                                onClick={() =>
                                  copyToClipboard(member.access_password || '123456', `${member.name} şifresi`)
                                }
                                className="p-1.5 rounded-lg text-slate-400 hover:text-white"
                                title="Şifreyi Kopyala"
                              >
                                <Copy className="w-4 h-4" />
                              </button>
                            </div>
                          </div>

                          {/* Tek Tıkla Sihirli Giriş Linki */}
                          <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between">
                            <div className="truncate mr-2">
                              <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                                <Share2 className="w-3 h-3 text-indigo-400" />
                                <span>Tek Tıkla Giriş Linki</span>
                              </div>
                              <div className="text-[11px] font-mono text-slate-400 truncate mt-0.5">
                                {magicUrl}
                              </div>
                            </div>
                            <button
                              type="button"
                              onClick={() => copyToClipboard(magicUrl, `${member.name} sihirli giriş linki`)}
                              className="px-2.5 py-1.5 rounded-lg bg-indigo-600/30 hover:bg-indigo-600 text-indigo-200 hover:text-white text-xs font-bold shrink-0 transition flex items-center gap-1"
                            >
                              <Copy className="w-3.5 h-3.5" />
                              <span>Kopyala</span>
                            </button>
                          </div>

                          {/* Giriş QR Kodu ve Ajan Kodu */}
                          <div className="p-2.5 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between">
                            <div>
                              <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                                <QrCode className="w-3 h-3 text-emerald-400" />
                                <span>{isParent ? 'Telefondan Hızlı Giriş' : 'PC & Mobil Bağlantı'}</span>
                              </div>
                              <div className="text-xs text-slate-300 font-bold mt-0.5">
                                {!isParent && member.desktop_pairing_code ? (
                                  <span className="font-mono text-emerald-400">
                                    Kod: {member.desktop_pairing_code}
                                  </span>
                                ) : (
                                  <span className="text-slate-400">QR Kod ile Giriş</span>
                                )}
                              </div>
                            </div>

                            <button
                              type="button"
                              onClick={() => setQrUser(member)}
                              className="px-2.5 py-1.5 rounded-lg bg-emerald-600/30 hover:bg-emerald-600 text-emerald-200 hover:text-white text-xs font-bold shrink-0 transition flex items-center gap-1"
                            >
                              <QrCode className="w-3.5 h-3.5" />
                              <span>QR Göster</span>
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* TAB 4: ADD NEW MEMBER FORM */}
          {activeTab === 'add' && (
            <form onSubmit={handleAddNewMember} className="max-w-xl mx-auto space-y-5 p-6 bg-slate-950 rounded-3xl border border-slate-800">
              <div className="text-center space-y-1">
                <h3 className="text-lg font-black text-white flex items-center justify-center gap-2">
                  <UserPlus className="w-5 h-5 text-emerald-400" />
                  <span>Aileye Yeni Birey Kaydet</span>
                </h3>
                <p className="text-xs text-slate-400">
                  Eşinizi ikinci ebeveyn olarak veya yeni bir öğrenciyi anında sisteme ekleyin.
                </p>
              </div>

              {/* ROL SEÇİMİ */}
              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => {
                    setNewMemberRole('parent');
                    setNewMemberEmoji('👩‍💼');
                  }}
                  className={`p-3.5 rounded-2xl border text-center transition flex flex-col items-center gap-1.5 ${
                    newMemberRole === 'parent'
                      ? 'bg-purple-600/25 border-purple-500 text-white shadow-lg'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  <span className="text-2xl">🧑‍✈️</span>
                  <span className="font-black text-xs">Eş / İkinci Ebeveyn</span>
                  <span className="text-[10px] text-purple-300 font-medium">Anne, Baba veya Veli</span>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setNewMemberRole('child');
                    setNewMemberEmoji('🦁');
                  }}
                  className={`p-3.5 rounded-2xl border text-center transition flex flex-col items-center gap-1.5 ${
                    newMemberRole === 'child'
                      ? 'bg-amber-600/25 border-amber-500 text-white shadow-lg'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  <span className="text-2xl">🎒</span>
                  <span className="font-black text-xs">Yeni Öğrenci / Çocuk</span>
                  <span className="text-[10px] text-amber-300 font-medium">Görevler, kalkanlar & market</span>
                </button>
              </div>

              {/* AD SOYAD */}
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1.5">
                  {newMemberRole === 'parent' ? 'Eşinizin / Ebeveynin Adı' : 'Öğrencinin Adı'}
                </label>
                <input
                  type="text"
                  value={newMemberName}
                  onChange={(e) => setNewMemberName(e.target.value)}
                  required
                  placeholder={newMemberRole === 'parent' ? 'Örn: Fatma, Ahmet' : 'Örn: Zeynep, Mehmet'}
                  className="w-full px-4 py-3 rounded-2xl bg-slate-900 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-indigo-500"
                />
              </div>

              {/* EBEVEYN ÖZEL AYARLARI */}
              {newMemberRole === 'parent' ? (
                <div>
                  <label className="block text-xs font-bold text-slate-300 mb-1.5">
                    Rol Tanımı
                  </label>
                  <div className="flex gap-2">
                    {['Anne', 'Baba', 'Veli'].map((t) => (
                      <button
                        key={t}
                        type="button"
                        onClick={() => {
                          setNewMemberTitle(t);
                          if (t === 'Anne') setNewMemberEmoji('👩‍💼');
                          if (t === 'Baba') setNewMemberEmoji('👨‍💼');
                        }}
                        className={`flex-1 py-2 rounded-xl text-xs font-bold border transition ${
                          newMemberTitle === t
                            ? 'bg-purple-600 text-white border-purple-400'
                            : 'bg-slate-900 text-slate-400 border-slate-800'
                        }`}
                      >
                        {t}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                /* ÇOCUK ÖZEL AYARLARI */
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1.5">
                      Sınıf / Seviye
                    </label>
                    <input
                      type="text"
                      value={newMemberGrade}
                      onChange={(e) => setNewMemberGrade(e.target.value)}
                      placeholder="Örn: 5. Sınıf"
                      className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-white font-bold text-xs focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-300 mb-1.5">
                      Yaş Modu
                    </label>
                    <div className="flex gap-1.5">
                      <button
                        type="button"
                        onClick={() => setNewMemberAgeGroup('kid')}
                        className={`flex-1 py-2 rounded-xl text-[11px] font-bold border transition ${
                          newMemberAgeGroup === 'kid'
                            ? 'bg-amber-500/20 text-amber-300 border-amber-400'
                            : 'bg-slate-900 text-slate-400 border-slate-800'
                        }`}
                      >
                        🧸 Çocuk
                      </button>
                      <button
                        type="button"
                        onClick={() => setNewMemberAgeGroup('teen')}
                        className={`flex-1 py-2 rounded-xl text-[11px] font-bold border transition ${
                          newMemberAgeGroup === 'teen'
                            ? 'bg-purple-500/20 text-purple-300 border-purple-400'
                            : 'bg-slate-900 text-slate-400 border-slate-800'
                        }`}
                      >
                        ⚡ Genç
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* EMOJİ SEÇİMİ */}
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1.5">
                  Avatar Emoji
                </label>
                <div className="flex flex-wrap gap-2">
                  {(newMemberRole === 'parent' ? PARENT_EMOJIS : CHILD_EMOJIS).map((em) => (
                    <button
                      key={em}
                      type="button"
                      onClick={() => setNewMemberEmoji(em)}
                      className={`w-10 h-10 rounded-xl text-xl flex items-center justify-center border transition ${
                        newMemberEmoji === em
                          ? 'bg-indigo-600 border-indigo-400 scale-110 shadow-lg'
                          : 'bg-slate-900 border-slate-800 hover:border-slate-700'
                      }`}
                    >
                      {em}
                    </button>
                  ))}
                </div>
              </div>

              <div className="pt-2">
                <button
                  type="submit"
                  disabled={isSubmitting || !newMemberName.trim()}
                  className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-black text-sm flex items-center justify-center gap-2 shadow-lg shadow-emerald-950/50 transition disabled:opacity-50"
                >
                  <CheckCircle2 className="w-5 h-5" />
                  <span>
                    {isSubmitting
                      ? 'Kaydediliyor...'
                      : newMemberRole === 'parent'
                      ? 'Eşi / Ebeveyni Kaydet ve Şifre Üret'
                      : 'Öğrenciyi Kaydet ve Şifre Üret'}
                  </span>
                </button>
              </div>
            </form>
          )}
        </div>

        {/* MODAL FOOTER */}
        <div className="px-5 sm:px-6 py-3.5 bg-slate-950/90 border-t border-slate-800 flex items-center justify-between text-xs text-slate-400 shrink-0">
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-emerald-400" />
            <span>Tüm şifreler ve linkler ailenize özel güvenle şifrelenir.</span>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold transition"
          >
            Kapat
          </button>
        </div>
      </motion.div>

      {/* SİLME ONAY MODALI */}
      <AnimatePresence>
        {deletingUser && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="w-full max-w-md bg-slate-900 border border-rose-500/40 rounded-3xl p-6 text-center space-y-4 shadow-2xl"
            >
              <div className="w-14 h-14 rounded-full bg-rose-500/20 text-rose-400 flex items-center justify-center mx-auto text-2xl">
                <AlertTriangle className="w-7 h-7" />
              </div>
              <div>
                <h3 className="text-lg font-black text-white">
                  {deletingUser.name} Aileden Silinecek!
                </h3>
                <p className="text-xs text-slate-300 mt-2">
                  Bu işlem geri alınamaz. {deletingUser.role === 'child' ? 'Öğrencinin tüm görevleri, puanları ve cihaz kayıtları' : 'Ebeveyn hesabı'} silinecektir.
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setDeletingUser(null)}
                  className="flex-1 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold text-xs transition"
                >
                  Vazgeç
                </button>
                <button
                  type="button"
                  onClick={handleConfirmDelete}
                  className="flex-1 py-3 rounded-xl bg-rose-600 hover:bg-rose-500 text-white font-black text-xs shadow-lg transition"
                >
                  Evet, Kesinlikle Sil
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* BÜYÜK QR KOD GÖRÜNTÜLEME MODALI */}
      <AnimatePresence>
        {qrUser && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="w-full max-w-sm bg-slate-900 border border-slate-800 rounded-3xl p-6 text-center space-y-4 shadow-2xl"
            >
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-black text-white flex items-center gap-2">
                  <span>{qrUser.avatar_config?.emoji || '👤'}</span>
                  <span>{qrUser.name} — Giriş QR Kodu</span>
                </h3>
                <button
                  type="button"
                  onClick={() => setQrUser(null)}
                  className="p-1 rounded-lg text-slate-400 hover:text-white"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="w-56 h-56 mx-auto bg-white p-3 rounded-2xl flex items-center justify-center shadow-lg">
                <img
                  src={`https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(
                    buildMagicLoginUrl(qrUser.magic_login_token || qrUser.id)
                  )}`}
                  alt="QR Kodu"
                  className="w-full h-full object-contain"
                />
              </div>

              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-300 space-y-1">
                <p>
                  <span className="text-slate-500">Kullanıcı:</span>{' '}
                  <span className="font-mono font-bold text-indigo-300">{qrUser.username}</span>
                </p>
                <p>
                  <span className="text-slate-500">Şifre:</span>{' '}
                  <span className="font-mono font-bold text-amber-300 tracking-widest">{qrUser.access_password}</span>
                </p>
                <p className="text-[10px] text-slate-500 pt-1">
                  Kameranızla bu karekodu okutarak doğrudan bu hesapla giriş yapabilirsiniz.
                </p>
              </div>

              <button
                type="button"
                onClick={() => {
                  copyToClipboard(
                    buildMagicLoginUrl(qrUser.magic_login_token || qrUser.id),
                    `${qrUser.name} giriş linki`
                  );
                }}
                className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center justify-center gap-2 transition"
              >
                <Copy className="w-4 h-4" />
                <span>Giriş Linkini Kopyala</span>
              </button>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};
