import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/review_service.dart';

class RatingScreen extends StatefulWidget {
  final String agentName;
  final String propertyTitle;
  final String bookingRef;
  final String propertyId;
  const RatingScreen({
    super.key,
    required this.agentName,
    required this.propertyTitle,
    required this.bookingRef,
    required this.propertyId,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _selectedRating = 0;
  final _reviewController = TextEditingController();
  bool _submitted = false;
  bool _isSubmitting = false;
  String? _submitError;
  final _reviewService = ReviewService();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThankYou();
    return _buildRatingForm();
  }

  Widget _buildRatingForm() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Agent'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildAgentCard(),
            const SizedBox(height: 32),
            _buildStarRating(),
            const SizedBox(height: 8),
            _buildRatingLabel(),
            const SizedBox(height: 32),
            _buildReviewInput(),
            const SizedBox(height: 12),
            _buildQuickTags(),
            const SizedBox(height: 32),
            if (_submitError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_submitError!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
              ),
            ],
            _buildSubmitButton(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              widget.agentName[0],
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.agentName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(widget.propertyTitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final index = i + 1;
        final filled = index <= _selectedRating;
        return GestureDetector(
          onTap: () => setState(() => _selectedRating = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 48,
              color: filled ? AppColors.rating : AppColors.border,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRatingLabel() {
    String label;
    switch (_selectedRating) {
      case 1:
        label = 'Poor';
        break;
      case 2:
        label = 'Fair';
        break;
      case 3:
        label = 'Good';
        break;
      case 4:
        label = 'Very Good';
        break;
      case 5:
        label = 'Excellent';
        break;
      default:
        label = 'Tap a star to rate';
    }
    return Text(label,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _selectedRating > 0 ? AppColors.primary : AppColors.hint));
  }

  Widget _buildReviewInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: TextField(
        controller: _reviewController,
        maxLines: 4,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Write your review (optional)...',
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildQuickTags() {
    final tags = ['Professional', 'Responsive', 'Great Property', 'Fair Price', 'Good Communication'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return GestureDetector(
          onTap: () {
            final current = _reviewController.text;
            if (!current.contains(tag)) {
              setState(() {
                _reviewController.text = current.isEmpty ? tag : '$current, $tag';
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    final enabled = _selectedRating > 0 && !_isSubmitting;
    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        alignment: Alignment.center,
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: ApexLoading(size: 20),
              )
            : const Text('Submit Rating',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final comment = _reviewController.text.trim();
      await _reviewService.createReview(
        propertyId: widget.propertyId,
        rating: _selectedRating,
        comment: comment.isNotEmpty ? comment : null,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) setState(() => _submitError = 'Failed to submit rating: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildThankYou() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
              ),
              const SizedBox(height: 28),
              const Text('Thank You!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: 12),
              Text(
                'Your rating for ${widget.agentName} has been submitted. It helps other tenants make better decisions.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.subtitle, height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Icon(
                    i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 32,
                    color: i < _selectedRating ? AppColors.rating : AppColors.border,
                  );
                }),
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
