import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';

/// Toggles the heart of [productId] and tells the shopper what happened:
/// "أُضيف إلى المفضلة" (with a link to the tab), "أُزيل من المفضلة", or the
/// error when it was rolled back. Works the same for guests and signed-in
/// users; the cubit decides where the data lives.
Future<void> toggleFavorite(
  BuildContext context, {
  required int productId,
  String slug = '',
}) async {
  final router = GoRouter.maybeOf(context);
  final result = await context
      .read<FavoritesCubit>()
      .toggle(productId, slug: slug);
  if (result == FavoriteResult.ignored) return;
  if (!result.ok) {
    showToast(result.error?.text ?? Strings.errorGeneric);
    return;
  }
  showToast(
    result.on ? Strings.toastFavAdded : Strings.toastFavRemoved,
    actionLabel: result.on ? Strings.toastFavAction : null,
    onAction: result.on && router != null
        ? () => router.go(Routes.favorites)
        : null,
  );
}

/// The heart. Filled when the product is a favorite (from the shared
/// favorites store, so every heart for the same product agrees).
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    required this.productId,
    this.slug = '',
    this.size = 20,
    this.overlay = true,
    super.key,
  });

  final int productId;
  final String slug;
  final double size;

  /// A translucent round background (on top of a card image).
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return BlocSelector<FavoritesCubit, FavoritesState, bool>(
      selector: (s) => s.ids.contains(productId),
      builder: (context, on) => Semantics(
        toggled: on,
        child: IconButton(
          tooltip: Strings.productFavorite,
          icon: Icon(on ? Icons.favorite : Icons.favorite_border, size: size),
          color: on ? c.accent : c.ink,
          style: overlay
              ? IconButton.styleFrom(
                  backgroundColor: c.surface.withValues(alpha: .85),
                )
              : null,
          onPressed: () =>
              toggleFavorite(context, productId: productId, slug: slug),
        ),
      ),
    );
  }
}
