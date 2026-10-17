import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'location.dart';

/// Um endereço encontrado na busca (ou escolhido no mapa).
class Place {
  final String name;
  final String detail;
  final double lat;
  final double lng;
  const Place(this.name, this.detail, this.lat, this.lng);

  String get label => detail.isEmpty ? name : '$name, $detail';
  GeoPos get pos => GeoPos(lat, lng);
}

/// Rota entre dois pontos (pelas ruas).
class RouteInfo {
  final double km;
  final int minutes;
  final List<GeoPos> points;
  final bool estimated; // true quando não deu para calcular pelas ruas
  const RouteInfo(this.km, this.minutes, this.points, {this.estimated = false});
}

/// Mapas grátis e sem chave: endereços pelo Photon (OpenStreetMap) e rotas
/// pelo OSRM. Na fase de testes isso basta; para lançar com muitos usuários,
/// trocar por um serviço com conta (os dois têm plano grátis).
class GeoService {
  static const _ua = {'User-Agent': 'MeuPet/1.0 (com.meupet.app)'};

  /// Usados nas prints automáticas (sem internet no teste).
  static Future<List<Place>> Function(String q)? testSearch;
  static Future<String?> Function(double lat, double lng)? testReverse;
  static Future<RouteInfo?> Function(GeoPos a, GeoPos b)? testRoute;

  static Future<List<Place>> search(String q, {GeoPos? near}) async {
    q = q.trim();
    if (q.length < 3) return const [];
    if (testSearch != null) return testSearch!(q);
    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': q,
        'limit': '8',
        if (near != null) 'lat': near.lat.toString(),
        if (near != null) 'lon': near.lng.toString(),
      });
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final feats = (jsonDecode(r.body)['features'] as List?) ?? const [];
      final out = <Place>[];
      for (final f in feats) {
        final p = _fromFeature(f);
        if (p != null && !out.any((o) => o.label == p.label)) out.add(p);
      }
      // Brasil primeiro (o Photon busca no mundo todo).
      out.sort((a, b) {
        final ab = (a.detail.contains('Brasil') ? 0 : 1) - (b.detail.contains('Brasil') ? 0 : 1);
        if (ab != 0 || near == null) return ab;
        return distanceKm(near.lat, near.lng, a.lat, a.lng).compareTo(distanceKm(near.lat, near.lng, b.lat, b.lng));
      });
      return out.map((p) => Place(p.name, p.detail.replaceAll(', Brasil', ''), p.lat, p.lng)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Endereço aproximado de um ponto do mapa.
  static Future<String?> reverse(double lat, double lng) async {
    if (testReverse != null) return testReverse!(lat, lng);
    try {
      final uri = Uri.https('photon.komoot.io', '/reverse', {'lat': '$lat', 'lon': '$lng'});
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final feats = (jsonDecode(r.body)['features'] as List?) ?? const [];
      if (feats.isEmpty) return null;
      return _fromFeature(feats.first)?.label.replaceAll(', Brasil', '');
    } catch (_) {
      return null;
    }
  }

  static Place? _fromFeature(dynamic f) {
    try {
      final c = f['geometry']['coordinates'] as List;
      final p = (f['properties'] as Map?) ?? const {};
      String s(String k) => (p[k] ?? '').toString().trim();
      final street = s('street');
      final number = s('housenumber');
      final name = s('name');
      final first = name.isNotEmpty
          ? name
          : street.isNotEmpty
              ? (number.isEmpty ? street : '$street, $number')
              : s('city');
      if (first.isEmpty) return null;
      final parts = <String>[
        if (name.isNotEmpty && street.isNotEmpty) number.isEmpty ? street : '$street, $number',
        if (s('district').isNotEmpty) s('district') else if (s('locality').isNotEmpty) s('locality'),
        if (s('city').isNotEmpty && s('city') != first) s('city'),
        if (s('state').isNotEmpty) _uf(s('state')),
        if (s('country') == 'Brasil' || s('countrycode') == 'BR') 'Brasil' else if (s('country').isNotEmpty) s('country'),
      ];
      return Place(first, parts.join(', '), (c[1] as num).toDouble(), (c[0] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  static const _ufs = {
    'Acre': 'AC', 'Alagoas': 'AL', 'Amapá': 'AP', 'Amazonas': 'AM', 'Bahia': 'BA', 'Ceará': 'CE', 'Distrito Federal': 'DF',
    'Espírito Santo': 'ES', 'Goiás': 'GO', 'Maranhão': 'MA', 'Mato Grosso': 'MT', 'Mato Grosso do Sul': 'MS',
    'Minas Gerais': 'MG', 'Pará': 'PA', 'Paraíba': 'PB', 'Paraná': 'PR', 'Pernambuco': 'PE', 'Piauí': 'PI',
    'Rio de Janeiro': 'RJ', 'Rio Grande do Norte': 'RN', 'Rio Grande do Sul': 'RS', 'Rondônia': 'RO', 'Roraima': 'RR',
    'Santa Catarina': 'SC', 'São Paulo': 'SP', 'Sergipe': 'SE', 'Tocantins': 'TO',
  };
  static String _uf(String state) => _ufs[state] ?? state;

  /// Rota de carro. Sem internet, estima pela linha reta.
  static Future<RouteInfo> route(GeoPos a, GeoPos b) async {
    if (testRoute != null) {
      final r = await testRoute!(a, b);
      if (r != null) return r;
    }
    try {
      final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${a.lng},${a.lat};${b.lng},${b.lat}?overview=full&geometries=geojson');
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final routes = (jsonDecode(r.body)['routes'] as List?) ?? const [];
        if (routes.isNotEmpty) {
          final rt = routes.first;
          final pts = [
            for (final c in (rt['geometry']['coordinates'] as List)) GeoPos((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ];
          return RouteInfo((rt['distance'] as num) / 1000, max(1, ((rt['duration'] as num) / 60).round()), pts);
        }
      }
    } catch (_) {}
    return straight(a, b);
  }

  /// Estimativa simples: 30% a mais que a linha reta, a 30 km/h.
  static RouteInfo straight(GeoPos a, GeoPos b) {
    final km = distanceKm(a.lat, a.lng, b.lat, b.lng) * 1.3;
    return RouteInfo(km, max(1, (km / 30 * 60).round()), [a, b], estimated: true);
  }
}
