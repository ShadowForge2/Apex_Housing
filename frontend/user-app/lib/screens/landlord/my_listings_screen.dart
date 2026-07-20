import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../models/models.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/property_service.dart';
import '../../services/token_storage.dart';
import 'edit_property_screen.dart';
import 'manage_listing_screen.dart';

Property _propertyModelToProperty(PropertyModel m) {
  int bedrooms = 0;
  int bathrooms = 0;
  for (final f in m.features) {
    if (f.featureName?.toLowerCase() == 'bedrooms') bedrooms = int.tryParse(f.featureValue ?? '') ?? 0;
    if (f.featureName?.toLowerCase() == 'bathrooms') bathrooms = int.tryParse(f.featureValue ?? '') ?? 0;
  }
  return Property(
    id: m.id,
    title: m.title,
    description: m.description ?? '',
    type: m.propertyType ?? 'apartment',
    city: m.location?.city ?? '',
    state: m.location?.state ?? '',
    address: m.location?.address ?? '',
    rentAmount: m.pricing?.rentAmount?.toInt() ?? 0,
    securityDeposit: m.pricing?.securityDeposit?.toInt() ?? 0,
    serviceFee: m.pricing?.serviceFee?.toInt() ?? 0,
    tenantPrice: (m.pricing?.rentAmount?.toInt() ?? 0) + (m.pricing?.serviceFee?.toInt() ?? 0),
    bedrooms: bedrooms,
    bathrooms: bathrooms,
    images: m.images.map((e) => e.url).toList(),
    features: m.features.map((e) => e.featureName ?? '').where((e) => e.isNotEmpty).toList(),
    amenities: m.amenities.map((e) => e.name ?? '').where((e) => e.isNotEmpty).toList(),
    agentName: 'You',
    agentAgency: 'Your Properties',
    isAvailable: m.availability?.isAvailable ?? true,
    isBooked: m.availability?.isBooked ?? false,
  );
}

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _viewMode = 0;
  final _viewModes = ['Marketplace', 'My Listings'];
  int _selectedFilter = 0;
  final _filters = ['All', 'Active', 'Occupied', 'Vacant'];
  bool _isLoading = true;
  String? _error;
  List<Property> _properties = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = await TokenStorage().getUserId();
      _userId = userId;
      final response = await PropertyService().listProperties(
        landlordId: _viewMode == 1 ? userId : null,
      );
      if (mounted) {
        setState(() {
          _properties = response.items.map(_propertyModelToProperty).toList();
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == 0
        ? _properties
        : _properties.where((p) {
            if (_selectedFilter == 1) return p.isAvailable;
            if (_selectedFilter == 2) return p.isBooked;
            return p.isAvailable && !p.isBooked;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _viewMode == 0 ? 'Marketplace' : 'My Listings',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                ),
              ),
              GestureDetector(
                onTap: () => showApexLoadingThen(context, () => Navigator.pushNamed(context, '/add-property')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Add New', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: List.generate(_viewModes.length, (i) {
                final active = _viewMode == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _viewMode = i;
                        _selectedFilter = 0;
                      });
                      _loadProperties();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _viewModes[i],
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.subtitle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: List.generate(_filters.length, (i) {
                final active = _selectedFilter == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.subtitle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: ApexLoading())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtitle)),
                          const SizedBox(height: 16),
                          TextButton(onPressed: _loadProperties, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                child: const Icon(Icons.home_work_outlined, size: 32, color: AppColors.hint),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _viewMode == 0 ? 'No listings in marketplace' : 'No listings found',
                                style: const TextStyle(color: AppColors.subtitle, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProperties,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) => _ListingCard(
                              property: filtered[i],
                              showActions: _viewMode == 1,
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Property property;
  final bool showActions;
  const _ListingCard({required this.property, this.showActions = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                Image.network(
                  property.images.isNotEmpty ? property.images.first : '',
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.home, color: AppColors.hint, size: 40),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: property.isBooked
                          ? AppColors.warning
                          : property.isAvailable
                              ? AppColors.success
                              : AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      property.isBooked ? 'Occupied' : property.isAvailable ? 'Active' : 'Vacant',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      property.priceFormatted,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.hint),
                    const SizedBox(width: 4),
                    Text('${property.city}, ${property.state}',
                        style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
                    const Spacer(),
                    const Icon(Icons.king_bed_outlined, size: 14, color: AppColors.hint),
                    const SizedBox(width: 4),
                    Text('${property.bedrooms} Bed',
                        style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
                    const SizedBox(width: 12),
                    const Icon(Icons.bathtub_outlined, size: 14, color: AppColors.hint),
                    const SizedBox(width: 4),
                    Text('${property.bathrooms} Bath',
                        style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
                  ],
                ),
                const SizedBox(height: 14),
                if (showActions)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPropertyScreen(propertyId: property.id))),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageListingScreen(property: property))),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Manage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
