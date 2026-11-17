/// Moves what a guest kept on the device (cart, favorites) into the account
/// right after sign-in, like lamsa-web's `mergeAfterSignIn`.
///
/// The backend stores nothing for guests: the app sends the device data once
/// (`POST /favorites/merge`, then `POST /cart/merge`) and clears it. Implementations
/// must never block or fail a sign-in.
abstract interface class GuestDataMerger {
  Future<void> merge();
}

/// Placeholder until the cart/favorites phase: the app has no guest cart or
/// favorites yet, so there is nothing to merge.
// TODO(cart phase): replace with the real merge (favorites first, then cart).
final class NoopGuestDataMerger implements GuestDataMerger {
  const NoopGuestDataMerger();

  @override
  Future<void> merge() async {}
}
