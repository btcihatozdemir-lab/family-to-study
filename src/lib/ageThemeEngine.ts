import { UserProfile } from '@/types/database';

export interface AgeAdaptivePersona {
  tier: 'junior' | 'senior'; // junior: 6-10 yaş (1-4. Sınıf), senior: 11-15 yaş (5-8. Sınıf & Lise)
  badgeTitle: string;
  welcomeSubtitle: string;
  pointsLabel: string;
  pointsSubtext: string;
  piggyLabel: string;
  piggyTitle: string;
  piggyDesc: string;
  shieldLabel: string;
  shieldSubtext: string;
  questsTabTitle: string;
  marketTabTitle: string;
  piggyWheelTabTitle: string;
  comboBannerTitle: string;
  comboBannerDesc: string;
  photoProofBadge: string;
  photoButtonText: string;
  completeButtonText: string;
  // Focus Lock Screen
  lockBadge: string;
  lockHeadline: string;
  lockSubtext: string;
  lockMascotEmojis: string;
  lockSensorWarning: string;
  // Wake-up Alarm Screen
  wakeHeaderBadge: string;
  wakeCatchInstruction: string;
  wakeTargetEmoji: string;
  riddles: {
    question: string;
    options: string[];
    correctIndex: number;
  }[];
  // Visual Styling
  heroGradient: string;
  cardBorderRadius: string;
  titleFontSize: string;
  actionButtonGradient: string;
}

export function getAgeAdaptivePersona(student: UserProfile): AgeAdaptivePersona {
  const ageGroup = student.avatar_config?.ageGroup || 'kid';
  const gradeText = (student.avatar_config?.grade || '').toLowerCase();

  // Determine if student is Junior (1-4. Sınıf / 6-10 yaş) or Senior (5-8. Sınıf & Lise / 11+ yaş)
  const isSenior =
    ageGroup === 'preteen' ||
    ageGroup === 'teen' ||
    gradeText.includes('5.') ||
    gradeText.includes('6.') ||
    gradeText.includes('7.') ||
    gradeText.includes('8.') ||
    gradeText.includes('lise') ||
    gradeText.includes('12') ||
    gradeText.includes('13') ||
    gradeText.includes('14');

  if (!isSenior) {
    // 6-10 YAŞ (1-4. SINIF) - RENKLİ, MASKOTLU, BÜYÜK BUTONLU MACERA DÜNYASI
    return {
      tier: 'junior',
      badgeTitle: `🌟 Kahraman Kaşif • ${student.avatar_config.grade || 'İlkokul'}`,
      welcomeSubtitle: 'Bugün hangi eğlenceli maceraları tamamlayacağız?',
      pointsLabel: 'ALTIN YILDIZ',
      pointsSubtext: 'Ödül Çadırında Harca!',
      piggyLabel: '💎 BİRİKİM KASASI',
      piggyTitle: '💎 Birikim Kasası / Altın Kumbara ✨',
      piggyDesc:
        'Altın yıldızlarını hemen harcamayıp Birikim Kasasına / Altın Kumbaraya atarsan, her Pazar gecesi kasan büyür ve +%20 ekstra altın kazandırır!',
      shieldLabel: 'SÜPER KALKAN',
      shieldSubtext: 'Korursan +20 Yıldız!',
      questsTabTitle: '🗺️ Günlük Maceralarım',
      marketTabTitle: '🎪 Sürpriz Ödül Çadırı',
      piggyWheelTabTitle: '💎 Altın Kumbara & Şans Çarkı',
      comboBannerTitle: '🌈 SÜPER SABAH KAHRAMANI BONUSU!',
      comboBannerDesc:
        'Diş fırçalama, yatak toplama ve çanta hazırlamayı bitirirsen anında +15 Altın Yıldız kazanırsın!',
      photoProofBadge: '📸 Fotoğraf Çek & Göster',
      photoButtonText: 'Ödevimi Çek & Gönder 📸',
      completeButtonText: 'Yaptım! Yıldızımı Ver 🎉',
      lockBadge: '🐱🌱 UYUYAN KEDİ & BİLGİ AĞACI KORUMASI',
      lockHeadline: 'Şşşt! Sen Ödev Yaparken Kedimiz Güç Topluyor 🐾',
      lockSubtext:
        'Sen masanda ödevini yaparken minik kedimiz uyuyor ve bilgi ağacın büyüyor. Ekrana gereksiz dokunup kediyi uyandırma, kalkanların kırılmasın!',
      lockMascotEmojis: '🌳🐱🍄✨',
      lockSensorWarning:
        'Dokunma Sensörü Açık: Boş ekrana dokunursan kedi uyanır ve 1 Süper Kalkanın kırılır!',
      wakeHeaderBadge: '☀️ GÜNAYDIN KÜÇÜK KAHRAMAN! UYANMA VAKTİ!',
      wakeCatchInstruction: 'Görev 1/2: Zıplayan Neşeli Güneş Yıldızlarını Yakala!',
      wakeTargetEmoji: '⭐',
      riddles: [
        {
          question:
            'Sabahları doğarım, dünyayı ısıtırım; akşam olunca saklanırım. Ben kimim?',
          options: ['Güneş ☀️', 'Bulut ☁️', 'Kardan Adam ⛄'],
          correctIndex: 0,
        },
        {
          question:
            'Günde iki kez dişlerimizi parlatan en yakın sabah dostumuz hangisidir?',
          options: ['Yastık 🛏️', 'Diş Fırçası 🪥', 'Oyuncak Araba 🚗'],
          correctIndex: 1,
        },
        {
          question: '8 + 7 işleminin sonucu kaçtır? Sabah zihin açıcı soru!',
          options: ['13', '15', '17'],
          correctIndex: 1,
        },
      ],
      heroGradient:
        'bg-gradient-to-r from-amber-600/90 via-orange-600/85 to-indigo-900 border-amber-300/60',
      cardBorderRadius: 'rounded-3xl',
      titleFontSize: 'text-lg sm:text-xl',
      actionButtonGradient:
        'bg-gradient-to-r from-amber-400 to-orange-500 hover:from-amber-300 hover:to-orange-400 text-slate-950',
    };
  }

  // 11-15 YAŞ (5-8. SINIF & LİSE) - SİBER AKADEMİ, XP/LEVEL, OYUN KONSOLU & STRATEJİ DÜNYASI
  const level = Math.max(1, Math.floor((student.points_balance + student.piggy_bank_balance) / 50));
  return {
    tier: 'senior',
    badgeTitle: `⚡ LVL ${level} Siber Stratejist • ${student.avatar_config.grade || 'Ortaokul'}`,
    welcomeSubtitle: 'Günlük XP hedeflerini tamamla, serini koru ve ödül mağazasını aç.',
    pointsLabel: 'XP BAKİYESİ',
    pointsSubtext: 'Kullanılabilir Kredi',
    piggyLabel: 'YATIRIM KASASI',
    piggyTitle: 'XP Yatırım Kasası 📈💎',
    piggyDesc:
      'Kredilerini hemen harcamayıp Yatırım Kasasına kilitlersen, her Pazar gecesi kasadaki bakiyene otomatik +%20 bileşik getiri eklenir.',
    shieldLabel: 'ODAK ENERJİSİ',
    shieldSubtext: 'Tam Koruma: +20 XP',
    questsTabTitle: '🎯 Aktif Quest & Görevler',
    marketTabTitle: '🕹️ Dijital & Sosyal Mağaza',
    piggyWheelTabTitle: '📈 Yatırım Kasası & Loot Çarkı',
    comboBannerTitle: '⚡ SABAH SERİSİ (MORNING STREAK) ÇARPANI',
    comboBannerDesc:
      'Sabah rutin zincirini eksiksiz tamamladığında hesabına otomatik +15 Bonus XP aktarılır.',
    photoProofBadge: '📸 Kanıt Doğrulama (Photo Proof)',
    photoButtonText: 'Çözüm Kanıtı Yükle 📸',
    completeButtonText: 'Tamamlandı (+XP Al) ⚡',
    lockBadge: '🚀 DEEP FOCUS (DERİN ODAK) PROTOKOLÜ AKTİF',
    lockHeadline: 'Derin Odak Modu: XP Çarpanın Yükleniyor ⚡',
    lockSubtext:
      'Şu an tüm cihazların çalışma protokolünde. Odak süresi boyunca ekranla etkileşime girmeyerek 3 Odak Enerjini koru ve gün sonu +20 XP bonusunu al.',
    lockMascotEmojis: '🪐⚡🛰️💎',
    lockSensorWarning:
      'Odak Kalkanı Sensörü: Çalışma süresi bitmeden ekrana dokunmak veya uygulamayı alta atmak 1 Odak Enerjisi düşürür.',
    wakeHeaderBadge: '⚡ SİBER AKADEMİ SABAH SENKRONİZASYONU AKTİF',
    wakeCatchInstruction: 'Aşama 1/2: Refleks Testi — Hareketli Enerji Kürelerini Yakala!',
    wakeTargetEmoji: '💠',
    riddles: [
      {
        question: '3² + 4² işleminin sonucu kaçtır? (Sabah zihin kalibrasyonu)',
        options: ['14', '25', '49'],
        correctIndex: 1,
      },
      {
        question:
          'Bir ders seansı 40 dakika sürüyorsa, 3 seans toplam kaç saat yapar?',
        options: ['1.5 Saat', '2 Saat', '2.5 Saat'],
        correctIndex: 1,
      },
      {
        question:
          'Güneş sistemimizde "Kızıl Gezegen" olarak bilinen gezegen hangisidir?',
        options: ['Venüs', 'Mars', 'Jüpiter'],
        correctIndex: 1,
      },
    ],
    heroGradient:
      'bg-gradient-to-r from-slate-900 via-purple-950 to-fuchsia-950 border-fuchsia-500/50',
    cardBorderRadius: 'rounded-2xl',
    titleFontSize: 'text-base sm:text-lg',
    actionButtonGradient:
      'bg-gradient-to-r from-fuchsia-600 to-indigo-600 hover:from-fuchsia-500 hover:to-indigo-500 text-white',
  };
}
