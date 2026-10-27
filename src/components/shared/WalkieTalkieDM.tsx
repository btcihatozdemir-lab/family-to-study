'use client';

import React, { useState, useRef } from 'react';
import { useFamilyRealtime } from '@/context/FamilyRealtimeContext';
import {
  Mic,
  Send,
  Radio,
  Volume2,
  Sparkles,
  CheckCheck,
  Square,
} from 'lucide-react';
import { soundEngine } from '@/lib/soundEngine';
import { useDesktopBridge } from '@/lib/useDesktopBridge';

interface WalkieTalkieDMProps {
  currentUserId: string;
  targetUserId?: string; // If omitted, allows choosing family member
  compact?: boolean;
}

const STUDENT_QUICK_REQUESTS = [
  '💧 Su / Meyve alabilir miyim?',
  '🙋‍♂️ Bir soruda takıldım, bakar mısınız?',
  '🚻 3 dk tuvalet molası lazım',
  '📸 Testimi bitirdim, onaylar mısınız?',
];

const PARENT_QUICK_REPLIES = [
  '🌟 Harika gidiyorsun, seninle gurur duyuyoruz!',
  '⏳ Az kaldı, odaklanmaya devam!',
  '🍉 Meyve tabağın geliyor!',
  '👍 Fotoğrafını gördüm, hemen onaylıyorum!',
];

export const WalkieTalkieDM: React.FC<WalkieTalkieDMProps> = ({
  currentUserId,
  targetUserId,
  compact = false,
}) => {
  const { users, messages, sendDirectMessage } = useFamilyRealtime();
  const currentUser = users.find((u) => u.id === currentUserId);
  const otherFamilyMembers = users.filter((u) => u.id !== currentUserId);

  const [selectedReceiverId, setSelectedReceiverId] = useState<string>(
    targetUserId ||
      (currentUser?.role === 'child' ? 'parent-mom' : 'child-omer')
  );
  const [textInput, setTextInput] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);

  useDesktopBridge(isRecording || Boolean(textInput.trim()));

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const activeReceiverId = targetUserId || selectedReceiverId;
  const receiverUser = users.find((u) => u.id === activeReceiverId);

  // Çocuğun perspektifinden gerçek akrabalık hitabını çözer
  const getKinshipLabel = (m?: UserProfile | null) => {
    if (!m) return 'Aile Bireyi';
    if (m.id === currentUserId) return 'Ben';
    if (currentUser?.role === 'child') {
      const title = (m.avatar_config?.roleTitle || '').toLowerCase();
      const nameLower = m.name.toLowerCase();
      if (m.role === 'parent') {
        if (title.includes('anne') || nameLower.includes('anne') || nameLower.includes('eşim') || nameLower.includes('merve')) return 'Annem';
        if (title.includes('baba') || nameLower.includes('baba') || nameLower.includes('ben') || nameLower.includes('cihat')) return 'Babam';
        if (title.includes('hala')) return 'Halam';
        if (title.includes('dayı')) return 'Dayım';
        if (title.includes('teyze')) return 'Teyzem';
        if (title.includes('amca')) return 'Amcam';
        if (title.includes('dede')) return 'Dedem';
        if (title.includes('anneanne')) return 'Anneannem';
        if (title.includes('babaanne')) return 'Babaannem';
        if (title.includes('abla')) return 'Ablam';
        if (title.includes('abi')) return 'Abim';
      }
    }
    return m.name.split(' ')[0];
  };

  // Filter conversation between current user and receiver (or family-wide between parents and child)
  const conversationMessages = messages.filter(
    (m) =>
      (m.sender_id === currentUserId && m.receiver_id === activeReceiverId) ||
      (m.sender_id === activeReceiverId && m.receiver_id === currentUserId) ||
      (currentUser?.role === 'child' &&
        (m.receiver_id === currentUserId || m.sender_id === currentUserId))
  );

  const handleSendText = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!textInput.trim()) return;
    await sendDirectMessage(currentUserId, activeReceiverId, 'text', textInput.trim());
    setTextInput('');
  };

  const handleQuickMessage = async (msg: string) => {
    await sendDirectMessage(currentUserId, activeReceiverId, 'quick_request', msg);
  };

  const startVoiceRecording = async () => {
    soundEngine.playWalkieTalkieBeep();
    setIsRecording(true);
    setRecordingSeconds(0);
    audioChunksRef.current = [];

    timerRef.current = setInterval(() => {
      setRecordingSeconds((s) => s + 1);
    }, 1000);

    if (typeof navigator !== 'undefined' && navigator.mediaDevices?.getUserMedia) {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const recorder = new MediaRecorder(stream);
        recorder.ondataavailable = (ev) => {
          if (ev.data.size > 0) audioChunksRef.current.push(ev.data);
        };
        recorder.onstop = () => {
          const blob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
          const reader = new FileReader();
          reader.onloadend = () => {
            const base64Audio = reader.result as string;
            sendDirectMessage(
              currentUserId,
              activeReceiverId,
              'audio',
              `🎙️ Sesli Telsiz Mesajı (${recordingSeconds || 2} sn)`,
              base64Audio
            );
          };
          reader.readAsDataURL(blob);
          stream.getTracks().forEach((t) => t.stop());
        };
        mediaRecorderRef.current = recorder;
        recorder.start();
        return;
      } catch {
        // Fallback simulated voice note if microphone permission is denied in browser
      }
    }
  };

  const stopVoiceRecording = async () => {
    if (timerRef.current) clearInterval(timerRef.current);
    setIsRecording(false);
    soundEngine.playWalkieTalkieBeep();

    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    } else {
      // Simulated Walkie-Talkie transmission when mic is unavailable
      await sendDirectMessage(
        currentUserId,
        activeReceiverId,
        'audio',
        `🎙️ Telsiz Anonsu (${Math.max(1, recordingSeconds)} sn): "Tamam, mesaj alındı! 📻"`,
        null
      );
    }
  };

  const quickTemplates =
    currentUser?.role === 'child' ? STUDENT_QUICK_REQUESTS : PARENT_QUICK_REPLIES;

  return (
    <div
      data-allow-touch="true"
      className="bg-slate-900/90 border border-indigo-500/30 rounded-2xl p-4 shadow-xl backdrop-blur-md text-white"
    >
      {/* Header & Family Receiver Selector */}
      <div className="flex flex-wrap items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-800">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-indigo-500/20 text-indigo-400">
            <Radio className="w-5 h-5 animate-pulse" />
          </div>
          <div>
            <h3 className="font-bold text-sm sm:text-base flex items-center gap-1.5">
              Aile Telsizi & Canlı DM
              <span className="text-[11px] bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full font-medium">
                Canlı Kanal
              </span>
            </h3>
            <p className="text-xs text-slate-400">
              Odaklanma kalkanını bozmadan güvenli iletişim
            </p>
          </div>
        </div>

        {!targetUserId && (
          <div className="flex items-center gap-1.5 bg-slate-800/90 p-1 rounded-xl">
            {otherFamilyMembers.map((member) => (
              <button
                key={member.id}
                type="button"
                onClick={() => setSelectedReceiverId(member.id)}
                className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition flex items-center gap-1 ${
                  activeReceiverId === member.id
                    ? 'bg-indigo-600 text-white shadow'
                    : 'text-slate-300 hover:bg-slate-700'
                }`}
              >
                <span>{member.avatar_config.emoji}</span>
                <span>{getKinshipLabel(member)}</span>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Messages Feed */}
      <div
        className={`space-y-2.5 overflow-y-auto pr-1 mb-3 ${
          compact ? 'max-h-44' : 'max-h-64'
        }`}
      >
        {conversationMessages.length === 0 ? (
          <div className="text-center py-6 text-slate-400 text-xs">
            Henüz mesaj yok. Aşağıdan hızlı mesaj veya Bas-Konuş telsiz gönderebilirsin!
          </div>
        ) : (
          conversationMessages.slice(-12).map((msg) => {
            const isMine = msg.sender_id === currentUserId;
            const sender = users.find((u) => u.id === msg.sender_id);
            return (
              <div
                key={msg.id}
                className={`flex flex-col ${isMine ? 'items-end' : 'items-start'}`}
              >
                <div
                  className={`max-w-[85%] rounded-2xl px-3.5 py-2 text-xs sm:text-sm ${
                    isMine
                      ? 'bg-gradient-to-r from-indigo-600 to-violet-600 text-white rounded-br-none'
                      : 'bg-slate-800 text-slate-100 border border-slate-700 rounded-bl-none'
                  }`}
                >
                  <div className="flex items-center gap-1.5 text-[10px] opacity-75 mb-0.5 font-semibold">
                    <span>{sender?.avatar_config.emoji}</span>
                    <span>{isMine ? 'Ben' : getKinshipLabel(sender)}</span>
                    <span>•</span>
                    <span>
                      {new Date(msg.created_at).toLocaleTimeString('tr-TR', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </span>
                  </div>

                  <p className="leading-snug">{msg.content}</p>

                  {msg.audio_url && (
                    <audio
                      controls
                      src={msg.audio_url}
                      className="mt-2 h-8 w-48 max-w-full"
                    />
                  )}
                  {msg.message_type === 'audio' && !msg.audio_url && (
                    <button
                      type="button"
                      onClick={() => soundEngine.playWalkieTalkieBeep()}
                      className="mt-1.5 inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/15 hover:bg-white/25 text-xs font-medium transition"
                    >
                      <Volume2 className="w-3.5 h-3.5" />
                      Telsiz Sinyalini Dinle
                    </button>
                  )}
                </div>
                {isMine && (
                  <span className="text-[10px] text-indigo-300 mt-0.5 flex items-center gap-0.5">
                    <CheckCheck className="w-3 h-3" /> İletildi
                  </span>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Quick Request Chips */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-2 mb-2.5 no-scrollbar">
        <Sparkles className="w-3.5 h-3.5 text-amber-400 shrink-0" />
        {quickTemplates.map((tpl, idx) => (
          <button
            key={idx}
            type="button"
            onClick={() => handleQuickMessage(tpl)}
            className="shrink-0 text-[11px] bg-slate-800/90 hover:bg-indigo-600/40 border border-slate-700 hover:border-indigo-400/50 text-slate-200 px-2.5 py-1 rounded-full transition"
          >
            {tpl}
          </button>
        ))}
      </div>

      {/* Input & Push-To-Talk Walkie-Talkie Controls */}
      <form onSubmit={handleSendText} className="flex items-center gap-2">
        <input
          type="text"
          value={textInput}
          onChange={(e) => setTextInput(e.target.value)}
          placeholder={`${receiverUser?.name.split(' ')[0] || 'Aileye'} mesaj yaz...`}
          className="flex-1 bg-slate-800/90 border border-slate-700 focus:border-indigo-500 rounded-xl px-3.5 py-2 text-xs sm:text-sm text-white placeholder-slate-400 focus:outline-none"
        />

        {!isRecording ? (
          <button
            type="button"
            onClick={startVoiceRecording}
            title="Bas-Konuş Sesli Telsiz Gönder"
            className="px-3 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs flex items-center gap-1.5 shadow-lg shadow-amber-500/20 transition shrink-0"
          >
            <Mic className="w-4 h-4" />
            <span className="hidden sm:inline">Bas-Konuş</span>
          </button>
        ) : (
          <button
            type="button"
            onClick={stopVoiceRecording}
            className="px-3 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white font-bold text-xs flex items-center gap-1.5 animate-pulse shadow-lg shadow-rose-600/30 transition shrink-0"
          >
            <Square className="w-4 h-4 fill-current" />
            <span>Gönder ({recordingSeconds}sn)</span>
          </button>
        )}

        <button
          type="submit"
          className="p-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition shrink-0"
        >
          <Send className="w-4 h-4" />
        </button>
      </form>
    </div>
  );
};
