'use client';

class SoundEngine {
  private ctx: AudioContext | null = null;
  private alarmInterval: ReturnType<typeof setInterval> | null = null;
  private brushInterval: ReturnType<typeof setInterval> | null = null;
  private alarmGainLevel = 0.15;

  private getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  private playTone(
    freq: number,
    duration: number,
    delay = 0,
    type: OscillatorType = 'sine',
    volume = 0.2
  ) {
    const ctx = this.getContext();
    if (!ctx) return;

    const startTime = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, startTime);

    gain.gain.setValueAtTime(0.001, startTime);
    gain.gain.exponentialRampToValueAtTime(volume, startTime + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(startTime);
    osc.stop(startTime + duration + 0.02);
  }

  // 1. Görev Onayı & Zafer Sesi (Victory Fanfare)
  public playVictoryFanfare() {
    const notes = [523.25, 659.25, 783.99, 1046.5]; // C5, E5, G5, C6
    notes.forEach((freq, idx) => {
      this.playTone(freq, idx === notes.length - 1 ? 0.55 : 0.18, idx * 0.12, 'triangle', 0.28);
    });
  }

  // 2. Eğlenceli Mola Başlangıç Zili (Recess Bell Melody)
  public playBreakStartBell() {
    const melody = [
      { f: 659.25, d: 0.18, t: 0 },
      { f: 587.33, d: 0.18, t: 0.18 },
      { f: 523.25, d: 0.18, t: 0.36 },
      { f: 659.25, d: 0.25, t: 0.54 },
      { f: 783.99, d: 0.45, t: 0.80 },
    ];
    melody.forEach((n) => this.playTone(n.f, n.d, n.t, 'sine', 0.3));
  }

  // 3. Mola Bitişi / Derse Dönüş Sesi (Focus Mode Chime)
  public playStudyStartChime() {
    const chords = [440, 554.37, 659.25, 880]; // A Major warm focus chord
    chords.forEach((f, i) => {
      this.playTone(f, 0.7, i * 0.08, 'sine', 0.2);
    });
  }

  // 4. Sürpriz Altın Görev (Flash Quest) Bildirim Sesi
  public playFlashQuestAlert() {
    const seq = [587.33, 880, 1174.66, 880, 1174.66];
    seq.forEach((f, i) => {
      this.playTone(f, 0.14, i * 0.1, 'square', 0.18);
    });
  }

  // 5. Kalkan Kırılma / İhlal Uyarı Sesi (Shield Broken Siren)
  public playViolationSiren() {
    this.playTone(320, 0.22, 0, 'sawtooth', 0.25);
    this.playTone(220, 0.35, 0.22, 'sawtooth', 0.28);
    this.playTone(320, 0.22, 0.58, 'sawtooth', 0.25);
    this.playTone(196, 0.40, 0.80, 'sawtooth', 0.30);
  }

  // 6. Telsiz / DM Bip Sesi (Walkie-Talkie Roger Beep)
  public playWalkieTalkieBeep() {
    this.playTone(1200, 0.08, 0, 'sine', 0.2);
    this.playTone(1600, 0.1, 0.09, 'sine', 0.2);
  }

  // 7. Giderek Yükselen (Crescendo) Enerjik Uyandırma Alarmı
  public startWakeUpAlarmLoop() {
    if (this.alarmInterval) return;
    this.alarmGainLevel = 0.12;

    const triggerPattern = () => {
      // Energetic morning arpeggio that progressively increases in volume
      this.alarmGainLevel = Math.min(0.55, this.alarmGainLevel + 0.05);
      const pattern = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5];
      pattern.forEach((freq, idx) => {
        this.playTone(freq, 0.16, idx * 0.14, 'triangle', this.alarmGainLevel);
      });
    };

    triggerPattern();
    this.alarmInterval = setInterval(triggerPattern, 1400);
  }

  public stopWakeUpAlarmLoop() {
    if (this.alarmInterval) {
      clearInterval(this.alarmInterval);
      this.alarmInterval = null;
    }
  }

  // 8. 2 Dakikalık Diş Fırçalama Sayacı İçin Eğlenceli Ritim
  public startToothbrushMusic() {
    if (this.brushInterval) return;
    let step = 0;
    const notes = [523.25, 587.33, 659.25, 783.99, 659.25, 587.33];
    this.brushInterval = setInterval(() => {
      const freq = notes[step % notes.length];
      this.playTone(freq, 0.18, 0, 'sine', 0.14);
      step++;
    }, 350);
  }

  public stopToothbrushMusic() {
    if (this.brushInterval) {
      clearInterval(this.brushInterval);
      this.brushInterval = null;
    }
  }
}

export const soundEngine = new SoundEngine();
