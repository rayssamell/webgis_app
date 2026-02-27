import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:webgis_app/models/place.dart';
import 'package:webgis_app/services/overpass_service.dart';
import 'package:webgis_app/views/components/place_detail.dart';


class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const LatLng campusCenter = LatLng(-19.922862, -43.992595);
  static const double radiusMeters = 1000;

  final _mapController = MapController();
  final _overpass = OverpassService();

  bool _satellite = false;
  bool _loading = false;

  LatLng? _userPos;
  LatLng _searchCenter = campusCenter;

  final Set<PlaceCategory> _filters = {
    PlaceCategory.restaurant,
    PlaceCategory.bar,
    PlaceCategory.snack,
  };

  List<Place> _places = [];
  Place? _selected;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    try {
      final data = await _overpass.fetchPlaces(
        center: _searchCenter,
        radiusMeters: radiusMeters,
        categories: _filters,
        userPositionForDistance: _userPos,
      );
      setState(() {
        _places = data;
        _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar locais: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _locateMe() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geolocalização desativada no dispositivo/navegador.')),
        );
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final user = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _userPos = user;
        _searchCenter = user;
      });

      _mapController.move(user, 16);
      await _loadPlaces();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao obter localização: $e')),
      );
    }
  }

  void _toggleBasemap() {
    setState(() => _satellite = !_satellite);
  }

  void _toggleFilter(PlaceCategory cat, bool selected) {
    setState(() {
      if (selected) {
        _filters.add(cat);
      } else {
        _filters.remove(cat);
      }
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadPlaces);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: _searchCenter,
        width: 40,
        height: 40,
        child: const Icon(Icons.school, size: 34, color: Colors.indigo),
      ),

      if (_userPos != null)
        Marker(
          point: _userPos!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.my_location, size: 18, color: Colors.blue),
            ),
          ),
        ),
      ..._places.map((p) {
        final isSel = _selected?.id == p.id;
        return Marker(
          point: p.position,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => setState(() => _selected = p),
            child: Icon(
              _iconFor(p.category),
              size: isSel ? 40 : 34,
              color: isSel ? Colors.deepOrange : Colors.redAccent,
            ),
          ),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onde comer perto do campus (BH)'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: campusCenter,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (pos, hasGesture) {
                if (!hasGesture) return;
                final c = pos.center;
                _searchCenter = c; 
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _satellite
                    // Satélite (Esri). 
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    // Ruas (OSM). 
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.edu.webgis.campusfood',
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () => _openAttributionDialog(context),
                  ),
                  if (_satellite)
                    const TextSourceAttribution('Imagery © Esri'),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Painel superior (controles)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(PlaceCategory.restaurant.label),
                      selected: _filters.contains(PlaceCategory.restaurant),
                      onSelected: (v) => _toggleFilter(PlaceCategory.restaurant, v),
                    ),
                    FilterChip(
                      label: Text(PlaceCategory.bar.label),
                      selected: _filters.contains(PlaceCategory.bar),
                      onSelected: (v) => _toggleFilter(PlaceCategory.bar, v),
                    ),
                    FilterChip(
                      label: Text(PlaceCategory.snack.label),
                      selected: _filters.contains(PlaceCategory.snack),
                      onSelected: (v) => _toggleFilter(PlaceCategory.snack, v),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _toggleBasemap,
                      icon: Icon(_satellite ? Icons.map : Icons.satellite_alt),
                      label: Text(_satellite ? 'Ruas' : 'Satélite'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _locateMe,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Minha localização'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _loadPlaces,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recarregar aqui'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    if (_selected != null) {
      return PlaceDetailsSheet(
        place: _selected!,
        onClose: () => setState(() => _selected = null),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.all(12),
      child: Card(
        elevation: 8,
        child: Column(
          children: [
            ListTile(
              title: Text('Resultados (${_places.length}) • raio ${radiusMeters.toInt()} m'),
              subtitle: Text(_userPos == null
                  ? 'Ordenado pela distância ao centro de busca'
                  : 'Ordenado pela sua localização'),
              trailing: IconButton(
                tooltip: 'Centralizar no campus',
                onPressed: () {
                  setState(() => _searchCenter = campusCenter);
                  _mapController.move(campusCenter, 15);
                  _loadPlaces();
                },
                icon: const Icon(Icons.school),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _places.isEmpty && !_loading
                  ? const Center(child: Text('Nenhum local encontrado com esses filtros.'))
                  : ListView.separated(
                      itemCount: _places.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _places[i];
                        return ListTile(
                          leading: Icon(_iconFor(p.category), color: Colors.redAccent),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${p.category.label} • ${(p.distanceMeters / 1000).toStringAsFixed(2)} km'),
                          onTap: () {
                            setState(() => _selected = p);
                            _mapController.move(p.position, 17);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PlaceCategory c) {
    return switch (c) {
      PlaceCategory.restaurant => Icons.restaurant,
      PlaceCategory.bar => Icons.local_bar,
      PlaceCategory.snack => Icons.fastfood,
    };
  }

  void _openAttributionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atribuição de dados'),
        content: const Text(
          'Este protótipo usa dados e/ou tiles do OpenStreetMap.\n'
          'Lembre-se de manter atribuição visível conforme a política de tiles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
