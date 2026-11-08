import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_exception.dart';

/// A place found by the address search.
class PlaceResult {
  final String name;
  final String details;
  final LatLng point;
  const PlaceResult({
    required this.name,
    required this.details,
    required this.point,
  });
}

/// Address search and reverse geocoding with OpenStreetMap's Nominatim API,
/// plus the device's current position. Needs an internet connection (the
/// rest of the app stays offline).
///
/// Nominatim usage policy: identify the app with a User-Agent and stay under
/// one request per second (callers debounce).
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'AutoRent/1.0 (ESPRIT student project, Flutter)',
    'Accept-Language': 'fr',
  };
  static const _timeout = Duration(seconds: 10);

  /// Searches places in Tunisia matching [query].
  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      'countrycodes': 'tn',
    });
    final list = await _getJson(uri) as List;
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        PlaceResult(
          name: _shortName(m),
          details: m['display_name'] as String? ?? '',
          point: LatLng(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        ),
    ];
  }

  /// Short human address for [point] ("Avenue Habib Bourguiba, Tunis"),
  /// or null when nothing is found.
  Future<String?> reverse(LatLng point) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'jsonv2',
      'zoom': '17',
      'addressdetails': '1',
    });
    final m = await _getJson(uri) as Map<String, dynamic>;
    if (m['error'] != null) return null;
    return _shortName(m);
  }

  Future<Object?> _getJson(Uri uri) async {
    try {
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw AppException(
          'Service de carte indisponible (${res.statusCode}).',
        );
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Recherche impossible : vérifiez votre connexion internet.',
      );
    }
  }

  /// Builds "road / place, city" from Nominatim's address parts.
  static String _shortName(Map<String, dynamic> m) {
    final a = (m['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return null;
    }

    final main = (m['name'] as String?)?.trim().isNotEmpty == true
        ? m['name'] as String
        : pick(['road', 'pedestrian', 'neighbourhood', 'suburb', 'hamlet']);
    final city = pick([
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state',
    ]);
    final parts = [main, city].whereType<String>().toSet().toList();
    if (parts.isNotEmpty) return parts.join(', ');
    final display = m['display_name'] as String? ?? '';
    return display.split(',').take(2).join(',').trim();
  }

  /// Current GPS position, asking for the permission when needed.
  static Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException(
        'La localisation est désactivée sur l\'appareil. Activez-la puis réessayez.',
      );
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const AppException('Autorisation de localisation refusée.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const AppException(
        'Localisation bloquée : autorisez-la dans les paramètres de l\'application.',
      );
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
      throw const AppException(
        'Position introuvable pour le moment. Réessayez.',
      );
    }
  }
}
