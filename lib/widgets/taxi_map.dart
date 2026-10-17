import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/location.dart';
import '../core/theme.dart';

LatLng ll(GeoPos p) => LatLng(p.lat, p.lng);
GeoPos gp(LatLng p) => GeoPos(p.latitude, p.longitude);

const kTaxiYellow = Color(0xFFF5C518);

/// Mapa do TaxiPet (OpenStreetMap, grátis e sem chave).
class TaxiMap extends StatelessWidget {
  /// Nas prints automáticas não há internet: desenha um fundo de ruas falso.
  static bool testMode = false;

  final MapController? controller;
  final GeoPos center;
  final double zoom;
  final GeoPos? pickup;
  final GeoPos? dest;
  final GeoPos? driver;
  final List<GeoPos> route;
  final void Function(GeoPos center, bool byUser)? onMoved;
  final VoidCallback? onReady;

  const TaxiMap({
    super.key,
    this.controller,
    required this.center,
    this.zoom = 15,
    this.pickup,
    this.dest,
    this.driver,
    this.route = const [],
    this.onMoved,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.dark;
    return Stack(children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: ll(center),
          initialZoom: zoom,
          minZoom: 4,
          maxZoom: 19,
          backgroundColor: dark ? const Color(0xFF1B2226) : const Color(0xFFE9ECE5),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: onReady,
          onPositionChanged: onMoved == null ? null : (camera, hasGesture) => onMoved!(gp(camera.center), hasGesture),
        ),
        children: [
          if (testMode)
            const SizedBox.expand(child: CustomPaint(painter: _FakeStreets()))
          else
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.meupet.app',
              maxNativeZoom: 19,
              tileBuilder: dark ? darkModeTileBuilder : null,
            ),
          if (route.length > 1)
            PolylineLayer(polylines: [
              Polyline(
                points: route.map(ll).toList(),
                strokeWidth: 5,
                color: AppColors.teal,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ]),
          MarkerLayer(markers: [
            if (pickup != null) Marker(point: ll(pickup!), width: 30, height: 30, child: const PickupDot()),
            if (dest != null)
              Marker(
                point: ll(dest!),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.place_rounded, color: AppColors.red, size: 44, shadows: [Shadow(color: Colors.black26, blurRadius: 4)]),
              ),
            if (driver != null) Marker(point: ll(driver!), width: 42, height: 42, child: const CarDot()),
          ]),
        ],
      ),
      Positioned(
        left: 6,
        bottom: 4,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
            child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9.5, color: AppColors.text2)),
          ),
        ),
      ),
    ]);
  }
}

/// Bolinha azul da partida.
class PickupDot extends StatelessWidget {
  final double size;
  const PickupDot({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.teal,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))],
        ),
      ),
    );
  }
}

/// Carrinho amarelo do motorista.
class CarDot extends StatelessWidget {
  const CarDot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kTaxiYellow,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF3E4446), size: 22),
    );
  }
}

/// Pino do centro do mapa (partida azul ou destino vermelho).
class CenterPin extends StatelessWidget {
  final bool destination;
  const CenterPin({super.key, this.destination = false});
  @override
  Widget build(BuildContext context) {
    final c = destination ? AppColors.red : AppColors.teal;
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: Icon(destination ? Icons.flag_rounded : Icons.pets_rounded, color: Colors.white, size: 18),
            ),
            Container(width: 3, height: 14, color: c),
            Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      ),
    );
  }
}

class _FakeStreets extends CustomPainter {
  const _FakeStreets();
  @override
  void paint(Canvas canvas, Size s) {
    final dark = AppColors.dark;
    canvas.drawRect(Offset.zero & s, Paint()..color = dark ? const Color(0xFF1F272B) : const Color(0xFFEDEFEA));
    final block = Paint()..color = dark ? const Color(0xFF263035) : const Color(0xFFE2E6DE);
    final park = Paint()..color = dark ? const Color(0xFF1E3326) : const Color(0xFFCFE8C6);
    final road = Paint()
      ..color = dark ? const Color(0xFF3A464C) : Colors.white
      ..strokeWidth = 10;
    final avenue = Paint()
      ..color = dark ? const Color(0xFF55574A) : const Color(0xFFFFE9A8)
      ..strokeWidth = 16;
    for (var y = 0.0; y < s.height; y += 90) {
      for (var x = 0.0; x < s.width; x += 110) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 8, y + 8, 94, 74), const Radius.circular(4)), block);
      }
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.55, s.height * 0.12, 180, 120), const Radius.circular(18)), park);
    for (var y = 0.0; y < s.height; y += 90) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), road);
    }
    for (var x = 0.0; x < s.width; x += 110) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), road);
    }
    canvas.drawLine(Offset(0, s.height * 0.78), Offset(s.width, s.height * 0.30), avenue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
