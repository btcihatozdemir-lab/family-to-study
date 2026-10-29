import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

abstract class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return instance ?? _AppLocalizationsTr(const Locale('tr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('de'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  // Metin tanımları
  String get appTitle;
  String get parentPortalTitle;
  String get kidsPortalTitle;

  String get signInWithApple;
  String get signInWithGoogle;
  String get orParentPin;
  String get existingFamilyTab;
  String get createFamilyTab;
  String get familyCodeHint;
  String get parentPinHint;
  String get loginButton;

  String get onboardingWelcomeTitle;
  String get onboardingWelcomeSubtitle;
  String get createMyFamily;
  String get joinPartnerFamily;
  String get sevenDayTrialBadge;
  String get familyNameLabel;
  String get parentNameLabel;
  String get partnerCodeLabel;
  String get roleLabel;
  String get genderLabel;
  String get createAndStartButton;
  String get joinFamilyButton;

  String get paywallTitle;
  String get paywallSubtitle;
  String get freeTrialButton;
  String get monthlyPlan;
  String get annualPlan;
  String get restorePurchases;
  String get cancelAnytime;

  String get dangerZoneTitle;
  String get dangerZoneDesc;
  String get deleteAccountButton;
  String get deleteAccountConfirmTitle;
  String get deleteAccountConfirmDesc;
  String get cancel;
  String get confirmDelete;

  String get statusFocusTime;
  String get statusBreakTime;
  String get statusFreeTime;
  String get coins;
  String get shield;
  String streakDays(int count);

  String get wakeUpTitle;
  String get wakeUpGentleVoice;
  String get appMinimizedWarning;
  String get taskApprovedVoice;
  String get breakFinishedVoice;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(_lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['tr', 'en', 'de'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations _lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return _AppLocalizationsEn(locale);
    case 'de':
      return _AppLocalizationsDe(locale);
    case 'tr':
    default:
      return _AppLocalizationsTr(locale);
  }
}

// ---------------------------------------------------------------------------
// TÜRKÇE (TR)
// ---------------------------------------------------------------------------
class _AppLocalizationsTr extends AppLocalizations {
  _AppLocalizationsTr(super.locale);

  @override
  String get appTitle => 'FamilyOS - FamilyToStudy';
  @override
  String get parentPortalTitle => 'Ebeveyn & Veli Komuta Merkezi';
  @override
  String get kidsPortalTitle => 'Öğrenci & Odaklanma Modu';

  @override
  String get signInWithApple => 'Apple ile Ebeveyn Girişi Yap';
  @override
  String get signInWithGoogle => 'Google ile Ebeveyn Girişi Yap';
  @override
  String get orParentPin => 'veya Ebeveyn Şifresi ile';
  @override
  String get existingFamilyTab => 'Mevcut Aile';
  @override
  String get createFamilyTab => 'Yeni Aile Kur';
  @override
  String get familyCodeHint => 'AİLE KODU (FAMZDE-2026)';
  @override
  String get parentPinHint => '4 Haneli Ebeveyn PIN';
  @override
  String get loginButton => 'Giriş Yap';

  @override
  String get onboardingWelcomeTitle => 'FamilyOS\'a Hoş Geldiniz';
  @override
  String get onboardingWelcomeSubtitle => 'Hemen ailenizi kurun veya mevcut aileye katılın';
  @override
  String get createMyFamily => 'Kendi Ailemi Kur';
  @override
  String get joinPartnerFamily => 'Eşimin Ailesine Katıl';
  @override
  String get sevenDayTrialBadge => 'İlk aile kurulumunuza özel 7 Gün Sınırsız Pro Deneme hediye!';
  @override
  String get familyNameLabel => 'AİLE ADI / SOYADI';
  @override
  String get parentNameLabel => 'EBEVEYN ADI VE SOYADI';
  @override
  String get partnerCodeLabel => 'EŞİNİZİN AİLE KODU';
  @override
  String get roleLabel => 'ROL / ÜNVAN';
  @override
  String get genderLabel => 'CİNSİYET';
  @override
  String get createAndStartButton => 'Kendi Ailemi Kur & Başla';
  @override
  String get joinFamilyButton => 'Eşimin Ailesine Katıl';

  @override
  String get paywallTitle => 'FamilyOS Pro\'ya Yükselt';
  @override
  String get paywallSubtitle => 'Tüm çocuk cihazları, Windows ekran kilidi ve canlı kalkan koruması tek pakette.';
  @override
  String get freeTrialButton => '7 Gün Ücretsiz Dene ve Başla';
  @override
  String get monthlyPlan => 'Aylık Pro';
  @override
  String get annualPlan => 'Yıllık Pro (2 Ay Hediye)';
  @override
  String get restorePurchases => 'Satın Alımları Geri Yükle';
  @override
  String get cancelAnytime => 'İstediğiniz zaman App Store ayarlarından iptal edebilirsiniz.';

  @override
  String get dangerZoneTitle => 'Tehlikeli Bölge (Danger Zone)';
  @override
  String get dangerZoneDesc => 'App Store Gizlilik Şartı (Guideline 5.1.1(v)) gereğince hesabınızı ve ailenize ait tüm verileri istediğiniz zaman anında ve kalıcı olarak silebilirsiniz.';
  @override
  String get deleteAccountButton => 'Hesabımı ve Tüm Aile Verilerimi Kalıcı Olarak Sil';
  @override
  String get deleteAccountConfirmTitle => 'Hesabı Kalıcı Olarak Sil';
  @override
  String get deleteAccountConfirmDesc => 'Bu işlem geri alınamaz! Ailenize ait tüm profiller, görevler ve kayıtlar veritabanımızdan kalıcı olarak silinecektir. Devam etmek istiyor musunuz?';
  @override
  String get cancel => 'Vazgeç';
  @override
  String get confirmDelete => 'Evet, Kalıcı Olarak Sil';

  @override
  String get statusFocusTime => 'Odaklanma Saati';
  @override
  String get statusBreakTime => 'Mola Vakti';
  @override
  String get statusFreeTime => 'Serbest Zaman';
  @override
  String get coins => 'Altın';
  @override
  String get shield => 'Kalkan';
  @override
  String streakDays(int count) => '$count Gün Seri';

  @override
  String get wakeUpTitle => 'Günaydın! Yeni Bir Gün Başlıyor';
  @override
  String get wakeUpGentleVoice => 'Günaydın! Yeni ve harika bir güne hazır mısın? Görevlerin seni bekliyor.';
  @override
  String get appMinimizedWarning => 'Ders saatin devam ediyor, kalkanını korumak için uygulamaya dönelim.';
  @override
  String get taskApprovedVoice => 'Tebrikler! Görevin onaylandı, harika iş çıkardın!';
  @override
  String get breakFinishedVoice => 'Molan bitti, haydi tekrar derse odaklanalım.';
}

// ---------------------------------------------------------------------------
// İNGİLİZCE (EN)
// ---------------------------------------------------------------------------
class _AppLocalizationsEn extends AppLocalizations {
  _AppLocalizationsEn(super.locale);

  @override
  String get appTitle => 'FamilyOS - FamilyToStudy';
  @override
  String get parentPortalTitle => 'Parent & Family Command Center';
  @override
  String get kidsPortalTitle => 'Student & Focus Mode';

  @override
  String get signInWithApple => 'Sign in with Apple';
  @override
  String get signInWithGoogle => 'Sign in with Google';
  @override
  String get orParentPin => 'or with Parent PIN';
  @override
  String get existingFamilyTab => 'Existing Family';
  @override
  String get createFamilyTab => 'Create New Family';
  @override
  String get familyCodeHint => 'FAMILY CODE (FAM-9X2A)';
  @override
  String get parentPinHint => '4-Digit Parent PIN';
  @override
  String get loginButton => 'Log In';

  @override
  String get onboardingWelcomeTitle => 'Welcome to FamilyOS';
  @override
  String get onboardingWelcomeSubtitle => 'Set up your family workspace or join an existing one';
  @override
  String get createMyFamily => 'Create My Family';
  @override
  String get joinPartnerFamily => 'Join Spouse\'s Family';
  @override
  String get sevenDayTrialBadge => 'Special gift: 7-Day Unlimited Pro Trial included!';
  @override
  String get familyNameLabel => 'FAMILY NAME';
  @override
  String get parentNameLabel => 'PARENT FULL NAME';
  @override
  String get partnerCodeLabel => 'SPOUSE\'S FAMILY CODE';
  @override
  String get roleLabel => 'ROLE / TITLE';
  @override
  String get genderLabel => 'GENDER';
  @override
  String get createAndStartButton => 'Create Family & Start';
  @override
  String get joinFamilyButton => 'Join Family';

  @override
  String get paywallTitle => 'Upgrade to FamilyOS Pro';
  @override
  String get paywallSubtitle => 'Unlimited child devices, Windows screen lock and live shield protection.';
  @override
  String get freeTrialButton => 'Start 7-Day Free Trial';
  @override
  String get monthlyPlan => 'Monthly Pro';
  @override
  String get annualPlan => 'Annual Pro (2 Months Free)';
  @override
  String get restorePurchases => 'Restore Purchases';
  @override
  String get cancelAnytime => 'Cancel anytime via App Store subscriptions.';

  @override
  String get dangerZoneTitle => 'Danger Zone';
  @override
  String get dangerZoneDesc => 'Under App Store Guideline 5.1.1(v), you can permanently delete your account and all family data anytime.';
  @override
  String get deleteAccountButton => 'Permanently Delete My Account & All Family Data';
  @override
  String get deleteAccountConfirmTitle => 'Permanently Delete Account';
  @override
  String get deleteAccountConfirmDesc => 'This action cannot be undone! All profiles, tasks, and data belonging to your family will be permanently erased. Do you wish to proceed?';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirmDelete => 'Yes, Delete Permanently';

  @override
  String get statusFocusTime => 'Study & Focus Mode';
  @override
  String get statusBreakTime => 'Break Time';
  @override
  String get statusFreeTime => 'Free Time';
  @override
  String get coins => 'Gold Coins';
  @override
  String get shield => 'Shield';
  @override
  String streakDays(int count) => '$count Day Streak';

  @override
  String get wakeUpTitle => 'Good Morning! A New Day Begins';
  @override
  String get wakeUpGentleVoice => 'Good morning! Ready for a wonderful day? Your morning missions await.';
  @override
  String get appMinimizedWarning => 'Study time is active. Return to the app to protect your shield.';
  @override
  String get taskApprovedVoice => 'Congratulations! Your task has been approved, great job!';
  @override
  String get breakFinishedVoice => 'Break time is over. Let\'s get back to focusing!';
}

// ---------------------------------------------------------------------------
// ALMANCA (DE)
// ---------------------------------------------------------------------------
class _AppLocalizationsDe extends AppLocalizations {
  _AppLocalizationsDe(super.locale);

  @override
  String get appTitle => 'FamilyOS - FamilyToStudy';
  @override
  String get parentPortalTitle => 'Eltern & Familien Kommandozentrale';
  @override
  String get kidsPortalTitle => 'Schüler & Fokusmodus';

  @override
  String get signInWithApple => 'Mit Apple anmelden';
  @override
  String get signInWithGoogle => 'Mit Google anmelden';
  @override
  String get orParentPin => 'oder mit Eltern-PIN';
  @override
  String get existingFamilyTab => 'Bestehende Familie';
  @override
  String get createFamilyTab => 'Neue Familie gründen';
  @override
  String get familyCodeHint => 'FAMILIEN-CODE (FAM-9X2A)';
  @override
  String get parentPinHint => '4-stellige Eltern-PIN';
  @override
  String get loginButton => 'Anmelden';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei FamilyOS';
  @override
  String get onboardingWelcomeSubtitle => 'Erstellen Sie Ihre Familie oder treten Sie einer bestehenden bei';
  @override
  String get createMyFamily => 'Eigene Familie gründen';
  @override
  String get joinPartnerFamily => 'Der Familie des Partners beitreten';
  @override
  String get sevenDayTrialBadge => 'Willkommensgeschenk: 7 Tage unbegrenztes Pro-Abo kostenlos!';
  @override
  String get familyNameLabel => 'FAMILIENNAME';
  @override
  String get parentNameLabel => 'VOLLSTÄNDIGER NAME DER ELTERN';
  @override
  String get partnerCodeLabel => 'FAMILIEN-CODE DES PARTNERS';
  @override
  String get roleLabel => 'ROLLE / TITEL';
  @override
  String get genderLabel => 'GESCHLECHT';
  @override
  String get createAndStartButton => 'Familie gründen & starten';
  @override
  String get joinFamilyButton => 'Familie beitreten';

  @override
  String get paywallTitle => 'Auf FamilyOS Pro upgraden';
  @override
  String get paywallSubtitle => 'Unbegrenzte Kindergeräte, Windows-Bildschirmsperre und Live-Schutzschild.';
  @override
  String get freeTrialButton => '7 Tage kostenlos testen';
  @override
  String get monthlyPlan => 'Monatlich Pro';
  @override
  String get annualPlan => 'Jährlich Pro (2 Monate gratis)';
  @override
  String get restorePurchases => 'Käufe wiederherstellen';
  @override
  String get cancelAnytime => 'Jederzeit in den App Store-Einstellungen kündbar.';

  @override
  String get dangerZoneTitle => 'Gefahrenbereich (Danger Zone)';
  @override
  String get dangerZoneDesc => 'Gemäß App Store Richtlinie 5.1.1(v) können Sie Ihr Konto und alle Familiendaten jederzeit dauerhaft löschen.';
  @override
  String get deleteAccountButton => 'Mein Konto & alle Daten endgültig löschen';
  @override
  String get deleteAccountConfirmTitle => 'Konto endgültig löschen';
  @override
  String get deleteAccountConfirmDesc => 'Diese Aktion kann nicht rückgängig gemacht werden! Alle Profile, Aufgaben und Daten werden dauerhaft gelöscht. Möchten Sie fortfahren?';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get confirmDelete => 'Ja, endgültig löschen';

  @override
  String get statusFocusTime => 'Lern- & Fokuszeit';
  @override
  String get statusBreakTime => 'Pause';
  @override
  String get statusFreeTime => 'Freizeit';
  @override
  String get coins => 'Goldmünzen';
  @override
  String get shield => 'Schutzschild';
  @override
  String streakDays(int count) => '$count Tage Serie';

  @override
  String get wakeUpTitle => 'Guten Morgen! Ein neuer Tag beginnt';
  @override
  String get wakeUpGentleVoice => 'Guten Morgen! Bereit für einen wunderbaren Tag? Deine Aufgaben warten.';
  @override
  String get appMinimizedWarning => 'Fokuszeit läuft. Kehre zur App zurück, um dein Schutzschild zu bewahren.';
  @override
  String get taskApprovedVoice => 'Herzlichen Glückwunsch! Deine Aufgabe wurde genehmigt, super gemacht!';
  @override
  String get breakFinishedVoice => 'Pause ist vorbei. Lass uns wieder konzentrieren!';
}
