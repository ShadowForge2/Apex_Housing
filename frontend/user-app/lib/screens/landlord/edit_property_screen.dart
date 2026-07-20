import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/property_service.dart';

class EditPropertyScreen extends StatefulWidget {
  final String? propertyId;
  const EditPropertyScreen({super.key, this.propertyId});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  String _propertyType = 'Apartment';
  final _types = ['Apartment', 'House', 'Studio', 'Penthouse', 'Duplex'];
  final _selectedAmenities = <String>{};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  PropertyModel? _property;
  List<PropertyAmenity> _allAmenities = [];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
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
    _loadProperty();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _rentController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    if (widget.propertyId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No property ID provided';
      });
      return;
    }
    try {
      final property = await PropertyService().getProperty(widget.propertyId!);
      if (mounted) {
        _titleController.text = property.title;
        _descriptionController.text = property.description ?? '';
        _addressController.text = property.location?.address ?? '';
        _cityController.text = property.location?.city ?? '';
        _stateController.text = property.location?.state ?? '';
        _rentController.text = property.pricing?.rentAmount?.toInt().toString() ?? '';
        _depositController.text = property.pricing?.securityDeposit?.toInt().toString() ?? '';
        _propertyType = (property.propertyType ?? 'apartment').substring(0, 1).toUpperCase() + (property.propertyType ?? 'apartment').substring(1);

        final selectedNames = property.amenities.map((a) => a.name ?? '').where((n) => n.isNotEmpty).toSet();
        _selectedAmenities.addAll(selectedNames);

        for (final f in property.features) {
          if (f.featureName?.toLowerCase() == 'bedrooms') _bedroomsController.text = f.featureValue ?? '';
          if (f.featureName?.toLowerCase() == 'bathrooms') _bathroomsController.text = f.featureValue ?? '';
        }

        setState(() {
          _property = property;
          _allAmenities = property.amenities;
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

  Future<void> _saveChanges() async {
    if (widget.propertyId == null) return;
    setState(() => _isSaving = true);
    try {
      final rentAmount = double.tryParse(_rentController.text.replaceAll(RegExp(r'[₦,\s]'), ''));
      final deposit = double.tryParse(_depositController.text.replaceAll(RegExp(r'[₦,\s]'), ''));

      await PropertyService().updateProperty(
        widget.propertyId!,
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        propertyType: _propertyType.toLowerCase(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
        rentAmount: rentAmount,
        securityDeposit: deposit,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Property'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
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
                      TextButton(onPressed: _loadProperty, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildCurrentImages(),
                      const SizedBox(height: 28),
                      _buildLabel('Property Type'),
                      const SizedBox(height: 12),
                      _buildTypeChips(),
                      const SizedBox(height: 24),
                      _buildLabel('Property Title'),
                      const SizedBox(height: 12),
                      _buildInput('Luxury 2BR Apartment in Lekki', controller: _titleController),
                      const SizedBox(height: 20),
                      _buildLabel('Description'),
                      const SizedBox(height: 12),
                      _buildTextArea('Beautiful modern apartment in the heart of Lekki Phase 1.', controller: _descriptionController),
                      const SizedBox(height: 20),
                      _buildLabel('Location'),
                      const SizedBox(height: 12),
                      _buildInput('15 Admiralty Way, Lekki Phase 1', controller: _addressController),
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
                      _buildInput('₦ 500,000', prefix: true, controller: _rentController),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Bedrooms'),
                                const SizedBox(height: 12),
                                _buildInput('2', controller: _bedroomsController),
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
                                _buildInput('2', controller: _bathroomsController),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Security Deposit'),
                      const SizedBox(height: 12),
                      _buildInput('₦ 50,000', prefix: true, controller: _depositController),
                      const SizedBox(height: 24),
                      _buildLabel('Amenities'),
                      const SizedBox(height: 12),
                      _buildAmenityChips(),
                      const SizedBox(height: 32),
                      AppButton(
                        text: _isSaving ? 'Saving...' : 'Save Changes',
                        onPressed: _isSaving ? null : _saveChanges,
                        icon: Icons.check_rounded,
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
                contentPadding: EdgeInsets.symmetric(horizontal: prefix ? 10 : 20, vertical: 16),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.text),
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
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
            child: Text(t, style: TextStyle(color: active ? Colors.white : AppColors.subtitle, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurrentImages() {
    final images = _property?.images ?? [];
    return SizedBox(
      height: 120,
      child: images.isEmpty
          ? Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.image, size: 40, color: AppColors.hint),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        images[i].url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: AppColors.hint),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          if (widget.propertyId == null) return;
                          try {
                            await PropertyService().deletePropertyImage(widget.propertyId!, images[i].id);
                            setState(() => _property!.images.removeAt(i));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Image removed')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to remove image: $e')),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildAmenityChips() {
    final amenities = _allAmenities.map((a) => a.name ?? '').where((n) => n.isNotEmpty).toList();
    if (amenities.isEmpty) {
      final fallbackAmenities = ['WiFi', 'Parking', 'Pool', 'Gym', 'Security', 'Generator', 'AC', 'Elevator', 'CCTV', 'Garden'];
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: fallbackAmenities.map((a) {
          final selected = _selectedAmenities.contains(a);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedAmenities.remove(a);
                } else {
                  _selectedAmenities.add(a);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: selected ? null : Border.all(color: AppColors.border),
              ),
              child: Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.subtitle)),
            ),
          );
        }).toList(),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: amenities.map((a) {
        final selected = _selectedAmenities.contains(a);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedAmenities.remove(a);
              } else {
                _selectedAmenities.add(a);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: selected ? null : Border.all(color: AppColors.border),
            ),
            child: Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.subtitle)),
          ),
        );
      }).toList(),
    );
  }
}
