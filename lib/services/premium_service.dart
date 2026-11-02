import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress_store.dart';

/// One-time "Remove Ads" purchase.
abstract class PremiumService extends ChangeNotifier {
  bool get isPremium;

  /// True once the store is reachable and the product exists, i.e. the purchase can be offered.
  bool get available;

  /// Localized price from the store, e.g. "$3.99".
  String? get price;

  Future<void> buy();
  Future<void> restore();
}

/// Web and tests: nothing to buy.
class NoPremiumService extends PremiumService {
  @override
  bool get isPremium => false;
  @override
  bool get available => false;
  @override
  String? get price => null;
  @override
  Future<void> buy() async {}
  @override
  Future<void> restore() async {}
}

/// Google Play / App Store purchase of [productId], cached in [ProgressStore] so it holds offline.
class StorePremiumService extends PremiumService {
  StorePremiumService(this._progress, {InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  static const productId = 'remove_ads';

  final ProgressStore _progress;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  @override
  bool get isPremium => _progress.premium;
  @override
  bool get available => _product != null && !isPremium;
  @override
  String? get price => _product?.price;

  /// Listens for purchases (including ones finished while the app was closed) and loads the product.
  Future<void> init() async {
    _sub = _store.purchaseStream.listen(_onPurchases, onError: (_) {});
    try {
      if (!await _store.isAvailable()) return;
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) _product = response.productDetails.first;
      notifyListeners();
      if (!isPremium) await _store.restorePurchases(); // reinstall or new device
    } catch (_) {
      // No store (emulator without Play, offline): the purchase just isn't offered.
    }
  }

  @override
  Future<void> buy() async {
    final product = _product;
    if (product == null) return;
    await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  @override
  Future<void> restore() => _store.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId &&
          (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored)) {
        await _progress.setPremium(true);
        notifyListeners();
      }
      if (p.pendingCompletePurchase) await _store.completePurchase(p);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
