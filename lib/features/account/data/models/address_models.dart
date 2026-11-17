import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address_models.g.dart';

/// One of the 14 Syrian governorates, as `GET /governorates` lists them (the
/// Arabic names come from the backend).
@JsonSerializable(fieldRename: FieldRename.snake)
final class Governorate extends Equatable {
  const Governorate({required this.code, required this.name});

  factory Governorate.fromJson(Map<String, dynamic> json) =>
      _$GovernorateFromJson(json);

  final String code;
  final String name;

  Map<String, dynamic> toJson() => _$GovernorateToJson(this);

  @override
  List<Object?> get props => [code, name];
}

/// A saved delivery address (`/users/me/addresses`).
@JsonSerializable(fieldRename: FieldRename.snake)
final class Address extends Equatable {
  const Address({
    required this.id,
    required this.governorate,
    required this.details,
    this.label,
    this.area,
    this.latitude,
    this.longitude,
    this.notes,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);

  final int id;
  final String? label;
  final String governorate;
  final String? area;
  final String details;

  /// Decimal strings (at most 6 decimals); both set or both null.
  final String? latitude;
  final String? longitude;
  final String? notes;
  final bool isDefault;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => _$AddressToJson(this);

  @override
  List<Object?> get props => [
        id,
        label,
        governorate,
        area,
        details,
        latitude,
        longitude,
        notes,
        isDefault,
      ];
}

/// What the address form holds, as typed (the backend trims and counts
/// characters itself; blanks become `null` when sent).
final class AddressDraft extends Equatable {
  const AddressDraft({
    this.label = '',
    this.governorate = '',
    this.area = '',
    this.details = '',
    this.notes = '',
    this.latitude = '',
    this.longitude = '',
    this.isDefault = false,
  });

  factory AddressDraft.from(Address a) => AddressDraft(
        label: a.label ?? '',
        governorate: a.governorate,
        area: a.area ?? '',
        details: a.details,
        notes: a.notes ?? '',
        latitude: a.latitude ?? '',
        longitude: a.longitude ?? '',
        isDefault: a.isDefault,
      );

  final String label;
  final String governorate;
  final String area;
  final String details;
  final String notes;
  final String latitude;
  final String longitude;
  final bool isDefault;

  String? _blank(String v) => v.trim().isEmpty ? null : v.trim();

  /// Body for create and update: every field is sent, so a blank area or notes
  /// or a removed pin clears the stored value (same as lamsa-web).
  Map<String, Object?> toBody({bool includeDefault = false}) => {
        'label': _blank(label),
        'governorate': governorate,
        'area': _blank(area),
        'details': details.trim(),
        'notes': _blank(notes),
        'latitude': _blank(latitude),
        'longitude': _blank(longitude),
        if (includeDefault) 'is_default': isDefault,
      };

  @override
  List<Object?> get props =>
      [label, governorate, area, details, notes, latitude, longitude, isDefault];
}
