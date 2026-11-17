import 'package:flutter/material.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/images/lamsa_image.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/features/catalog/data/brand_mark.dart';

/// The web's neutral "bottle" drawing, shown where a product has no image
/// (or it fails to load).
class ProductSilhouette extends StatelessWidget {
  const ProductSilhouette({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return ColoredBox(
      color: c.surface2,
      child: CustomPaint(
        painter: _BottlePainter(c.muted),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2)
      ..scale(side / 200);
    final p = Paint();
    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 179), width: 108, height: 14),
      p..color = Colors.black.withValues(alpha: .08),
    );
    // Cap and neck.
    p.color = color.withValues(alpha: .55);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(90, 26, 20, 18),
          const Radius.circular(4),
        ),
        p,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(84, 42, 32, 16),
          const Radius.circular(5),
        ),
        p,
      );
    // Body.
    p.color = color.withValues(alpha: .3);
    final body = Path()
      ..moveTo(68, 72)
      ..quadraticBezierTo(68, 58, 84, 58)
      ..lineTo(116, 58)
      ..quadraticBezierTo(132, 58, 132, 72)
      ..lineTo(132, 166)
      ..quadraticBezierTo(132, 174, 124, 174)
      ..lineTo(76, 174)
      ..quadraticBezierTo(68, 174, 68, 166)
      ..close();
    canvas
      ..drawPath(body, p)
      // Label and highlight.
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(80, 98, 40, 44),
          const Radius.circular(4),
        ),
        p..color = Colors.white.withValues(alpha: .6),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(74, 68, 7, 96),
          const Radius.circular(3.5),
        ),
        p..color = Colors.white.withValues(alpha: .25),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BottlePainter old) => old.color != color;
}

/// A backend image that fills its parent, with the silhouette as fallback.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    required this.urls,
    this.fit = BoxFit.cover,
    this.fallback = const ProductSilhouette(),
    super.key,
  });

  final ImageUrls? urls;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth.isFinite
            ? box.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = box.maxHeight.isFinite ? box.maxHeight : null;
        return LamsaImage(
          urls: urls,
          width: width,
          height: height,
          fit: fit,
          fallback: fallback,
        );
      },
    );
  }
}

/// Round brand mark: the logo, or the name's first letter on the brand's
/// deterministic color when there is no logo (or it fails to load).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    required this.id,
    required this.name,
    required this.logo,
    this.size = 58,
    super.key,
  });

  final int id;
  final String name;
  final ImageUrls? logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: brandColor(id),
      child: Text(
        monogram(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: logo == null
            ? letter
            : LamsaImage(
                urls: logo,
                width: size,
                height: size,
                fit: BoxFit.contain,
                fallback: letter,
              ),
      ),
    );
  }
}
