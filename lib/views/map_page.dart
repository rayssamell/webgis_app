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
    _mapController.dispose();
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
      
      String msg = 'Erro ao buscar locais: $e';
      if (e.toString().contains('erro_429')) {
        msg = 'Servidores ocupados (Limite de buscas). Aguarde um instante e tente novamente.';
      } else if (e.toString().contains('timeout')) {
        msg = 'A busca demorou muito. Tente diminuir a área no mapa.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
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

      setState(() => _loading = true);
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
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Onde comer perto do campus'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. O MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: campusCenter,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (pos, hasGesture) {
                if (!hasGesture) return;
                _searchCenter = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _satellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'br.edu.webgis.campusfood',
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () => _openAttributionDialog(context),
                  ),
                  if (_satellite) const TextSourceAttribution('Imagery © Esri'),
                ],
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // 2. FILTROS
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip(PlaceCategory.restaurant),
                    const SizedBox(width: 8),
                    _buildFilterChip(PlaceCategory.bar),
                    const SizedBox(width: 8),
                    _buildFilterChip(PlaceCategory.snack),
                  ],
                ),
              ),
            ),
          ),

          // 3. BOTÃO DE BUSCAR
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: ElevatedButton.icon(
                  onPressed: _loadPlaces,
                  icon: const Icon(Icons.saved_search, size: 20),
                  label: const Text('Buscar nesta área'),
                  style: ElevatedButton.styleFrom(
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),

          // 4. CONTROLES DO MAPA
          Positioned(
            right: 16,
            top: 180,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "btn_layer",
                  onPressed: _toggleBasemap,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Icon(
                    _satellite ? Icons.map_outlined : Icons.satellite_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: "btn_location",
                  onPressed: _locateMe,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // 5. PAINEL INFERIOR (Resultados / Detalhes)
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(PlaceCategory category) {
    final isSelected = _filters.contains(category);
    return FilterChip(
      showCheckmark: false,
      elevation: isSelected ? 2 : 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      avatar: Icon(
        _iconFor(category),
        size: 18,
        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      label: Text(category.label),
      selected: isSelected,
      onSelected: (v) => _toggleFilter(category, v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  List<Marker> _buildMarkers() {
    return [
      Marker(
        point: campusCenter,
        width: 48,
        height: 48,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Icon(Icons.school, size: 28, color: Colors.indigo),
        ),
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
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.circle, size: 12, color: Colors.blue),
            ),
          ),
        ),
      // Locais encontrados
      ..._places.map((p) {
        final isSel = _selected?.id == p.id;
        final size = isSel ? 52.0 : 40.0;
        final color = isSel ? Colors.deepOrange : Colors.redAccent;
        
        return Marker(
          point: p.position,
          width: size,
          height: size,
          child: GestureDetector(
            onTap: () {
              setState(() => _selected = p);
              _mapController.move(p.position, 17);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isSel ? color.withOpacity(0.5) : Colors.black26,
                    blurRadius: isSel ? 8 : 4,
                    offset: const Offset(0, 2),
                  )
                ],
                border: Border.all(color: color, width: isSel ? 2 : 1),
              ),
              child: Icon(_iconFor(p.category), size: isSel ? 28 : 22, color: color),
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildBottomPanel(BuildContext context) {
    if (_selected != null) {
      return PlaceDetailsSheet(
        place: _selected!,
        onClose: () => setState(() => _selected = null),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            title: Text(
              'Resultados (${_places.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _userPos == null ? 'Em um raio de ${radiusMeters.toInt()}m' : 'Ordenado por distância de você',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton.filledTonal(
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
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Nenhum local encontrado. Tente mudar os filtros ou a área de busca.'),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                    itemBuilder: (context, i) {
                      final p = _places[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          child: Icon(_iconFor(p.category), color: Colors.redAccent, size: 20),
                        ),
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
          'Este protótipo usa dados e tiles do OpenStreetMap.\n'
          'Lembre-se de manter atribuição visível conforme a política de tiles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}