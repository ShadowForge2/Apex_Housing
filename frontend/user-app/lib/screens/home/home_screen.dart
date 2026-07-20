import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../services/property_service.dart';
import '../../services/token_storage.dart';
import '../../services/user_service.dart';
import '../../services/favorite_service.dart';
import '../../services/location_service.dart';
import '../../models/models.dart';
import '../../widgets/property_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/verification_progress_banner.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/onboarding_flow_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onPropertyTap;
  final void Function(int)? onPropertyDetail;
  final VoidCallback? onMapTap;

  const HomeScreen({super.key, required this.onPropertyTap, this.onPropertyDetail, this.onMapTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;
  final _categories = ['Near Me', 'All', 'For Rent', 'Villa', 'Apartment'];
  String? _selectedPriceRange;
  final _priceRanges = [
    {'key': 'budget', 'label': 'Under 100k'},
    {'key': 'mid', 'label': '100k-300k'},
    {'key': 'standard', 'label': '300k-500k'},
    {'key': 'premium', 'label': '500k-1M'},
    {'key': 'luxury', 'label': 'Above 1M'},
  ];
  final _propertyService = PropertyService();
  final _favoriteService = FavoriteService();
  final _locationService = AppLocationService.instance;

  List<Property> _properties = [];
  bool _isLoading = true;
  String? _error;
  String _userName = '';
  String? _profilePicture;
  String _initials = 'U';
  bool _locationLoaded = false;
  VerificationStatus? _verificationStatus;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadVerificationStatus();
    _fetchProperties();
  }

  Future<void> _loadUserName() async {
    final name = await TokenStorage().getUserName();
    final email = await TokenStorage().getUserEmail();
    try {
      final profile = await UserService().getMyProfile();
      if (mounted) {
        setState(() {
          _userName = [profile.firstName, profile.lastName].where((e) => e != null && e.isNotEmpty).join(' ');
          if (_userName.isEmpty) _userName = (name != null && name.isNotEmpty) ? name : (email?.split('@').first ?? 'User');
          _profilePicture = profile.profilePicture;
          final words = _userName.split(' ');
          _initials = words.length >= 2 ? '${words[0][0]}${words[1][0]}'.toUpperCase() : (_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = (name != null && name.isNotEmpty) ? name : (email?.split('@').first ?? 'User');
          final words = _userName.split(' ');
          _initials = words.length >= 2 ? '${words[0][0]}${words[1][0]}'.toUpperCase() : (_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U');
        });
      }
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await UserService().fetchVerificationStatus();
      if (mounted) setState(() => _verificationStatus = status);
    } catch (e) {
      debugPrint('HomeScreen: Failed to load verification status: $e');
    }
  }

  String? _selectedPropertyType() {
    switch (_selectedCategory) {
      case 3:
        return 'villa';
      case 4:
        return 'apartment';
      default:
        return null;
    }
  }

  Future<void> _fetchProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_selectedCategory == 0) {
        await _fetchNearbyProperties();
      } else {
        final response = await _propertyService.searchProperties(
          propertyType: _selectedPropertyType(),
          priceRange: _selectedPriceRange,
        );
        setState(() {
          _properties = response.items.map((m) => m.toProperty()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNearbyProperties() async {
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      setState(() {
        _error = 'Location permission is required to find houses near you. Please enable it in settings.';
        _isLoading = false;
      });
      return;
    }
    _locationLoaded = true;
    try {
      final response = await _propertyService.searchProperties(
        latitude: position.latitude,
        longitude: position.longitude,
        sortBy: 'distance',
      );
      setState(() {
        _properties = response.items.map((m) => m.toProperty()).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchProperties,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(tc),
              const SizedBox(height: 20),
              if (_verificationStatus != null && !_verificationStatus!.isFullyActivated && !_bannerDismissed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: VerificationProgressBanner(
                    status: _verificationStatus!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingFlowScreen()),
                    ).then((_) => _loadVerificationStatus()),
                    onDismiss: () => setState(() => _bannerDismissed = true),
                  ),
                ),
              _buildSearch(tc),
              const SizedBox(height: 20),
              _buildCategories(tc),
              const SizedBox(height: 12),
              _buildPriceRanges(tc),
              const SizedBox(height: 28),
              _buildSectionTitle('Recommended', 'View All'),
              const SizedBox(height: 16),
              _buildFeaturedListings(),
              const SizedBox(height: 32),
              _buildSectionTitle('Popular Locations', 'See All'),
              const SizedBox(height: 16),
              _buildPopularLocations(tc),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              backgroundImage: _profilePicture != null && _profilePicture!.isNotEmpty
                  ? NetworkImage(_profilePicture!)
                  : null,
              child: _profilePicture == null || _profilePicture!.isEmpty
                  ? Text(_initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tc.text),
                ),
                Text(
                  'Ilorin, Nigeria',
                  style: TextStyle(color: tc.subtitle, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onMapTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(blurRadius: 10, color: tc.shadow)],
              ),
              child: const Icon(Icons.map_outlined, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const NotificationsScreen(),
            )),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: tc.card,
              child: Icon(Icons.notifications_none, color: tc.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: widget.onMapTap,
        child: Container(
          height: 55,
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
                  readOnly: true,
        onTap: () => showApexLoadingThen(context, widget.onMapTap!),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search properties or map...',
                    hintStyle: TextStyle(color: tc.hint),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                width: 45,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(ThemeColors tc) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final active = _selectedCategory == i;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = i);
              _fetchProperties();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : tc.card,
                borderRadius: BorderRadius.circular(25),
                border: active ? null : Border.all(color: tc.border),
              ),
              child: Text(
                _categories[i],
                style: TextStyle(
                  color: active ? Colors.white : tc.subtitle,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceRanges(ThemeColors tc) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _priceRanges.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final active = _selectedPriceRange == null;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedPriceRange = null);
                _fetchProperties();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : tc.card,
                  borderRadius: BorderRadius.circular(18),
                  border: active ? null : Border.all(color: tc.border),
                ),
                child: Text(
                  'Any Price',
                  style: TextStyle(
                    color: active ? Colors.white : tc.subtitle,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }
          final pr = _priceRanges[i - 1];
          final active = _selectedPriceRange == pr['key'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedPriceRange = active ? null : pr['key']);
              _fetchProperties();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : tc.card,
                borderRadius: BorderRadius.circular(18),
                border: active ? null : Border.all(color: tc.border),
              ),
              child: Text(
                pr['label']!,
                style: TextStyle(
                  color: active ? Colors.white : tc.subtitle,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => showApexLoading(context, duration: const Duration(milliseconds: 800), label: 'Loading...'),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedListings() {
    if (_isLoading) {
      return SizedBox(
        height: 290,
        child: Center(
          child: const ApexLoading(),
        ),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 290,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Failed to load properties', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              TextButton(onPressed: _fetchProperties, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_properties.isEmpty) {
      return SizedBox(
        height: 290,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_work_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('No properties available', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 290,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _properties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final prop = _properties[i];
          return PropertyCard(
            property: prop,
            onTap: () {
              showApexLoadingThen(context, () {
                if (widget.onPropertyDetail != null) {
                  widget.onPropertyDetail!(i);
                } else {
                  widget.onPropertyTap();
                }
              });
            },
            onFavorite: () async {
              try {
                await _favoriteService.addFavorite(prop.id);
              } catch (_) {}
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularLocations(ThemeColors tc) {
    List<Map<String, String>> locations;
    if (_properties.length >= 4) {
      locations = [
        {'name': _properties[0].city.isNotEmpty ? _properties[0].city : 'Lekki', 'count': '${_properties.length}', 'image': _properties[0].images.first},
        {'name': _properties[1].city.isNotEmpty ? _properties[1].city : 'Victoria Island', 'count': '${_properties.length}', 'image': _properties[1].images.first},
        {'name': _properties[3].city.isNotEmpty ? _properties[3].city : 'Ikoyi', 'count': '${_properties.length}', 'image': _properties[3].images.first},
      ];
    } else if (_properties.isNotEmpty) {
      locations = _properties.take(3).map((p) => {
        'name': p.city.isNotEmpty ? p.city : 'Location',
        'count': '${_properties.length}',
        'image': p.images.first,
      }).toList();
    } else {
      locations = [
        {'name': 'Lekki', 'count': '0', 'image': ''},
        {'name': 'Victoria Island', 'count': '0', 'image': ''},
        {'name': 'Ikoyi', 'count': '0', 'image': ''},
      ];
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final loc = locations[i];
          return GestureDetector(
            onTap: () => showApexLoadingThen(context, widget.onMapTap!),
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: loc['image']!.isNotEmpty
                        ? Image.network(
                            loc['image']!,
                            height: 56,
                            width: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 56,
                              color: tc.surfaceVariant,
                              child: Icon(Icons.location_city, color: tc.hint),
                            ),
                          )
                        : Container(
                            height: 56,
                            color: tc.surfaceVariant,
                            child: Icon(Icons.location_city, color: tc.hint),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${loc['count']} homes', style: TextStyle(fontSize: 11, color: tc.subtitle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
