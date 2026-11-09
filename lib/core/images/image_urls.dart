import 'package:equatable/equatable.dart';

enum ImageSize { thumb, medium, large }

/// The backend's `{thumb, medium, large}` WebP object (300 / 800 / 1600 px).
final class ImageUrls extends Equatable {
  const ImageUrls({this.thumb, this.medium, this.large});

  static const thumbWidth = 300;
  static const mediumWidth = 800;

  static ImageUrls? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final urls = ImageUrls(
      thumb: json['thumb'] as String?,
      medium: json['medium'] as String?,
      large: json['large'] as String?,
    );
    return urls.isEmpty ? null : urls;
  }

  final String? thumb;
  final String? medium;
  final String? large;

  bool get isEmpty => thumb == null && medium == null && large == null;

  /// Size class for [physicalWidth] pixels, same thresholds as lamsa-web.
  static ImageSize sizeFor(double physicalWidth) {
    if (physicalWidth <= thumbWidth) return ImageSize.thumb;
    if (physicalWidth <= mediumWidth) return ImageSize.medium;
    return ImageSize.large;
  }

  /// Best URL for a widget [displayWidth] in logical px on a screen with
  /// [devicePixelRatio]; falls back to the nearest available size.
  String? pick(double displayWidth, {double devicePixelRatio = 1}) {
    final wanted = sizeFor(displayWidth * devicePixelRatio);
    final order = switch (wanted) {
      ImageSize.thumb => [thumb, medium, large],
      ImageSize.medium => [medium, large, thumb],
      ImageSize.large => [large, medium, thumb],
    };
    for (final url in order) {
      if (url != null) return url;
    }
    return null;
  }

  @override
  List<Object?> get props => [thumb, medium, large];
}
