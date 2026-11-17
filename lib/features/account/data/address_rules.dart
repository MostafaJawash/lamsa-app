import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';

/// Address rules, mirroring the backend's `AddressCreate` and lamsa-web's
/// `address-validation.ts`: label up to 50, governorate required, area up to
/// 100, details 10..500, notes up to 500, optional coordinates that come as a
/// pair inside Syria. The form validates with these for instant feedback; the
/// backend stays the judge and its Arabic message wins when it rejects
/// something.
abstract final class AddressLimits {
  static const label = 50;
  static const area = 100;
  static const detailsMin = 10;
  static const detailsMax = 500;
  static const notes = 500;
}

enum AddressField { label, governorate, area, details, notes, location, form }

typedef AddressErrors = Map<AddressField, String>;

/// A point on the map.
final class LatLngPoint extends Equatable {
  const LatLngPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

/// The same rough box the backend accepts for an address location (it checks
/// it too).
abstract final class SyriaBounds {
  static const south = 32.3;
  static const north = 37.4;
  static const west = 35.6;
  static const east = 42.4;
}

bool isWithinSyria(double lat, double lng) =>
    lat.isFinite &&
    lng.isFinite &&
    lat >= SyriaBounds.south &&
    lat <= SyriaBounds.north &&
    lng >= SyriaBounds.west &&
    lng <= SyriaBounds.east;

/// A coordinate as the backend wants it: at most 6 decimal places.
String formatCoordinate(double value) {
  final fixed = value.toStringAsFixed(6);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : fixed;
}

/// Approximate centre of each governorate (its capital city), used to open
/// the map where the customer is likely to be. Codes the backend adds later
/// fall back to Damascus.
const governorateCenters = <String, LatLngPoint>{
  'damascus': LatLngPoint(33.5138, 36.2765),
  'rif_dimashq': LatLngPoint(33.5731, 36.4046),
  'aleppo': LatLngPoint(36.2021, 37.1343),
  'homs': LatLngPoint(34.7324, 36.7137),
  'hama': LatLngPoint(35.1318, 36.7578),
  'latakia': LatLngPoint(35.5317, 35.7915),
  'tartus': LatLngPoint(34.889, 35.8866),
  'idlib': LatLngPoint(35.9306, 36.6339),
  'deir_ez_zor': LatLngPoint(35.3359, 40.1408),
  'raqqa': LatLngPoint(35.9528, 39.0079),
  'hasakah': LatLngPoint(36.5024, 40.7477),
  'daraa': LatLngPoint(32.6189, 36.1021),
  'as_suwayda': LatLngPoint(32.709, 36.5663),
  'quneitra': LatLngPoint(33.1257, 35.824),
};

LatLngPoint governorateCenter(String? code) =>
    governorateCenters[code] ?? governorateCenters['damascus']!;

/// Characters as the backend counts them (code points, after trimming).
int textLength(String value) => value.trim().runes.length;

/// The pin as numbers, or null when none is set (or only half of it).
LatLngPoint? parseLocation(String latitude, String longitude) {
  if (latitude.isEmpty || longitude.isEmpty) return null;
  final lat = double.tryParse(latitude);
  final lng = double.tryParse(longitude);
  return lat == null || lng == null ? null : LatLngPoint(lat, lng);
}

/// Field errors in Arabic, empty when valid. [governorateCodes]: the codes
/// the backend lists (null skips the membership check).
AddressErrors validateAddress(
  AddressDraft v, {
  Iterable<String>? governorateCodes,
}) {
  final errors = <AddressField, String>{};
  if (textLength(v.label) > AddressLimits.label) {
    errors[AddressField.label] = Strings.afErrLabelLong(AddressLimits.label);
  }
  if (v.governorate.isEmpty) {
    errors[AddressField.governorate] = Strings.afErrGovernorateRequired;
  } else if (governorateCodes != null && !governorateCodes.contains(v.governorate)) {
    errors[AddressField.governorate] = Strings.afErrGovernorateUnknown;
  }
  if (textLength(v.area) > AddressLimits.area) {
    errors[AddressField.area] = Strings.afErrAreaLong(AddressLimits.area);
  }
  final details = textLength(v.details);
  if (details == 0) {
    errors[AddressField.details] = Strings.afErrDetailsRequired;
  } else if (details < AddressLimits.detailsMin) {
    errors[AddressField.details] = Strings.afErrDetailsShort(AddressLimits.detailsMin);
  } else if (details > AddressLimits.detailsMax) {
    errors[AddressField.details] = Strings.afErrDetailsLong(AddressLimits.detailsMax);
  }
  if (textLength(v.notes) > AddressLimits.notes) {
    errors[AddressField.notes] = Strings.afErrNotesLong(AddressLimits.notes);
  }
  if (v.latitude.isNotEmpty || v.longitude.isNotEmpty) {
    final p = parseLocation(v.latitude, v.longitude);
    if (p == null || !isWithinSyria(p.lat, p.lng)) {
      errors[AddressField.location] = Strings.afErrLocationInvalid;
    }
  }
  return errors;
}

/// Backend address errors to what the form shows. The backend's Arabic
/// message wins (`INVALID_LOCATION`, `ADDRESS_LIMIT_REACHED`, ...); only the
/// per-field marks of a `VALIDATION_ERROR` use our own text (the backend's
/// field messages are English).
AddressErrors mapAddressError(Object error) {
  if (error is! ApiError) return {AddressField.form: messageOf(error)};
  switch (error.code) {
    case 'INVALID_LOCATION':
      return {AddressField.location: error.userMessage};
    case 'VALIDATION_ERROR':
      const fields = {
        'label': AddressField.label,
        'governorate': AddressField.governorate,
        'area': AddressField.area,
        'details': AddressField.details,
        'notes': AddressField.notes,
        'latitude': AddressField.location,
        'longitude': AddressField.location,
      };
      final errors = <AddressField, String>{};
      for (final d in error.validationDetails) {
        final field = fields[d.field.split('.').last];
        if (field != null) errors.putIfAbsent(field, () => Strings.afErrInvalid);
      }
      return errors.isNotEmpty
          ? errors
          : {AddressField.form: error.userMessage};
  }
  return {AddressField.form: error.userMessage};
}

/// Name of a governorate by code (the code itself if unknown).
String governorateName(List<Governorate> list, String code) =>
    list.where((g) => g.code == code).firstOrNull?.name ?? code;

/// The address stored on an order (`shipping_address`, a free-form snapshot
/// the backend keeps as it was when the order was placed). New orders carry
/// `{label, governorate, area, details, latitude, longitude, notes}`; older
/// ones `{city, street, building, notes}`; old pickup orders none. Reads
/// whichever shape is there without guessing and without failing on odd
/// values.
final class AddressSnapshotView extends Equatable {
  const AddressSnapshotView({
    required this.lines,
    this.notes,
    this.location,
  });

  /// Display lines, most important first (label, governorate and area, details).
  final List<String> lines;
  final String? notes;

  /// Only when both coordinates are finite numbers.
  final ({String lat, String lng})? location;

  @override
  List<Object?> get props => [lines, notes, location];
}

String _str(Object? v) {
  if (v is String) return v.trim();
  if (v is num && v.isFinite) return '$v';
  return '';
}

String? _coordinate(Object? v) {
  final t = _str(v);
  return t.isEmpty || double.tryParse(t) == null ? null : t;
}

AddressSnapshotView? describeAddressSnapshot(
  Map<String, dynamic>? snapshot,
  String Function(String code) governorateLabel,
) {
  if (snapshot == null) return null;
  final notes = _str(snapshot['notes']).isEmpty ? null : _str(snapshot['notes']);
  if (snapshot.containsKey('governorate') || snapshot.containsKey('details')) {
    final code = _str(snapshot['governorate']);
    final place = [
      if (code.isNotEmpty) governorateLabel(code),
      _str(snapshot['area']),
    ].where((e) => e.isNotEmpty).join('، ');
    final lat = _coordinate(snapshot['latitude']);
    final lng = _coordinate(snapshot['longitude']);
    return AddressSnapshotView(
      lines: [
        for (final l in [_str(snapshot['label']), place, _str(snapshot['details'])])
          if (l.isNotEmpty) l,
      ],
      notes: notes,
      location: lat != null && lng != null ? (lat: lat, lng: lng) : null,
    );
  }
  // The city / street / building snapshot of orders before the Syria adaptation.
  final lines = [
    for (final k in const ['city', 'street', 'building'])
      if (_str(snapshot[k]).isNotEmpty) _str(snapshot[k]),
  ];
  return lines.isNotEmpty || notes != null
      ? AddressSnapshotView(lines: lines, notes: notes)
      : null;
}

/// An OpenStreetMap link for a point (the website's own map provider).
Uri openStreetMapUri(String lat, String lng) => Uri.parse(
      'https://www.openstreetmap.org/?mlat=${Uri.encodeComponent(lat)}'
      '&mlon=${Uri.encodeComponent(lng)}'
      '#map=16/${Uri.encodeComponent(lat)}/${Uri.encodeComponent(lng)}',
    );
