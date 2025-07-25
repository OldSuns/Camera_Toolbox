class CameraData {
  final String brand;
  final String model;
  final String year;
  final String sensorResolution;
  final String cropFactor;
  final String sensorType;
  final String dimensions;
  final String weight;
  final String effectiveMegapixels;
  final String maxVideoResolution;
  final String iso;
  final String storageTypes;
  final String battery;
  final String exposureCompensation;
  final String usb;
  final String maxImageResolution;
  final String maxShutterSpeed;
  final String sensorSize;
  final String opticalZoom;
  final String metering;
  final String viewfinder;
  final String screenResolution;

  CameraData({
    required this.brand,
    required this.model,
    required this.year,
    required this.sensorResolution,
    required this.cropFactor,
    required this.sensorType,
    required this.dimensions,
    required this.weight,
    required this.effectiveMegapixels,
    required this.maxVideoResolution,
    required this.iso,
    required this.storageTypes,
    required this.battery,
    required this.exposureCompensation,
    required this.usb,
    required this.maxImageResolution,
    required this.maxShutterSpeed,
    required this.sensorSize,
    required this.opticalZoom,
    required this.metering,
    required this.viewfinder,
    required this.screenResolution,
  });

  factory CameraData.fromMap(Map<String, dynamic> map) {
    return CameraData(
      brand: map['Brand'] ?? '',
      model: map['Model'] ?? '',
      year: map['Year'] ?? '',
      sensorResolution: map['Sensor resolution'] ?? '',
      cropFactor: map['Crop factor'] ?? '',
      sensorType: map['Sensor type'] ?? '',
      dimensions: map['Dimensions'] ?? '',
      weight: map['Weight'] ?? '',
      effectiveMegapixels: map['Effective megapixels'] ?? '',
      maxVideoResolution: map['Max. video resolution'] ?? '',
      iso: map['ISO'] ?? '',
      storageTypes: map['Storage types'] ?? '',
      battery: map['Battery'] ?? '',
      exposureCompensation: map['Exposure Compensation'] ?? '',
      usb: map['USB'] ?? '',
      maxImageResolution: map['Max. image resolution'] ?? '',
      maxShutterSpeed: map['Max. shutter speed'] ?? '',
      sensorSize: map['Sensor size'] ?? '',
      opticalZoom: map['Optical zoom'] ?? '',
      metering: map['Metering'] ?? '',
      viewfinder: map['Viewfinder'] ?? '',
      screenResolution: map['Screen resolution'] ?? '',
    );
  }

  // Note: copyWith, toMap, toJson, toString, ==, hashCode should be updated
  // in a real application to include the new fields for full functionality.
}
