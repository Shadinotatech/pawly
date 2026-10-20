import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'store.dart';

/// Test builds (the APK from GitHub) are made with
/// --dart-define=PAWLY_TEST_PRO=true so Pro can be tried without paying.
/// The Play Store bundle is built without it.
const bool kTestBuild = bool.fromEnvironment('PAWLY_TEST_PRO');

/// Product IDs. Create exactly these in Play Console > Monetize.
class ProProducts {
  static const monthly = 'pawly_pro_monthly'; // subscription
  static const yearly = 'pawly_pro_yearly'; // subscription
  static const lifetime = 'pawly_pro_lifetime'; // one-time product
  static const all = {monthly, yearly, lifetime};
}

enum ProPlan { monthly, yearly, lifetime }

/// Handles Google Play purchases for Pawly Pro.
class ProService extends ChangeNotifier {
  ProService(this.store);

  final AppStore store;
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  bool busy = false;
  String? message;
  final Map<String, ProductDetails> products = {};

  /// Prices shown before Play returns real ones.
  static const fallbackPrice = {
    ProPlan.monthly: r'$2.99',
    ProPlan.yearly: r'$14.99',
    ProPlan.lifetime: r'$29.99',
  };

  String idFor(ProPlan p) => switch (p) {
        ProPlan.monthly => ProProducts.monthly,
        ProPlan.yearly => ProProducts.yearly,
        ProPlan.lifetime => ProProducts.lifetime,
      };

  String priceFor(ProPlan p) => products[idFor(p)]?.price ?? fallbackPrice[p]!;

  Future<void> init() async {
    try {
      available = await _iap.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) {
      notifyListeners();
      return;
    }
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      busy = false;
      message = 'Purchase failed. Please try again.';
      notifyListeners();
    });
    try {
      final r = await _iap.queryProductDetails(ProProducts.all);
      for (final p in r.productDetails) {
        // Subscriptions can return one entry per offer; keep the first.
        products.putIfAbsent(p.id, () => p);
      }
    } catch (e) {
      debugPrint('Product query failed: $e');
    }
    await refreshOwnership();
    notifyListeners();
  }

  /// Checks Google Play for an active subscription or lifetime purchase.
  Future<void> refreshOwnership() async {
    if (!available) return;
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await addition.queryPastPurchases();
      if (r.error != null) return; // keep cached state when offline
      final owned =
          r.pastPurchases.any((p) => ProProducts.all.contains(p.productID));
      if (owned != store.settings.proOwned) {
        store.settings.proOwned = owned;
        store.changed();
      }
    } catch (e) {
      debugPrint('Ownership check failed: $e');
    }
  }

  Future<void> buy(ProPlan plan) async {
    message = null;
    final product = products[idFor(plan)];
    if (!available || product == null) {
      message = kTestBuild
          ? 'Store purchases work after the app is on Google Play. In this test build, use "Unlock Pro for testing".'
          : 'Google Play is not available right now. Please try again later.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      busy = false;
      message = 'Could not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    message = null;
    if (!available) {
      message = 'Google Play is not available right now.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    await refreshOwnership();
    busy = false;
    message = store.settings.proOwned
        ? 'Pro restored. Thank you!'
        : 'No Pro purchase found on this Google account.';
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!ProProducts.all.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          busy = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          store.settings.proOwned = true;
          store.changed();
          busy = false;
          message = 'Welcome to Pawly Pro!';
        case PurchaseStatus.error:
          busy = false;
          message = 'Purchase failed. You were not charged.';
        case PurchaseStatus.canceled:
          busy = false;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
