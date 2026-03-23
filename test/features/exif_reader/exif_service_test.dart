import 'package:flutter_test/flutter_test.dart';

import 'package:oldsun_camera_toolbox/src/features/exif_reader/exif_service.dart';

void main() {
  test('formats GPS coordinates with hemisphere references', () {
    final translated = ExifService.translateAndFormatExifDataForTesting({
      'GPS GPSLatitude': const [
        [30, 1],
        [15, 1],
        [0, 1],
      ],
      'GPS GPSLatitudeRef': 'S',
      'GPS GPSLongitude': const [
        [120, 1],
        [30, 1],
        [0, 1],
      ],
      'GPS GPSLongitudeRef': 'W',
    });

    expect(translated['纬度'], '-30.250000°');
    expect(translated['经度'], '-120.500000°');
  });
}
