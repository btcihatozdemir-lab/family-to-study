'use client';

import { useCallback } from 'react';

/**
 * ÇAKIŞMA ÖNLEYİCİ KURAL:
 * Eğer PWA şu an Windows Masaüstü Ajanı (`FamilyOS-Windows-Agent`) içinde
 * çalışıyorsa, tarayıcı içi Web TTS ve Web Audio Desibel Ölçer devre dışı
 * bırakılır (Windows Ajanı bunları yerel SAPI + Audio Ducking ve donanımsal
 * mikrofon thread'i ile zaten yürütmektedir).
 */
export function isRunningInsideWindowsAgent(): boolean {
  if (typeof navigator === 'undefined') return false;
  return navigator.userAgent.includes('FamilyOS-Windows-Agent');
}

/**
 * Merkezi Türkçe Sesli Ev Asistanı (Web Speech API - window.speechSynthesis tr-TR)
 */
export function speakTurkishAnnouncement(
  text: string,
  enabled: boolean = true
): void {
  if (
    !enabled ||
    typeof window === 'undefined' ||
    !('speechSynthesis' in window) ||
    isRunningInsideWindowsAgent()
  ) {
    return;
  }

  try {
    const synth = window.speechSynthesis;
    synth.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'tr-TR';
    utterance.rate = 1.02;
    utterance.pitch = 1.05;
    utterance.volume = 1.0;

    const voices = synth.getVoices();
    const trVoice =
      voices.find(
        (v) =>
          v.lang.toLowerCase().includes('tr') &&
          (v.name.toLowerCase().includes('yelda') ||
            v.name.toLowerCase().includes('emel') ||
            v.name.toLowerCase().includes('google') ||
            v.name.toLowerCase().includes('turkish'))
      ) || voices.find((v) => v.lang.toLowerCase().includes('tr'));

    if (trVoice) {
      utterance.voice = trVoice;
    }

    synth.speak(utterance);
  } catch (err) {
    console.warn('[TTSAnnouncer] Sesli anons hatası:', err);
  }
}

export function useTTSAnnouncer(enabled: boolean = true) {
  const isWindowsAgent = isRunningInsideWindowsAgent();

  const announceCustom = useCallback(
    (text: string) => {
      speakTurkishAnnouncement(text, enabled);
    },
    [enabled]
  );

  const announceStudyStart = useCallback(
    (studentName: string, minutes: number = 40) => {
      speakTurkishAnnouncement(
        `Dikkat dikkat! ${studentName} için ${minutes} dakikalık odaklanma uçuşu başlıyor, başarılar kaptan!`,
        enabled
      );
    },
    [enabled]
  );

  const announceTaskApproved = useCallback(
    (studentName: string, points: number) => {
      speakTurkishAnnouncement(
        `Harika haber ${studentName}! Görevin onaylandı ve hesabına ${points} puan yüklendi!`,
        enabled
      );
    },
    [enabled]
  );

  const announceHappyHourStarted = useCallback(
    (discountPercent: number) => {
      speakTurkishAnnouncement(
        `Ev halkı dikkat! Markette yüzde ${discountPercent} sürpriz indirim saati başladı!`,
        enabled
      );
    },
    [enabled]
  );

  const announceRaceQuestDropped = useCallback(
    (taskTitle: string, points: number) => {
      speakTurkishAnnouncement(
        `Ev halkı dikkat! İlk kapar yarış görevi düştü: ${taskTitle}! İlk basan ${points} altın puanı kapar!`,
        enabled
      );
    },
    [enabled]
  );

  return {
    isWindowsAgent,
    announceCustom,
    announceStudyStart,
    announceTaskApproved,
    announceHappyHourStarted,
    announceRaceQuestDropped,
  };
}
