import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lamsa_app/core/platform/external_links.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap's standard tile layer, like lamsa-web (no Google Maps, no API
/// key). Its tile usage policy requires an identifying user agent and a
/// visible credit; both are set below.
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const osmUserAgent = 'com.lamsa.app';
const osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// Why a "use my location" request did not produce a point.
enum LocateFailure { denied, unavailable }

/// Result of asking for the current position.
final class LocateResult {
  const LocateResult.found(LatLngPoint this.point) : failure = null;

  const LocateResult.failed(LocateFailure this.failure) : point = null;

  final LatLngPoint? point;
  final LocateFailure? failure;
}

/// Source of the device's current position (replaceable in tests).
abstract interface class CurrentLocator {
  Future<LocateResult> locate();
}

/// `geolocator`: asks for the permission when needed, then reads the position.
final class GeolocatorLocator implements CurrentLocator {
  const GeolocatorLocator();

  @override
  Future<LocateResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocateResult.failed(LocateFailure.unavailable);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocateResult.failed(LocateFailure.denied);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocateResult.found(LatLngPoint(p.latitude, p.longitude));
    } on Object {
      return const LocateResult.failed(LocateFailure.unavailable);
    }
  }
}

/// Where the app asks for the device position; a field so tests can replace
/// it (like `ExternalLinks.opener`).
abstract final class DeviceLocation {
  static CurrentLocator locator = const GeolocatorLocator();
}

/// The optional map location of an address. Same behavior as lamsa-web:
/// tap the map to place the pin (tap again to move it), "استخدم موقعي الحالي",
/// "إزالة الموقع", points outside Syria are refused, and the map opens on the
/// chosen governorate. The form's other fields work without it.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    required this.governorate,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.locator,
    super.key,
  });

  final String governorate;
  final String latitude;
  final String longitude;

  /// The new pin, or null when the location was removed.
  final ValueChanged<LatLngPoint?> onChanged;
  final CurrentLocator? locator;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _controller = MapController();
  String? _status;
  bool _statusIsError = false;
  bool _locating = false;
  bool _tilesFailed = false;

  LatLngPoint? get _pin => parseLocation(widget.latitude, widget.longitude);

  void _say(String text, {bool error = false}) => setState(() {
        _status = text;
        _statusIsError = error;
      });

  void _pick(LatLngPoint point, String message) {
    if (!isWithinSyria(point.lat, point.lng)) {
      _say(Strings.mapOutside, error: true);
      return;
    }
    // At most 6 decimals, as the backend wants.
    widget.onChanged(
      LatLngPoint(
        double.parse(formatCoordinate(point.lat)),
        double.parse(formatCoordinate(point.lng)),
      ),
    );
    _say(message);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    _say(Strings.mapLocating);
    final r = await (widget.locator ?? DeviceLocation.locator).locate();
    if (!mounted) return;
    setState(() => _locating = false);
    final point = r.point;
    if (point != null) {
      _pick(point, Strings.mapLocated);
      if (isWithinSyria(point.lat, point.lng)) {
        _controller.move(LatLng(point.lat, point.lng), 15);
      }
    } else {
      _say(
        r.failure == LocateFailure.denied
            ? Strings.mapDenied
            : Strings.mapUnavailable,
        error: true,
      );
    }
  }

  void _remove() {
    widget.onChanged(null);
    _say(Strings.mapRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final pin = _pin;
    final center = pin ?? governorateCenter(widget.governorate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(Strings.mapTitle, style: theme.titleSmall),
            const SizedBox(width: Spacing.sm),
            Text(
              Strings.mapOptional,
              style: theme.bodySmall!.copyWith(color: c.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(Strings.mapHelp, style: theme.bodySmall!.copyWith(color: c.muted)),
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: SizedBox(
            height: 240,
            // Maps are always left-to-right, inside the RTL page.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: LatLng(center.lat, center.lng),
                  initialZoom: pin != null ? 15 : 9,
                  onTap: (_, point) => _pick(
                    LatLngPoint(point.latitude, point.longitude),
                    _pin == null ? Strings.mapPlaced : Strings.mapMoved,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: osmTileUrl,
                    userAgentPackageName: osmUserAgent,
                    maxZoom: 19,
                    errorTileCallback: (_, _, _) {
                      if (!_tilesFailed && mounted) {
                        setState(() => _tilesFailed = true);
                      }
                    },
                  ),
                  if (pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(pin.lat, pin.lng),
                          width: 40,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on, size: 44, color: c.accent),
                        ),
                      ],
                    ),
                  const _MapCredit(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text(Strings.mapUseMyLocation),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
            OutlinedButton(
              onPressed: pin == null ? null : _remove,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text(Strings.mapRemoveLocation),
            ),
            if (pin != null)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${formatCoordinate(pin.lat)}, ${formatCoordinate(pin.lng)}',
                  style: theme.bodySmall!.copyWith(color: c.muted),
                ),
              ),
          ],
        ),
        if (_tilesFailed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              Strings.mapTilesFailed,
              style: theme.bodySmall!.copyWith(color: c.danger),
            ),
          ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _status!,
              style: theme.bodySmall!.copyWith(
                color: _statusIsError ? c.danger : c.muted,
              ),
            ),
          ),
      ],
    );
  }
}

/// The credit OpenStreetMap's tile policy asks for, linking to its copyright
/// page.
class _MapCredit extends StatelessWidget {
  const _MapCredit();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: () => ExternalLinks.open(Uri.parse(osmCopyrightUrl)),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: const Text(
            Strings.mapAttribution,
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
