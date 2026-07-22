import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../models/models.dart';
import '../../services/favorite_service.dart';
import '../../services/property_service.dart';
import '../../widgets/property_card.dart';
import '../../widgets/loading_overlay.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback onPropertyTap;
  final void Function(String propertyId)? onPropertyDetail;

  const FavoritesScreen({super.key, required this.onPropertyTap, this.onPropertyDetail});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favoriteService = FavoriteService();
  List<Property> _favoriteProperties = [];
  Set<String> _favoritedIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final favorites = await _favoriteService.getFavorites();
      final properties = <Property>[];
      final ids = <String>{};
      for (final fav in favorites) {
        ids.add(fav.propertyId ?? '');
        if (fav.property != null) {
          final model = PropertyModel.fromJson(fav.property!);
          properties.add(model.toProperty());
        }
      }
      setState(() {
        _favoriteProperties = properties;
        _favoritedIds = ids;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(String propertyId, int index) async {
    try {
      if (_favoritedIds.contains(propertyId)) {
        await _favoriteService.removeFavorite(propertyId);
        setState(() {
          _favoritedIds.remove(propertyId);
          _favoriteProperties.removeAt(index);
        });
      } else {
        await _favoriteService.addFavorite(propertyId);
        setState(() => _favoritedIds.add(propertyId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorite')),
        );
      }
    }
  }

  double _imageHeight(int index) {
    switch (index % 4) {
      case 0:
        return 220;
      case 1:
        return 170;
      case 2:
        return 200;
      default:
        return 180;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('Favorites', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
              const Spacer(),
              TextButton(
                onPressed: _fetchFavorites,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: ApexLoading());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Unable to connect', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Check your connection and try again', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 8),
            TextButton(onPressed: _fetchFavorites, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_favoriteProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No favorites yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 4),
            Text('Tap the heart icon on a property to save it here', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );
    }
    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      crossAxisCount: 2,
      itemCount: _favoriteProperties.length,
      itemBuilder: (_, i) {
        final prop = _favoriteProperties[i];
        return PropertyCard(
          property: prop,
          isGrid: true,
          imageHeight: _imageHeight(i),
          isFavorited: _favoritedIds.contains(prop.id),
          onTap: () {
            showApexLoadingThen(context, () {
              if (widget.onPropertyDetail != null) {
                widget.onPropertyDetail!(prop.id);
              } else {
                widget.onPropertyTap();
              }
            });
          },
          onFavorite: () => _toggleFavorite(prop.id, i),
        );
      },
    );
  }
}
