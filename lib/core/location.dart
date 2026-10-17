import 'dart:math';

import 'package:geolocator/geolocator.dart';

class GeoPos {
  final double lat;
  final double lng;
  const GeoPos(this.lat, this.lng);
}

/// Localização do aparelho (GPS). Devolve null se o usuário negar ou o GPS
/// estiver desligado; [lastError] explica o motivo.
class LocationService {
  /// Usado nas prints automáticas (não há GPS no teste).
  static GeoPos? Function()? testOverride;
  static String? lastError;

  static Future<GeoPos?> current() async {
    lastError = null;
    if (testOverride != null) return testOverride!();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        lastError = 'A localização do aparelho está desligada.';
        return _last();
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        lastError = 'Permissão de localização negada.';
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      return GeoPos(p.latitude, p.longitude);
    } catch (_) {
      final last = await _last();
      if (last == null) lastError = 'Não foi possível obter a localização.';
      return last;
    }
  }

  static Future<GeoPos?> _last() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : GeoPos(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Distância em linha reta (km).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String fmtKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}
