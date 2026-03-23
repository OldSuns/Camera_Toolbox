import 'package:flutter_test/flutter_test.dart';

import 'package:oldsun_camera_toolbox/src/features/exif_reader/exif_data.dart';

void main() {
  test('gpsCoordinates parses translated latitude and longitude', () {
    final data = ExifData(
      rawData: const {},
      translatedData: const {'纬度': '-30.250000°', '经度': '120.500000°'},
      imagePath: '/tmp/sample.jpg',
      hasExif: true,
    );

    expect(data.hasGpsInfo, isTrue);
    expect(data.gpsCoordinates, isNotNull);
    expect(data.gpsCoordinates!['latitude'], -30.25);
    expect(data.gpsCoordinates!['longitude'], 120.5);
  });
}
