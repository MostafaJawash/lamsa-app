import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:lamsa_app/features/auth/data/guest_data_merger.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

/// What a completed merge changed (for the toast and the cubits).
final class MergeOutcome extends Equatable {
  const MergeOutcome({this.cart, this.restored = 0, this.adjusted = false});

  /// The whole cart after the merge (null when only favorites were merged).
  final Cart? cart;

  /// Cart lines that ended up in the account (added, merged or capped).
  final int restored;

  /// Something was capped or skipped.
  final bool adjusted;

  @override
  List<Object?> get props => [cart, restored, adjusted];
}

/// Sends the guest cart and favorites to the backend right after sign-in, then
/// clears them. Rules (backend README "Guests", same as lamsa-web):
///
/// - favorites first (`POST /favorites/merge`), then the cart
///   (`POST /cart/merge`); merging favorites twice is harmless, so a failed
///   cart merge can simply be retried;
/// - the cart merge never fails because of one bad item: every line is
///   reported as `added`, `merged`, `capped` (stock/limit) or `skipped`
///   (not found, out of stock, ...) and the response is the whole cart;
/// - local data is cleared only after both calls succeed. A failure keeps it
///   and rethrows, so the caller can retry later (the next sign-in, launch or
///   cart load). It never blocks the sign-in itself.
///
/// Calls are single-flight: concurrent triggers share one merge.
class GuestMergeService {
  GuestMergeService(this._api, this._store);

  final CartApi _api;
  final GuestStore _store;

  Future<MergeOutcome?>? _inflight;

  /// Whether there is anything on the device to merge.
  Future<bool> hasPending() async =>
      (await _store.readCart()).isNotEmpty ||
      (await _store.readFavorites()).isNotEmpty;

  /// Merges when there is local data; null when there was nothing to merge.
  Future<MergeOutcome?> mergeIfAny() =>
      _inflight ??= _run().whenComplete(() => _inflight = null);

  Future<MergeOutcome?> _run() async {
    final cart = await _store.readCart();
    final favorites = await _store.readFavorites();
    if (cart.isEmpty && favorites.isEmpty) return null;

    if (favorites.isNotEmpty) {
      await _api.mergeFavorites([for (final f in favorites) f.productId]);
    }
    var outcome = const MergeOutcome();
    if (cart.isNotEmpty) {
      final merged = await _api.mergeCart(cart);
      outcome = MergeOutcome(
        cart: merged.cart,
        restored: merged.restored,
        adjusted: merged.adjusted,
      );
    }
    await _store.clearAll();
    return outcome;
  }
}

/// The real [GuestDataMerger] (replaces the phase-2 no-op): merge guest data,
/// tell the shopper what happened, and switch the app's cart and favorites to
/// the backend. Skipped by `SessionCubit` while a temporary password is
/// pending; it runs after the password change signs in again.
class CommerceMerger implements GuestDataMerger {
  CommerceMerger(this._service, {this.onMerged, this.onSignedIn});

  final GuestMergeService _service;

  /// Shows the toast for a non-empty merge.
  final void Function(MergeOutcome outcome)? onMerged;

  /// Reloads the cart and favorites from the backend (always, even when there
  /// was nothing to merge or the merge failed).
  final Future<void> Function(MergeOutcome? outcome)? onSignedIn;

  @override
  Future<void> merge() async {
    MergeOutcome? outcome;
    try {
      outcome = await _service.mergeIfAny();
      if (outcome != null) onMerged?.call(outcome);
    } on Object {
      // Local data stays; the next cart load retries.
      outcome = null;
    }
    await onSignedIn?.call(outcome);
  }
}
