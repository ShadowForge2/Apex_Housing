import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/models.dart';
import '../../services/property_service.dart';
import '../../widgets/loading_overlay.dart';

class ManageListingScreen extends StatefulWidget {
  final Property property;
  const ManageListingScreen({super.key, required this.property});

  @override
  State<ManageListingScreen> createState() => _ManageListingScreenState();
}

class _ManageListingScreenState extends State<ManageListingScreen> {
  late bool _isAvailable;
  late bool _isBooked;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _isAvailable = widget.property.isAvailable;
    _isBooked = widget.property.isBooked;
  }

  Property get property => widget.property;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Listing'),
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
            _buildPropertyPreview(),
            const SizedBox(height: 28),
            const Text('Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
            const SizedBox(height: 14),
            if (_isBooked) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.warning, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This listing has an active booking. Editing and deleting are blocked until the transaction is completed.',
                        style: TextStyle(fontSize: 13, color: AppColors.warning.shade700, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildActionCard(
                context,
                icon: _isAvailable ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.warning,
                title: _isAvailable ? 'Hide Listing' : 'Unhide Listing',
                subtitle: _isAvailable
                    ? 'Hide this listing from search results. You can unhide it anytime.'
                    : 'Make this listing visible in search results again.',
                onTap: () => _toggleVisibility(),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                context,
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                title: 'Delete Listing',
                subtitle: 'Permanently remove this listing. This action cannot be undone.',
                onTap: () => _confirmDelete(),
              ),
            ],
            const SizedBox(height: 28),
            const Text('Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
            const SizedBox(height: 14),
            _buildStatusInfo(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                Image.network(
                  property.images.first,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
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
                      color: _isBooked
                          ? AppColors.warning
                          : _isAvailable
                              ? AppColors.success
                              : AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _isBooked ? 'Occupied' : _isAvailable ? 'Active' : 'Vacant',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
                    Text(property.priceFormatted,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isUpdating ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4)),
                ],
              ),
            ),
            if (_isUpdating)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo() {
    final items = [
      _statusRow('Visibility', _isAvailable ? 'Visible' : 'Hidden',
          _isAvailable ? AppColors.success : AppColors.warning),
      _statusRow('Occupancy', _isBooked ? 'Occupied' : 'Vacant',
          _isBooked ? AppColors.warning : AppColors.subtitle),
      _statusRow('Bedrooms', '${property.bedrooms}', AppColors.text),
      _statusRow('Bathrooms', '${property.bathrooms}', AppColors.text),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Divider(height: 1, color: AppColors.border);
          }
          return items[i ~/ 2];
        }),
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.subtitle)),
          const Spacer(),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final newStatus = _isAvailable ? 'inactive' : 'active';
      await PropertyService().updateProperty(
        property.id,
        status: newStatus,
      );
      if (mounted) {
        setState(() => _isAvailable = !_isAvailable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isAvailable ? 'Listing now visible in search' : 'Listing hidden from search'),
            backgroundColor: _isAvailable ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Listing',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
          'Are you sure you want to delete "${property.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.subtitle, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProperty();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await PropertyService().deleteProperty(property.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted'), backgroundColor: AppColors.error),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}
