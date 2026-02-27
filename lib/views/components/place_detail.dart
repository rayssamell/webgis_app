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
      address = addrStreet + (addrNumber != null && addrNumber.isNotEmpty ? ', $addrNumber' : '');
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.all(12),
      child: Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${place.category.label} • ${(place.distanceMeters / 1000).toStringAsFixed(2)} km'),
              const SizedBox(height: 12),
              if (address != null) Text('Endereço: $address'),
              if (cuisine != null && cuisine.isNotEmpty) Text('Cozinha: $cuisine'),
              if (opening != null && opening.isNotEmpty) Text('Horário: $opening'),
              const Spacer(),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onClose,
                    icon: const Icon(Icons.place),
                    label: const Text('Voltar à lista'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
