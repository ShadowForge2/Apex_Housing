import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/property_service.dart';
import '../../services/amenity_service.dart';
import '../../services/app_state_restoration.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> with AppStateRestoration {
  @override
  String get screenId => 'add_property';

  @override
  Map<String, dynamic> get restorationData => {
    'title': _titleController.text,
    'description': _descriptionController.text,
    'address': _addressController.text,
    'city': _cityController.text,
    'state': _stateController.text,
    'rent': _rentController.text,
    'bedrooms': _bedroomsController.text,
    'bathrooms': _bathroomsController.text,
    'deposit': _depositController.text,
    'propertyType': _propertyType,
    'amenities': _selectedAmenities.toList(),
  };

  @override
  void restoreState(Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _addressController.text = data['address'] ?? '';
    _cityController.text = data['city'] ?? '';
    _stateController.text = data['state'] ?? '';
    _rentController.text = data['rent'] ?? '';
    _bedroomsController.text = data['bedrooms'] ?? '';
    _bathroomsController.text = data['bathrooms'] ?? '';
    _depositController.text = data['deposit'] ?? '';
    _propertyType = data['propertyType'] ?? 'Apartment';
    _selectedAmenities = Set<String>.from(data['amenities'] ?? []);
    if (mounted) setState(() {});
  }
  final _types = ['Apartment', 'House', 'Studio', 'Penthouse', 'Duplex'];
  String _propertyType = 'Apartment';
  Set<String> _selectedAmenities = {};
  bool _isSubmitting = false;
  bool _isLoadingAmenities = true;
  List<AmenityModel> _amenities = [];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termsController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _rentController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _depositController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _rentController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _loadAmenities() async {
    try {
      final amenities = await AmenityService().listAmenities();
      if (mounted) {
        setState(() {
          _amenities = amenities;
          _isLoadingAmenities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAmenities = false);
      }
    }
  }

  Future<void> _publishListing() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a property title')),
      );
      return;
    }

    if (_termsController.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terms & Conditions must be at least 20 characters')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final rentAmount = double.tryParse(_rentController.text.replaceAll(RegExp(r'[₦,\s]'), '')) ?? 0;
      final deposit = double.tryParse(_depositController.text.replaceAll(RegExp(r'[₦,\s]'), '')) ?? 0;

      final selectedAmenityIds = _amenities
          .where((a) => _selectedAmenities.contains(a.name))
          .map((a) => a.id)
          .toList();

      await PropertyService().createProperty(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        propertyType: _propertyType.toLowerCase(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
        rentAmount: rentAmount > 0 ? rentAmount : null,
        securityDeposit: deposit > 0 ? deposit : null,
        agentTerms: _termsController.text.trim().isNotEmpty ? _termsController.text.trim() : null,
        amenityIds: selectedAmenityIds.isNotEmpty ? selectedAmenityIds : null,
      );

      if (mounted) {
        await clearSavedState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property published successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Property'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildImageUpload(),
            const SizedBox(height: 28),
            _buildLabel('Property Type'),
            const SizedBox(height: 12),
            _buildTypeChips(),
            const SizedBox(height: 24),
            _buildLabel('Property Title'),
            const SizedBox(height: 12),
            _buildInput('e.g. Luxury 2BR Apartment in Lekki', controller: _titleController),
            const SizedBox(height: 20),
            _buildLabel('Description'),
            const SizedBox(height: 12),
            _buildTextArea('Describe your property...', controller: _descriptionController),
            const SizedBox(height: 20),
            _buildLabel('Terms & Conditions'),
            const SizedBox(height: 8),
            const Text('Required. Minimum 20 characters.', style: TextStyle(fontSize: 12, color: AppColors.hint)),
            const SizedBox(height: 12),
            _buildTextArea('Enter your terms and conditions for this listing...', controller: _termsController),
            const SizedBox(height: 20),
            _buildLabel('Location'),
            const SizedBox(height: 12),
            _buildInput('Address or area', controller: _addressController),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('City'),
                      const SizedBox(height: 12),
                      _buildInput('Lagos', controller: _cityController),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('State'),
                      const SizedBox(height: 12),
                      _buildInput('Lagos', controller: _stateController),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Rent Amount (per year)'),
            const SizedBox(height: 12),
            _buildInput('₦ 0.00', prefix: true, controller: _rentController),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Bedrooms'),
                      const SizedBox(height: 12),
                      _buildInput('0', controller: _bedroomsController),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Bathrooms'),
                      const SizedBox(height: 12),
                      _buildInput('0', controller: _bathroomsController),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Security Deposit'),
            const SizedBox(height: 12),
            _buildInput('₦ 0.00', prefix: true, controller: _depositController),
            const SizedBox(height: 24),
            _buildLabel('Amenities'),
            const SizedBox(height: 12),
            _buildAmenityChips(),
            const SizedBox(height: 24),
            _buildLabel('Availability'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From', style: TextStyle(fontSize: 12, color: AppColors.hint)),
                      const SizedBox(height: 8),
                      _buildInput('Select date'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Until', style: TextStyle(fontSize: 12, color: AppColors.hint)),
                      const SizedBox(height: 8),
                      _buildInput('Select date'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            AppButton(
              text: _isSubmitting ? 'Publishing...' : 'Publish Listing',
              onPressed: _isSubmitting ? null : _publishListing,
              icon: Icons.publish_rounded,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text));
  }

  Widget _buildInput(String hint, {bool prefix = false, TextEditingController? controller}) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (prefix)
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text('₦', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.subtitle)),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                contentPadding: EdgeInsets.symmetric(horizontal: prefix ? 10 : 20, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(String hint, {TextEditingController? controller}) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        maxLines: null,
        expands: true,
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildTypeChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _types.map((t) {
        final active = _propertyType == t;
        return GestureDetector(
          onTap: () => setState(() => _propertyType = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: active ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: active ? Colors.white : AppColors.subtitle,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageUpload() {
    return GestureDetector(
      onTap: () => showApexLoading(context, duration: const Duration(seconds: 1), label: 'Opening gallery...'),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('Upload Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Tap to add property images', style: TextStyle(fontSize: 13, color: AppColors.hint)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityChips() {
    if (_isLoadingAmenities) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: const Center(child: ApexLoading()),
      );
    }
    final amenityNames = _amenities.map((a) => a.name ?? '').where((n) => n.isNotEmpty).toList();
    if (amenityNames.isEmpty) {
      return const Text('No amenities available', style: TextStyle(color: AppColors.hint, fontSize: 13));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: amenityNames.map((a) {
        final active = _selectedAmenities.contains(a);
        return GestureDetector(
          onTap: () => setState(() {
            if (active) {
              _selectedAmenities.remove(a);
            } else {
              _selectedAmenities.add(a);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: active ? null : Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(a,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.subtitle)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
