import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'session_manager.dart';
import 'supabase_service.dart';
import '../screens/paywall_screen.dart';

/// ===========================================================================
/// subscription_service.dart - REVENUECAT ENTEGRASYONU VE PRO LİSANS YÖNETİMİ
/// ===========================================================================
/// SOLID: Single Responsibility Principle (SRP)
/// Uygulama içi satın alımları (RevenueCat), 7 günlük deneme süresini ve
/// Supabase veritabanındaki `subscription_tier` alanının senkronizasyonunu yönetir.
/// ===========================================================================

class SubscriptionService {
  static const String appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: 'appl_TEST_API_KEY',
  );
  static const String proEntitlementId = 'pro';

  static bool _isInitialized = false;
  static bool _isPro = false;
  static CustomerInfo? _customerInfo;

  static final StreamController<bool> _proStateController =
      StreamController<bool>.broadcast();
  static Stream<bool> get proStateStream => _proStateController.stream;

  static bool get isPro => _isPro;
  static CustomerInfo? get customerInfo => _customerInfo;

  /// RevenueCat SDK Başlatma
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final configuration = PurchasesConfiguration(appleApiKey);
        if (SessionManager.familyId.isNotEmpty) {
          configuration.appUserID = SessionManager.familyId;
        }

        await Purchases.configure(configuration);
        _isInitialized = true;

        Purchases.addCustomerInfoUpdateListener((info) {
          _updateCustomerInfo(info);
        });

        final info = await Purchases.getCustomerInfo();
        await _updateCustomerInfo(info);
      }
    } catch (e) {
      print('[SubscriptionService] RevenueCat başlatma uyarısı: $e');
    }

    // Supabase ile de başlangıç durumunu teyit et (7 günlük trial dahil)
    await checkIsPro();
  }

  /// Kullanıcı oturum açtığında RevenueCat ile eşleştir
  static Future<void> logIn(String familyId) async {
    if (!_isInitialized || familyId.isEmpty) return;
    try {
      final result = await Purchases.logIn(familyId);
      await _updateCustomerInfo(result.customerInfo);
    } catch (e) {
      print('[SubscriptionService] logIn hatası: $e');
    }
  }

  /// Aktif Paketleri (Offerings) Getir
  static Future<Offerings?> getOfferings() async {
    if (!_isInitialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('[SubscriptionService] getOfferings hatası: $e');
      return null;
    }
  }

  /// Paket Satın Al (RevenueCat + Supabase Eşitleme)
  static Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final hasPro = customerInfo.entitlements.active.containsKey(proEntitlementId);
      if (hasPro) {
        await _updateCustomerInfo(customerInfo);
        await _syncProWithSupabase(customerInfo);
        return true;
      }
    } catch (e) {
      print('[SubscriptionService] purchasePackage hatası: $e');
    }
    return false;
  }

  /// Satın Alımları Geri Yükle (Restore Purchases)
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final hasPro = customerInfo.entitlements.active.containsKey(proEntitlementId);
      await _updateCustomerInfo(customerInfo);
      if (hasPro) {
        await _syncProWithSupabase(customerInfo);
      }
      return hasPro;
    } catch (e) {
      print('[SubscriptionService] restorePurchases hatası: $e');
      return false;
    }
  }

  /// Pro Durumunu Hem RevenueCat Hem Supabase Üzerinden Doğrula
  static Future<bool> checkIsPro() async {
    bool rcPro = false;
    if (_isInitialized) {
      try {
        final info = await Purchases.getCustomerInfo();
        rcPro = info.entitlements.active.containsKey(proEntitlementId);
      } catch (_) {}
    }

    bool dbPro = false;
    final famId = SessionManager.familyId;
    if (famId.isNotEmpty) {
      try {
        dbPro = await SupabaseService.checkIsFamilyPro(famId);
      } catch (_) {}
    }

    final newStatus = rcPro || dbPro;
    if (_isPro != newStatus) {
      _isPro = newStatus;
      _proStateController.add(_isPro);
    }
    return _isPro;
  }

  /// Supabase ile Pro Durumunu Senkronize Et
  static Future<void> _syncProWithSupabase(CustomerInfo info) async {
    final famId = SessionManager.familyId;
    if (famId.isEmpty) return;

    try {
      final expDate = info.entitlements.active[proEntitlementId]?.expirationDate;
      await SupabaseService.client.from('families').update({
        'subscription_tier': 'pro',
        'subscription_status': 'active',
        'rc_app_user_id': info.originalAppUserId,
        if (expDate != null) 'pro_expires_at': expDate,
      }).eq('id', famId);
      _isPro = true;
      _proStateController.add(true);
    } catch (e) {
      print('[SubscriptionService] Supabase senkronizasyon hatası: $e');
    }
  }

  static Future<void> _updateCustomerInfo(CustomerInfo info) async {
    _customerInfo = info;
    final hasPro = info.entitlements.active.containsKey(proEntitlementId);
    if (_isPro != hasPro) {
      _isPro = hasPro;
      _proStateController.add(_isPro);
    }
  }

  /// Kilitli Özellik Sarmalayıcısı (Feature Gating Wrapper)
  /// Kullanıcı Pro ise işlemi doğrudan çalıştırır, değilse Paywall modalını açar.
  static Future<void> withProCheck(
    BuildContext context, {
    required VoidCallback onAllowed,
    String featureTitle = 'FamilyOS Pro',
  }) async {
    final pro = await checkIsPro();
    if (pro) {
      onAllowed();
    } else if (context.mounted) {
      PaywallScreen.show(context, triggerFeature: featureTitle);
    }
  }
}
