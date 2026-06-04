import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';
import '../logger.dart';
import '../preferences/service_region.dart';

/// RevenueCat: mainland iOS Pro lifetime + addon; ShrimpSend overseas subscriptions.
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  static bool get _isIos => Platform.isIOS;

  static bool get _isAndroidOverseas =>
      Platform.isAndroid &&
      Env.prodServiceRegion == ServiceRegion.international;

  static bool get _rcConfigured => Env.rcApiKey.isNotEmpty;

  /// Configure after login (iOS / Android overseas when RC key set).
  Future<void> configureIfNeeded(String? userId) async {
    if (!_rcConfigured) return;
    if (!_isIos && !_isAndroidOverseas) return;
    if (userId == null || userId.isEmpty) return;
    try {
      final configured = await Purchases.isConfigured;
      if (configured) {
        await Purchases.logIn(userId);
        logApi.info('RevenueCat logIn userId=$userId');
        return;
      }
      await Purchases.configure(PurchasesConfiguration(Env.rcApiKey)
        ..appUserID = userId);
      logApi.info('RevenueCat configure appUserId=$userId platform=${Platform.operatingSystem}');
    } on PlatformException catch (e) {
      logApi.warning('RevenueCat configure failed: ${e.message}');
    }
  }

  /// Clears the RC session on logout so the next login can bind a different user.
  Future<void> logOutIfNeeded() async {
    if (!_rcConfigured) return;
    if (!_isIos && !_isAndroidOverseas) return;
    try {
      final configured = await Purchases.isConfigured;
      if (!configured) return;
      await Purchases.logOut();
      logApi.info('RevenueCat logOut');
    } on PlatformException catch (e) {
      logApi.warning('RevenueCat logOut failed: ${e.message}');
    }
  }

  String? getProductIdForTier(String tierCode) {
    switch (tierCode.toUpperCase()) {
      case 'PRO':
        return Env.rcProductPro;
      case 'ADDON_5':
        return Env.rcProductAddon5;
      case 'PLUS_MONTHLY':
        return Env.rcPlusMonthly;
      case 'PLUS_YEARLY':
        return Env.rcPlusYearly;
      case 'PRO_MONTHLY':
        return Env.rcProMonthly;
      case 'PRO_YEARLY':
        return Env.rcProYearly;
      case 'ULTRA_MONTHLY':
        return Env.rcUltraMonthly;
      case 'ULTRA_YEARLY':
        return Env.rcUltraYearly;
      default:
        return null;
    }
  }

  ProductCategory _categoryForTierCode(String tierCode) {
    final u = tierCode.toUpperCase();
    if (u.contains('MONTHLY') ||
        u.contains('YEARLY') ||
        u.contains('_M') ||
        u.contains('_Y')) {
      return ProductCategory.subscription;
    }
    return ProductCategory.nonSubscription;
  }

  /// Store purchase (iOS/Android overseas subscriptions or mainland lifetime).
  Future<bool> purchaseTier(String tierCode) async {
    if (!_isIos && !_isAndroidOverseas) return false;
    if (!_rcConfigured) return false;
    final productId = getProductIdForTier(tierCode);
    if (productId == null || productId.isEmpty) return false;
    final category = _categoryForTierCode(tierCode);
    try {
      final products = await Purchases.getProducts(
        [productId],
        productCategory: category,
      );
      if (products.isEmpty) {
        logApi.warning('RevenueCat product not found: $productId');
        return false;
      }
      await Purchases.purchase(
        PurchaseParams.storeProduct(products.first),
      );
      logApi.info('RevenueCat purchase success tier=$tierCode');
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'PurchaseCancelledError' || e.message?.contains('cancelled') == true) {
        logApi.info('RevenueCat purchase cancelled');
        return false;
      }
      logApi.warning('RevenueCat purchase failed: ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Restore App Store / Play purchases (required for review; also helps after reinstall).
  Future<bool> restorePurchases() async {
    if (!_isIos && !_isAndroidOverseas) return false;
    if (!_rcConfigured) return false;
    try {
      await Purchases.restorePurchases();
      logApi.info('RevenueCat restorePurchases completed');
      return true;
    } on PlatformException catch (e) {
      logApi.warning('RevenueCat restorePurchases failed: ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Mainland iOS lifetime OR overseas iOS/Android subscriptions.
  bool get canUseApplePurchase => _isIos && _rcConfigured;

  bool get canUseOverseasStorePurchase =>
      _rcConfigured && (_isIos || _isAndroidOverseas);

  /// Whether restore purchases should be offered (same platforms as store purchase).
  bool get canRestorePurchases => canUseOverseasStorePurchase || canUseApplePurchase;
}
