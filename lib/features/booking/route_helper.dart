import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches route geometry between two points from OSRM and returns polyline points.
Future<List<LatLng>> getRoutePoints({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  String osrmBaseUrl = 'https://router.project-osrm.org',
}) async {
  final url = '$osrmBaseUrl/route/v1/driving/'
      '${originLng.toStringAsFixed(5)},${originLat.toStringAsFixed(5)};'
      '${destLng.toStringAsFixed(5)},${destLat.toStringAsFixed(5)}'
      '?overview=full&geometries=polyline';
  try {
    final res = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout'),
    );
    if (res.statusCode != 200) return _fallbackPoints(originLat, originLng, destLat, destLng);
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (data?['code'] != 'Ok') return _fallbackPoints(originLat, originLng, destLat, destLng);
    final routes = data!['routes'] as List<dynamic>?;
    final geometry = (routes != null && routes.isNotEmpty && routes.first is Map)
        ? (routes.first as Map<String, dynamic>)['geometry'] as String?
        : null;
    if (geometry == null || geometry.isEmpty) return _fallbackPoints(originLat, originLng, destLat, destLng);
    return _decodePolyline(geometry);
  } catch (_) {
    return _fallbackPoints(originLat, originLng, destLat, destLng);
  }
}

List<LatLng> _fallbackPoints(double lat1, double lng1, double lat2, double lng2) {
  return [LatLng(lat1, lng1), LatLng(lat2, lng2)];
}

/// Decodes Google/OSRM encoded polyline.
List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  int lat = 0, lng = 0;
  while (index < encoded.length) {
    int b, shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
