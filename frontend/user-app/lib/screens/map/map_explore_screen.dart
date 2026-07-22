import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/models.dart';
import '../../services/property_service.dart';
import '../../services/location_service.dart';
import '../../widgets/loading_overlay.dart';

class MapExploreScreen extends StatefulWidget {
  final void Function(String propertyId)? onPropertyDetail;

  const MapExploreScreen({super.key, this.onPropertyDetail});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  final MapController _mapController = MapController();
  final PropertyService _propertyService = PropertyService();
  final AppLocationService _locationService = AppLocationService.instance;
  final TextEditingController _searchController = TextEditingController();

  static const _lagosCenter = LatLng(6.5244, 3.3792);

  List<Property> _properties = [];
  bool _isLoading = true;
  String? _error;
  int _selectedPropertyIndex = -1;
  bool _mapReady = false;
  Timer? _debounce;

  LatLng _currentCenter = _lagosCenter;
  double _currentZoom = 13;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      _currentCenter = LatLng(position.latitude, position.longitude);
      if (_mapReady) {
        _mapController.move(_currentCenter, _currentZoom);
      }
    }
    _fetchProperties();
  }

  void _onMapMoved(MapCamera camera) {
    _currentCenter = camera.center;
    _currentZoom = camera.zoom;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchProperties();
    });
  }

  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _propertyService.searchProperties(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        radiusKm: _radiusFromZoom(_currentZoom),
        sortBy: 'distance',
        pageSize: 50,
      );
      if (mounted) {
        setState(() {
          _properties = response.items.map((m) => m.toProperty()).toList();
          _isLoading = false;
          _selectedPropertyIndex = -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _radiusFromZoom(double zoom) {
    if (zoom >= 16) return 2;
    if (zoom >= 14) return 5;
    if (zoom >= 12) return 15;
    if (zoom >= 10) return 30;
    return 50;
  }

  Future<void> _searchProperties(String query) async {
    if (query.trim().isEmpty) {
      _fetchProperties();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _propertyService.searchProperties(
        query: query,
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        sortBy: 'distance',
        pageSize: 50,
      );
      if (mounted) {
        setState(() {
          _properties = response.items.map((m) => m.toProperty()).toList();
          _isLoading = false;
          _selectedPropertyIndex = -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _centerOnUser() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      final center = LatLng(position.latitude, position.longitude);
      _mapController.move(center, 14);
      setState(() => _currentCenter = center);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: _currentZoom,
                onMapReady: () => _mapReady = true,
                onTap: (tapPos, latLng) => setState(() => _selectedPropertyIndex = -1),
                onPositionChanged: (pos, hasGesture) => _onMapMoved(pos),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.apex_housing',
                ),
                MarkerLayer(
                  markers: _buildMarkers(tc),
                ),
              ],
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(blurRadius: 15, color: tc.shadow)],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  Icon(Icons.search, color: tc.hint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search in this area...',
                        hintStyle: TextStyle(color: tc.hint),
                      ),
                      onSubmitted: _searchProperties,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_searchController.text.isNotEmpty) {
                        _searchProperties(_searchController.text);
                      } else {
                        _fetchProperties();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      width: 45,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            child: Column(
              children: [
                _floatingButton(Icons.add, () {
                  _mapController.move(_currentCenter, _currentZoom + 1);
                }, tc),
                const SizedBox(height: 8),
                _floatingButton(Icons.remove, () {
                  _mapController.move(_currentCenter, _currentZoom - 1);
                }, tc),
                const SizedBox(height: 12),
                _floatingButton(Icons.my_location_rounded, _centerOnUser, tc),
              ],
            ),
          ),

          if (_isLoading && _properties.isEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: tc.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(blurRadius: 10, color: tc.shadow)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text('Loading properties...', style: TextStyle(fontSize: 13, color: tc.text)),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            left: 20,
            bottom: _selectedPropertyIndex >= 0 ? 170 : 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(blurRadius: 10, color: tc.shadow)],
              ),
              child: Text(
                '${_properties.length} properties found',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tc.text),
              ),
            ),
          ),

          if (_selectedPropertyIndex >= 0 && _selectedPropertyIndex < _properties.length)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomPropertyCard(_properties[_selectedPropertyIndex], tc),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(ThemeColors tc) {
    final markers = <Marker>[];

    final position = _locationService.currentPosition;
    if (position != null) {
      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 140,
          height: 56,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
                ),
                child: const Text(
                  'Your location',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.blue.withOpacity(0.4))],
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (int i = 0; i < _properties.length; i++) {
      final p = _properties[i];
      if (p.latitude == null || p.longitude == null) continue;
      final isSelected = _selectedPropertyIndex == i;
      markers.add(
        Marker(
          point: LatLng(p.latitude!, p.longitude!),
          width: isSelected ? 110 : 90,
          height: 40,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => setState(() => _selectedPropertyIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : tc.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(blurRadius: 8, color: tc.shadow)],
                border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
              ),
              child: Text(
                p.priceFormatted,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected ? Colors.white : tc.text,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _floatingButton(IconData icon, VoidCallback onPressed, ThemeColors tc) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tc.card,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(blurRadius: 10, color: tc.shadow)],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: tc.text),
        onPressed: onPressed,
      ),
    );
  }

  Widget _bottomPropertyCard(Property property, ThemeColors tc) {
    return GestureDetector(
      onTap: () {
        if (widget.onPropertyDetail != null && _selectedPropertyIndex >= 0 && _selectedPropertyIndex < _properties.length) {
          showApexLoadingThen(context, () {
            widget.onPropertyDetail!(_properties[_selectedPropertyIndex].id);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        height: 125,
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(blurRadius: 25, color: tc.shadow)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
              child: property.images.isNotEmpty
                  ? Image.network(
                      property.images.first,
                      width: 130,
                      height: 125,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 130,
                        height: 125,
                        color: tc.surfaceVariant,
                        child: Icon(Icons.home, size: 36, color: tc.hint),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: 125,
                      color: tc.surfaceVariant,
                      child: Icon(Icons.home, size: 36, color: tc.hint),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      property.priceFormatted,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: tc.hint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            property.address.isNotEmpty ? property.address : '${property.city}, ${property.state}',
                            style: TextStyle(fontSize: 12, color: tc.subtitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _stat(Icons.king_bed_outlined, '${property.bedrooms}', tc),
                        const SizedBox(width: 10),
                        _stat(Icons.bathtub_outlined, '${property.bathrooms}', tc),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, ThemeColors tc) {
    return Row(
      children: [
        Icon(icon, size: 14, color: tc.hint),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tc.subtitle)),
      ],
    );
  }
}
