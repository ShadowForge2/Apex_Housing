import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/models.dart';
import '../../widgets/apex_loading.dart';
import '../../services/property_service.dart';
import '../../services/review_service.dart';
import '../../services/booking_service.dart';
import '../../widgets/loading_overlay.dart';
import '../profile/public_profile_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property? property;
  final String? propertyId;
  final String? _slug;

  const PropertyDetailScreen({super.key, this.property, this.propertyId})
      : assert(property != null || propertyId != null, 'Either property or propertyId must be provided'),
        _slug = null;

  const PropertyDetailScreen.fromProperty({super.key, required Property property})
      : property = property,
        propertyId = null,
        _slug = null;

  const PropertyDetailScreen.fromPropertyId({super.key, required String id})
      : property = null,
        propertyId = id,
        _slug = null;

  const PropertyDetailScreen.fromSlug({super.key, required String slug})
      : property = null,
        propertyId = null,
        _slug = slug;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  Property? _loadedProperty;
  bool _isLoadingProperty = false;
  String? _loadError;
  final ReviewService _reviewService = ReviewService();
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.property != null) {
      _fetchReviews(widget.property!.id);
    } else if (widget._slug != null) {
      _fetchPropertyBySlug(widget._slug!);
    } else if (widget.propertyId != null) {
      _fetchProperty(widget.propertyId!);
    }
  }

  Future<void> _fetchPropertyBySlug(String slug) async {
    setState(() {
      _isLoadingProperty = true;
      _loadError = null;
    });
    try {
      final model = await PropertyService().getPropertyBySlug(slug);
      if (mounted) {
        setState(() {
          _loadedProperty = model.toProperty();
          _isLoadingProperty = false;
        });
        _fetchReviews(model.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Property not found';
          _isLoadingProperty = false;
        });
      }
    }
  }

  Future<void> _fetchProperty(String id) async {
    setState(() {
      _isLoadingProperty = true;
      _loadError = null;
    });
    try {
      final model = await PropertyService().getProperty(id);
      if (mounted) {
        setState(() {
          _loadedProperty = model.toProperty();
          _isLoadingProperty = false;
        });
        _fetchReviews(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingProperty = false;
        });
      }
    }
  }

  Property? get _currentProperty => _loadedProperty ?? widget.property;

  Future<void> _fetchReviews(String propertyId) async {
    setState(() => _isLoadingReviews = true);
    try {
      final reviews = await _reviewService.getPropertyReviews(propertyId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reserveNow() async {
    setState(() => _isReserving = true);
    try {
      await BookingService().createBooking(propertyId: property.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reserve: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  Property get property => widget.property ?? _loadedProperty!;
  bool _isReserving = false;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    if (_isLoadingProperty) {
      return Scaffold(
        backgroundColor: tc.background,
        body: const Center(child: ApexLoading()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: tc.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Failed to load property', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _fetchProperty(widget.propertyId!),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: tc.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: tc.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tc.card,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 10, color: tc.shadow)],
                ),
                child: Icon(Icons.arrow_back, color: tc.text, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: property.images.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                      child: Image.network(
                        property.images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: tc.surfaceVariant,
                          child: Center(child: Icon(Icons.home, size: 64, color: tc.hint)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        property.images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: _currentPage == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.subtitle),
                      const SizedBox(width: 4),
                      Text(
                        '${property.address}, ${property.city}',
                        style: TextStyle(fontSize: 14, color: tc.subtitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: tc.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _feature(Icons.king_bed_rounded, '${property.bedrooms}', 'Beds', tc),
                        _feature(Icons.bathtub_rounded, '${property.bathrooms}', 'Baths', tc),
                        _feature(Icons.directions_car_rounded, '2', 'Parking', tc),
                        _feature(Icons.square_foot_rounded, '1250', 'sqft', tc),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Description', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
                  const SizedBox(height: 12),
                  Text(
                    property.description,
                    style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  const Text('Amenities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...property.features.map((f) => _amenityChip(f)),
                      ...property.amenities.map((a) => _amenityChip(a)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('Location', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            property.latitude ?? 6.5244,
                            property.longitude ?? 3.3792,
                          ),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.apex_housing',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  property.latitude ?? 6.5244,
                                  property.longitude ?? 3.3792,
                                ),
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Agent', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
                  const SizedBox(height: 14),
                  _buildAgentCard(tc),
                  const SizedBox(height: 28),
                  _buildPropertyReviews(tc),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        color: tc.background,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Price', style: TextStyle(fontSize: 12, color: tc.hint)),
                  Text(
                    property.priceFormatted,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 170,
              height: 55,
              child: ElevatedButton(
                onPressed: _isReserving ? null : _reserveNow,
                child: _isReserving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: ApexLoading(size: 20),
                      )
                    : const Text('Reserve now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(ThemeColors tc) {
    final ratingSum = _reviews.fold<int>(0, (sum, r) => sum + (r.rating ?? 0));
    final ratingCount = _reviews.where((r) => r.rating != null && r.rating! > 0).length;
    final liveRating = ratingCount > 0 ? ratingSum / ratingCount : 0.0;
    final displayRating = liveRating > 0 ? liveRating : property.agentRating;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
            name: property.agentName,
            initials: property.agentName[0],
            role: 'Landlord',
            userId: property.landlordId ?? property.agentName,
            rating: displayRating,
            totalListings: property.agentListings,
            memberSince: '2025',
            city: property.city,
          ),
        )),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Text(
                property.agentName[0],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.agentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(property.agentAgency, style: TextStyle(fontSize: 12, color: tc.subtitle)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.rating),
                    const SizedBox(width: 3),
                    Text(displayRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
                Text(ratingCount > 0 ? '$ratingCount ratings' : 'No ratings',
                    style: TextStyle(fontSize: 11, color: tc.hint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyReviews(ThemeColors tc) {
    if (_isLoadingReviews) {
      return const Center(child: ApexLoading());
    }
    if (_reviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews (${_reviews.length})',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: tc.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
          ),
          child: Column(
            children: [
              ..._reviews.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, indent: 20, endIndent: 20, color: tc.border),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text((r.userId ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.userId ?? 'Anonymous',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
                                    Text(r.createdAt ?? '',
                                        style: TextStyle(fontSize: 11, color: tc.hint)),
                                  ],
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i2) => Icon(
                                  i2 < (r.rating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 14,
                                  color: i2 < (r.rating ?? 0) ? AppColors.rating : AppColors.border,
                                )),
                              ),
                            ],
                          ),
                          if ((r.comment ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(r.comment!,
                                style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feature(IconData icon, String value, String label, ThemeColors tc) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.lightPurple,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: tc.hint)),
      ],
    );
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}
