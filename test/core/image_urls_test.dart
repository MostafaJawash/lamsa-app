import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/images/image_urls.dart';

void main() {
  const urls = ImageUrls(thumb: 't', medium: 'm', large: 'l');

  test('size thresholds match lamsa-web (300 / 800 / 1600)', () {
    expect(ImageUrls.sizeFor(300), ImageSize.thumb);
    expect(ImageUrls.sizeFor(301), ImageSize.medium);
    expect(ImageUrls.sizeFor(800), ImageSize.medium);
    expect(ImageUrls.sizeFor(801), ImageSize.large);
  });

  test('pick accounts for device pixel ratio', () {
    expect(urls.pick(100), 't');
    expect(urls.pick(100, devicePixelRatio: 3), 't');
    expect(urls.pick(200, devicePixelRatio: 3), 'm');
    expect(urls.pick(400, devicePixelRatio: 3), 'l');
  });

  test('falls back to the nearest available size', () {
    expect(const ImageUrls(large: 'l').pick(50), 'l');
    expect(const ImageUrls(thumb: 't').pick(2000), 't');
    expect(const ImageUrls().pick(100), isNull);
  });

  test('fromJson returns null for null or empty', () {
    expect(ImageUrls.fromJson(null), isNull);
    expect(ImageUrls.fromJson(<String, dynamic>{}), isNull);
    expect(ImageUrls.fromJson({'thumb': 'a'}), const ImageUrls(thumb: 'a'));
  });
}
