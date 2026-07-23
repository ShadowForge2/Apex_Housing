import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/report_service.dart';

class RaiseDisputeScreen extends StatefulWidget {
  final String bookingId;
  final String propertyTitle;
  final String? landlordId;
  final String? landlordName;

  const RaiseDisputeScreen({
    super.key,
    required this.bookingId,
    required this.propertyTitle,
    this.landlordId,
    this.landlordName,
  });

  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'property_damage';
  String _selectedSeverity = 'medium';
  bool _isSubmitting = false;

  static const _types = [
    {'value': 'property_damage', 'label': 'Property Damage', 'icon': Icons.broken_house_rounded},
    {'value': 'harassment', 'label': 'Harassment', 'icon': Icons.gpp_bad_rounded},
    {'value': 'safety', 'label': 'Safety Concern', 'icon': Icons.shield_rounded},
    {'value': 'noise', 'label': 'Noise Complaint', 'icon': Icons.volume_down_rounded},
    {'value': 'discrimination', 'label': 'Discrimination', 'icon': Icons.block_rounded},
    {'value': 'other', 'label': 'Other', 'icon': Icons.help_outline_rounded},
  ];

  static const _severities = [
    {'value': 'low', 'label': 'Low', 'color': AppColors.subtitle},
    {'value': 'medium', 'label': 'Medium', 'color': AppColors.warning},
    {'value': 'high', 'label': 'High', 'color': AppColors.error},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ReportService().raiseDispute(
        bookingId: widget.bookingId,
        disputeType: _selectedType,
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        reportedAgainstId: widget.landlordId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute submitted successfully. Our team will review it shortly.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit dispute: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Raise Dispute'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filing a false dispute may result in account suspension. Only report genuine issues.',
                        style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Dispute Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final isSelected = _selectedType == t['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t['value'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : tc.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : tc.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t['icon'] as IconData, size: 16, color: isSelected ? AppColors.primary : tc.hint),
                          const SizedBox(width: 6),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.primary : tc.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Text('Severity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
              const SizedBox(height: 10),
              Row(
                children: _severities.map((s) {
                  final isSelected = _selectedSeverity == s['value'];
                  final color = s['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSeverity = s['value'] as String),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.1) : tc.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isSelected ? color : tc.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? color : tc.text,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Text('Title (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Brief summary of the issue',
                  hintStyle: TextStyle(color: tc.hint),
                  filled: true,
                  fillColor: tc.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please describe the issue';
                  if (v.trim().length < 10) return 'Description must be at least 10 characters';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Describe the issue in detail. Include dates, specific incidents, and any evidence you have.',
                  hintStyle: TextStyle(color: tc.hint, fontSize: 13),
                  filled: true,
                  fillColor: tc.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (widget.landlordName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tc.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 16, color: tc.hint),
                      const SizedBox(width: 8),
                      Text('Reported against: ${widget.landlordName}', style: TextStyle(fontSize: 13, color: tc.subtitle)),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: ApexLoading(size: 20))
                      : const Text('Submit Dispute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
