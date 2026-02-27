import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:webgis_app/models/place.dart';

class OverpassService {
  static const String overpassInterpreterUrl =
      'https://overpass-api.de/api/interpreter';

  final Distance _distance = const Distance();

  Future<List<Place>> fetchPlaces({
    required LatLng center,
    required double radiusMeters,
    required Set<PlaceCategory> categories,
    LatLng? userPositionForDistance,
  }) async {
    final query = _buildQuery(center, radiusMeters, categories);

    final resp = await http.post(
      Uri.parse(overpassInterpreterUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: 'data=${Uri.encodeQueryComponent(query)}',
    );

    if (resp.statusCode != 200) {
      throw Exception('Overpass erro ${resp.statusCode}: ${resp.body}');
    }

    final decoded = json.decode(resp.body) as Map<String, dynamic>;
    final elements = (decoded['elements'] as List).cast<Map<String, dynamic>>();

    final origin = userPositionForDistance ?? center;
    final places = <Place>[];

    for (final el in elements) {
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final String? amenity = tags['amenity'] as String?;
      final category = _categoryFromAmenity(amenity);
      if (category == null || !categories.contains(category)) continue;

      LatLng? pos;
      if (el['type'] == 'node') {
        final lat = (el['lat'] as num?)?.toDouble();
        final lon = (el['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) pos = LatLng(lat, lon);
      } else {
        final centerObj = (el['center'] as Map?)?.cast<String, dynamic>();
        final lat = (centerObj?['lat'] as num?)?.toDouble();
        final lon = (centerObj?['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) pos = LatLng(lat, lon);
      }
      if (pos == null) continue;

      final dist = _distance(origin, pos).toDouble();

      places.add(Place(
        id: '${el['type']}/${el['id']}',
        name: name,
        category: category,
        position: pos,
        tags: tags,
        distanceMeters: dist,
      ));
    }

    places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return places;
  }

  PlaceCategory? _categoryFromAmenity(String? amenity) {
    return switch (amenity) {
      'restaurant' => PlaceCategory.restaurant,
      'bar' => PlaceCategory.bar,
      'fast_food' => PlaceCategory.snack,
      'cafe' => PlaceCategory.snack,
      _ => null,
    };
  }

  String _buildQuery(LatLng center, double radius, Set<PlaceCategory> cats) {
    final lat = center.latitude;
    final lon = center.longitude;
    final r = radius.round();

    final wantSnack = cats.contains(PlaceCategory.snack);

    final parts = <String>[];
    if (cats.contains(PlaceCategory.restaurant)) {
      parts.add(_amenityBlock('restaurant', r, lat, lon));
    }
    if (cats.contains(PlaceCategory.bar)) {
      parts.add(_amenityBlock('bar', r, lat, lon));
    }
    if (wantSnack) {
      parts.add(_amenityBlock('fast_food', r, lat, lon));
      parts.add(_amenityBlock('cafe', r, lat, lon));
    }

    return '''
      [out:json][timeout:25];
      (
      ${parts.join('\n')}
      );
      out center tags;
      ''';
  }

  String _amenityBlock(String amenity, int r, double lat, double lon) {
    return '''
      node["amenity"="$amenity"](around:$r,$lat,$lon);
      way["amenity"="$amenity"](around:$r,$lat,$lon);
      relation["amenity"="$amenity"](around:$r,$lat,$lon);
      ''';
  }
}
