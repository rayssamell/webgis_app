import 'package:flutter/material.dart';
import 'package:webgis_app/models/place.dart';

class PlaceDetailsSheet extends StatelessWidget {
  final Place place;
  final VoidCallback onClose;

  const PlaceDetailsSheet({
    super.key,
    required this.place,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final opening = (place.tags['opening_hours'] as String?)?.trim();
    final cuisine = (place.tags['cuisine'] as String?)?.trim();
    final addrStreet = (place.tags['addr:street'] as String?)?.trim();
    final addrNumber = (place.tags['addr:housenumber'] as String?)?.trim();

    String? address;
    if (addrStreet != null && addrStreet.isNotEmpty) {
      address = '$addrStreet${addrNumber != null && addrNumber.isNotEmpty ? ', $addrNumber' : ''}';
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puxador visual (Drag handle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${place.category.label} • ${(place.distanceMeters / 1000).toStringAsFixed(2)} km',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Fechar',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (address != null) _buildInfoRow(context, Icons.location_on_outlined, address),
                if (cuisine != null && cuisine.isNotEmpty) _buildInfoRow(context, Icons.restaurant_menu, cuisine),
                if (opening != null && opening.isNotEmpty) _buildInfoRow(context, Icons.access_time, opening),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.list),
                    label: const Text('Voltar à lista'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}