import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/app_button.dart';
import '../../services/property_service.dart';
import '../../services/amenity_service.dart';
import '../../services/app_state_restoration.dart';
import '../../services/permission_helper.dart';

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
    'latitude': _latitude,
    'longitude': _longitude,
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
    _latitude = data['latitude'] as double?;
    _longitude = data['longitude'] as double?;
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
  final _addressFocusNode = FocusNode();

  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  final _imagePicker = ImagePicker();
  final Map<String, File?> _imageSlots = {
    'front': null,
    'bathroom': null,
    'toilet': null,
    'bedroom': null,
    'kitchen': null,
  };
  File? _videoFile;

  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isSearchingAddress = false;

  static const _slotLabels = {
    'front': 'Front View',
    'bathroom': 'Bathroom',
    'toilet': 'Toilet',
    'bedroom': 'Bedroom',
    'kitchen': 'Kitchen',
  };

  static const _slotIcons = {
    'front': Icons.home_outlined,
    'bathroom': Icons.bathtub_outlined,
    'toilet': Icons.wc_outlined,
    'bedroom': Icons.king_bed_outlined,
    'kitchen': Icons.kitchen_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadAmenities();
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    final text = _addressController.text.trim();
    if (text.length >= 3) {
      _searchAddresses(text);
    } else {
      setState(() => _addressSuggestions = []);
    }
  }

  Future<void> _searchAddresses(String query) async {
    setState(() => _isSearchingAddress = true);
    try {
      final results = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _addressSuggestions = results.take(5).map((loc) => {
            'address': '',
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          }).toList();
          _isSearchingAddress = false;
        });
        for (int i = 0; i < _addressSuggestions.length && i < 5; i++) {
          try {
            final placemarks = await placemarkFromCoordinates(
              _addressSuggestions[i]['latitude'] as double,
              _addressSuggestions[i]['longitude'] as double,
            );
            if (placemarks.isNotEmpty && mounted) {
              final p = placemarks.first;
              final parts = [p.name, p.street, p.subLocality, p.locality, p.administrativeArea]
                  .where((e) => e != null && e.isNotEmpty);
              setState(() {
                _addressSuggestions[i]['address'] = parts.join(', ');
              });
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _selectAddressSuggestion(Map<String, dynamic> suggestion) {
    _addressController.removeListener(_onAddressChanged);
    _latitude = suggestion['latitude'] as double;
    _longitude = suggestion['longitude'] as double;
    _addressController.text = suggestion['address'] as String;
    _addressController.addListener(_onAddressChanged);
    setState(() => _addressSuggestions = []);
    _addressFocusNode.unfocus();
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
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
    _addressFocusNode.dispose();
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

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable in settings.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Location Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
              'APEX Housing needs your location to auto-fill the property address and show it on the map to potential tenants.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Now')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );
        if (proceed != true) return;

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        final opened = await openAppSettings();
        if (!opened) return;
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latitude = position.latitude;
      _longitude = position.longitude;

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _addressController.removeListener(_onAddressChanged);
          _addressController.text = [place.street, place.subLocality]
              .where((e) => e != null && e.isNotEmpty).join(', ');
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _addressController.addListener(_onAddressChanged);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location captured')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage(String slot) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Select Source', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Camera'),
                onTap: () { Navigator.pop(ctx); _captureImage(slot, ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Gallery'),
                onTap: () { Navigator.pop(ctx); _captureImage(slot, ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage(String slot, ImageSource source) async {
    final hasPermission = await PermissionHelper.showRationaleAndRequest(
      context,
      permission: source == ImageSource.camera ? Permission.camera : Permission.photos,
      title: source == ImageSource.camera ? 'Camera Access' : 'Gallery Access',
      explanation: source == ImageSource.camera
          ? 'APEX Housing needs camera access to take photos of your property for listing.'
          : 'APEX Housing needs gallery access to upload property photos from your device.',
      icon: source == ImageSource.camera ? Icons.camera_alt_outlined : Icons.photo_library_outlined,
    );

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${source == ImageSource.camera ? 'Camera' : 'Gallery'} permission is required to add property photos.'),
            action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
          ),
        );
      }
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() => _imageSlots[slot] = File(picked.path));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickVideo() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Select Video Source', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
                title: const Text('Camera'),
                onTap: () { Navigator.pop(ctx); _captureVideo(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined, color: AppColors.primary),
                title: const Text('Gallery'),
                onTap: () { Navigator.pop(ctx); _captureVideo(ImageSource.gallery); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureVideo(ImageSource source) async {
    final hasPermission = await PermissionHelper.showRationaleAndRequest(
      context,
      permission: source == ImageSource.camera ? Permission.camera : Permission.videos,
      title: source == ImageSource.camera ? 'Camera Access' : 'Gallery Access',
      explanation: source == ImageSource.camera
          ? 'APEX Housing needs camera access to record a video walkthrough of your property.'
          : 'APEX Housing needs gallery access to upload a video from your device.',
      icon: source == ImageSource.camera ? Icons.videocam_outlined : Icons.video_library_outlined,
    );

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${source == ImageSource.camera ? 'Camera' : 'Gallery'} permission is required to add property videos.'),
            action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
          ),
        );
      }
      return;
    }

    try {
      final picked = await _imagePicker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));
      if (picked != null && mounted) {
        setState(() => _videoFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
    }
  }

  Future<void> _publishListing() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a property title')));
      return;
    }

    final allFilled = _imageSlots.values.every((f) => f != null);
    if (!allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload all 5 required images')));
      return;
    }

    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a property video')));
      return;
    }

    if (_termsController.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terms & Conditions must be at least 20 characters')));
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

      final propData = await PropertyService().createProperty(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        propertyType: _propertyType.toLowerCase(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
        latitude: _latitude,
        longitude: _longitude,
        rentAmount: rentAmount > 0 ? rentAmount : null,
        securityDeposit: deposit > 0 ? deposit : null,
        agentTerms: _termsController.text.trim().isNotEmpty ? _termsController.text.trim() : null,
        amenityIds: selectedAmenityIds.isNotEmpty ? selectedAmenityIds : null,
      );

      final propertyId = propData['id'] as String;

      int sortOrder = 0;
      for (final entry in _imageSlots.entries) {
        if (entry.value != null) {
          await PropertyService().uploadPropertyImage(
            propertyId,
            filePath: entry.value!.path,
            label: entry.key,
            sortOrder: sortOrder++,
          );
        }
      }

      if (_videoFile != null) {
        await PropertyService().uploadPropertyVideo(propertyId, filePath: _videoFile!.path);
      }

      if (mounted) {
        await clearSavedState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property published successfully. An email has been sent to your inbox.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
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
            _buildLabel('Property Photos'),
            const SizedBox(height: 4),
            const Text('Upload all 5 required photos', style: TextStyle(fontSize: 12, color: AppColors.hint)),
            const SizedBox(height: 12),
            _buildImageGrid(),
            const SizedBox(height: 16),
            _buildLabel('Property Video'),
            const SizedBox(height: 4),
            const Text('Record or select a short video tour (max 60s)', style: TextStyle(fontSize: 12, color: AppColors.hint)),
            const SizedBox(height: 12),
            _buildVideoSlot(),
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
            GestureDetector(
              onTap: _isGettingLocation ? null : _useMyLocation,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isGettingLocation)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    else
                      Icon(
                        _latitude != null ? Icons.check_circle_outline : Icons.my_location_rounded,
                        size: 18,
                        color: _latitude != null ? AppColors.success : AppColors.primary,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _latitude != null ? 'Location captured — tap to update' : 'Use my current location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _latitude != null ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAddressInput(),
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

  Widget _buildImageGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        ..._imageSlots.entries.map((entry) => _buildImageSlot(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildImageSlot(String slot, File? file) {
    final label = _slotLabels[slot]!;
    final icon = _slotIcons[slot]!;
    final hasImage = file != null;

    return GestureDetector(
      onTap: () => _pickImage(slot),
      child: Container(
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? AppColors.success : AppColors.border,
            width: hasImage ? 2 : 1.5,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageSlots[slot] = null),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.hint, size: 28),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtitle), textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  const Icon(Icons.add_circle_outline, size: 18, color: AppColors.hint),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoSlot() {
    final hasVideo = _videoFile != null;
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasVideo ? Colors.transparent : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasVideo ? AppColors.success : AppColors.border,
            width: hasVideo ? 2 : 1.5,
          ),
        ),
        child: hasVideo
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, color: AppColors.success, size: 36),
                          const SizedBox(height: 8),
                          Text('Video selected', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _videoFile = null),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text('Upload Video', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  const Text('Tap to record or select', style: TextStyle(fontSize: 12, color: AppColors.hint)),
                ],
              ),
      ),
    );
  }

  Widget _buildAddressInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInput(
          'Start typing address...',
          controller: _addressController,
          focusNode: _addressFocusNode,
        ),
        if (_isSearchingAddress)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
              SizedBox(width: 8),
              Text('Searching...', style: TextStyle(fontSize: 12, color: AppColors.hint)),
            ]),
          ),
        if (_addressSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _addressSuggestions.map((s) {
                final addr = s['address'] as String;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                  title: Text(addr.isNotEmpty ? addr : 'Pin location on map', style: const TextStyle(fontSize: 13)),
                  onTap: () => _selectAddressSuggestion(s),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text));
  }

  Widget _buildInput(String hint, {bool prefix = false, TextEditingController? controller, FocusNode? focusNode}) {
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
              focusNode: focusNode,
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

  Widget _buildAmenityChips() {
    if (_isLoadingAmenities) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: ApexLoading()),
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
                Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.subtitle)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
