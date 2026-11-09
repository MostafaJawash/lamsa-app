import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/network/app_env.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';

/// Backend image at the right WebP size for its on-screen width.
class LamsaImage extends StatelessWidget {
  const LamsaImage({
    required this.urls,
    required this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final ImageUrls? urls;
  final double width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final url = urls?.pick(width, devicePixelRatio: dpr);
    final placeholder = ColoredBox(color: context.lamsa.surface2);
    if (url == null) {
      return SizedBox(width: width, height: height, child: placeholder);
    }
    return CachedNetworkImage(
      imageUrl: AppEnv.resolveMediaUrl(url),
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
