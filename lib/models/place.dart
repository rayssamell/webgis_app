import 'package:latlong2/latlong.dart';

enum PlaceCategory { restaurant, bar, snack }

extension PlaceCategoryUI on PlaceCategory {
  String get label => switch (this) {
        PlaceCategory.restaurant => 'Restaurante',
        PlaceCategory.bar => 'Bar',
        PlaceCategory.snack => 'Lanchonete',
      };

  String get amenityValue => switch (this) {
        PlaceCategory.restaurant => 'restaurant',
        PlaceCategory.bar => 'bar',
        PlaceCategory.snack => 'fast_food', // aproximação para “lanchonete”
      };
}

class Place {
  final String id;
  final String name;
  final PlaceCategory category;
  final LatLng position;
  final Map<String, dynamic> tags;
  final double distanceMeters;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.tags,
    required this.distanceMeters,
  });
}
