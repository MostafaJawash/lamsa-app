// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Governorate _$GovernorateFromJson(Map<String, dynamic> json) =>
    Governorate(code: json['code'] as String, name: json['name'] as String);

Map<String, dynamic> _$GovernorateToJson(Governorate instance) =>
    <String, dynamic>{'code': instance.code, 'name': instance.name};

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
  id: (json['id'] as num).toInt(),
  governorate: json['governorate'] as String,
  details: json['details'] as String,
  label: json['label'] as String?,
  area: json['area'] as String?,
  latitude: json['latitude'] as String?,
  longitude: json['longitude'] as String?,
  notes: json['notes'] as String?,
  isDefault: json['is_default'] as bool? ?? false,
);

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'governorate': instance.governorate,
  'area': instance.area,
  'details': instance.details,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'notes': instance.notes,
  'is_default': instance.isDefault,
};
