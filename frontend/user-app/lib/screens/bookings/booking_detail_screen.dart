import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/models.dart';
import '../../widgets/apex_loading.dart';
import '../../services/booking_service.dart';
import '../../services/escrow_service.dart';
import '../../widgets/status_badge.dart';
import 'rating_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  final String? bookingId;
  const BookingDetailScreen({super.key, required this.booking, this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _bookingService = BookingService();
  final _escrowService = EscrowService();
  late Booking _booking;
  EscrowModel? _escrow;
  bool _isLoading = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (widget.bookingId != null) _fetchBooking();
  }

  Future<void> _fetchBooking() async {
    setState(() => _isLoading = true);
    try {
      final model = await _bookingService.getBooking(widget.bookingId!);
      EscrowModel? escrow;
      try {
        escrow = await _escrowService.getEscrowByBooking(widget.bookingId!);
      } catch (_) {}
      setState(() {
        _booking = Booking(
          id: model.id,
          propertyId: model.propertyId,
          reference: 'APX-${model.id.length > 8 ? model.id.substring(0, 8) : model.id}',
          propertyTitle: 'Property ${model.propertyId ?? ''}',
          propertyImage: '',
          status: model.status ?? 'pending',
          totalAmount: model.totalAmount,
          moveInDate: model.moveInDate ?? '—',
          createdAt: model.createdAt ?? '—',
          escrowStatus: escrow?.status ?? model.status ?? 'pending',
          inspectionHoursLeft: null,
        );
        _escrow = escrow;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load booking details')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      final model = await _bookingService.cancelBooking(_booking.id);
      setState(() {
        _booking = Booking(
          id: model.id,
          propertyId: _booking.propertyId,
          reference: _booking.reference,
          propertyTitle: _booking.propertyTitle,
          propertyImage: _booking.propertyImage,
          status: model.status ?? 'cancelled',
          totalAmount: _booking.totalAmount,
          moveInDate: model.moveInDate ?? _booking.moveInDate,
          createdAt: model.createdAt ?? _booking.createdAt,
          cancellationReason: _booking.cancellationReason,
          escrowStatus: _booking.escrowStatus,
          inspectionHoursLeft: null,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Booking Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: ApexLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildPropertyCard(tc),
                  const SizedBox(height: 24),
                  _buildStatusSection(tc),
                  const SizedBox(height: 24),
                  _buildPaymentBreakdown(tc),
                  const SizedBox(height: 24),
                  _buildEscrowTimeline(tc),
                  const SizedBox(height: 24),
                  _buildActions(context, tc),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildPropertyCard(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Image.network(
              _booking.propertyImage,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: tc.surfaceVariant,
                child: Icon(Icons.home, size: 48, color: tc.hint),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_booking.propertyTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: tc.text)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.confirmation_num_outlined, size: 16, color: AppColors.subtitle),
                    const SizedBox(width: 6),
                    Text(_booking.reference, style: TextStyle(fontSize: 13, color: tc.subtitle, fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(ThemeColors tc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
          const SizedBox(height: 10),
          StatusBadge(text: _booking.status),
          const SizedBox(height: 16),
          Row(
            children: [
              _meta(Icons.calendar_today_rounded, 'Move-in', _booking.moveInDate, tc),
              const SizedBox(width: 24),
              _meta(Icons.access_time_rounded, 'Created', _booking.createdAt, tc),
            ],
          ),
          if (_booking.inspectionHoursLeft != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(
                    'Inspection window closes in ${_booking.inspectionHoursLeft} hours',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(ThemeColors tc) {
    final rentAmount = _booking.totalAmount > 0 ? (_booking.totalAmount * 0.86).round() : 0;
    final serviceFee = _booking.totalAmount > 0 ? (_booking.totalAmount * 0.05).round() : 0;
    final securityDeposit = _booking.totalAmount > 0 ? (_booking.totalAmount - rentAmount - serviceFee) : 0;

    String fmt(int n) {
      if (n <= 0) return '—';
      return '₦${n.toString().replaceAll(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), ',')}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
          const SizedBox(height: 14),
          _paymentRow('Annual Rent', fmt(rentAmount), tc: tc),
          _paymentRow('Service Fee (5%)', fmt(serviceFee), tc: tc),
          _paymentRow('Security Deposit', fmt(securityDeposit), tc: tc),
          Divider(height: 24, color: tc.border),
          _paymentRow('Total', fmt(_booking.totalAmount), isBold: true, tc: tc),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String value, {bool isBold = false, required ThemeColors tc}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isBold ? tc.text : tc.subtitle, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, color: isBold ? AppColors.primary : tc.text, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEscrowTimeline(ThemeColors tc) {
    final escrowStatus = _escrow?.status ?? 'pending';
    final fundedAt = _escrow?.fundedAt;
    final releasedAt = _escrow?.releasedAt;
    final createdAt = _escrow?.createdAt ?? _booking.createdAt;
    final isInspectionActive = _booking.inspectionHoursLeft != null;

    String _formatDate(String? iso) {
      if (iso == null) return '';
      try {
        final dt = DateTime.parse(iso);
        return '${dt.month}/${dt.day}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return iso;
      }
    }

    final steps = [
      {'label': 'Booking Confirmed', 'status': 'completed', 'time': _formatDate(createdAt)},
      {'label': 'Inspection Window', 'status': isInspectionActive ? 'active' : (_booking.status == 'pending' ? 'pending' : 'completed'), 'time': isInspectionActive ? '${_booking.inspectionHoursLeft}h left' : ''},
      {'label': 'Payment in Escrow', 'status': fundedAt != null ? 'completed' : (escrowStatus == 'funded' ? 'active' : 'pending'), 'time': _formatDate(fundedAt)},
      {'label': 'Lease Finalized', 'status': releasedAt != null ? 'completed' : (escrowStatus == 'released' ? 'completed' : 'pending'), 'time': _formatDate(releasedAt)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Escrow Timeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.subtitle)),
          const SizedBox(height: 16),
          ...steps.map((s) {
            final isCompleted = s['status'] == 'completed';
            final isActive = s['status'] == 'active';
            final color = isCompleted ? AppColors.success : isActive ? AppColors.primary : AppColors.border;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.success : isActive ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : isActive
                              ? Container(margin: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                              : null,
                    ),
                    Container(width: 2, height: 30, color: color),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['label']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : tc.text)),
                      if ((s['time'] as String).isNotEmpty)
                        Text(s['time']!, style: TextStyle(fontSize: 12, color: tc.hint)),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ThemeColors tc) {
    if (_booking.status == 'completed') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => RatingScreen(
            agentName: 'Sarah Johnson',
            propertyTitle: _booking.propertyTitle,
            bookingRef: _booking.reference,
            propertyId: _booking.propertyId ?? '',
          ),
        )),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.rating, Color(0xFFF59E0B)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 22, color: Colors.white),
              SizedBox(width: 8),
              Text('Rate Agent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: tc.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: Text('Contact Agent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: _isCancelling ? null : _cancelBooking,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _isCancelling ? AppColors.border : AppColors.error,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              alignment: Alignment.center,
              child: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: ApexLoading(size: 18),
                    )
                  : const Text('Cancel Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label, String value, ThemeColors tc) {
    return Row(
      children: [
        Icon(icon, size: 16, color: tc.subtitle),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: tc.hint)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.text)),
          ],
        ),
      ],
    );
  }
}
