import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../models/models.dart';
import '../../services/booking_service.dart';
import '../../widgets/booking_card.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _bookingService = BookingService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final models = await _bookingService.listBookings();
      _bookings = models.map(_toBooking).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Booking _toBooking(BookingModel b) {
    return Booking(
      id: b.id,
      propertyId: b.propertyId,
      reference: 'APX-${b.id.length > 8 ? b.id.substring(0, 8) : b.id}',
      propertyTitle: 'Property ${b.propertyId ?? ''}',
      propertyImage: '',
      status: b.status ?? 'pending',
      totalAmount: 0,
      moveInDate: b.moveInDate ?? '—',
      createdAt: b.createdAt ?? '—',
      escrowStatus: 'pending',
      inspectionHoursLeft: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: const [
                Text('My Bookings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: tc.border),
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: tc.subtitle,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Confirmed'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: ApexLoading())
                : _error != null
                    ? _buildErrorState(tc)
                    : TabBarView(
                        children: [0, 1, 2, 3].map((statusFilter) {
                          final filtered = _bookings.where((b) {
                            if (statusFilter == 0) return b.status == 'pending';
                            if (statusFilter == 1) return b.status == 'confirmed';
                            if (statusFilter == 2) return b.status == 'completed';
                            return b.status == 'cancelled';
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(color: tc.surface, shape: BoxShape.circle),
                                    child: Icon(
                                      statusFilter == 0
                                          ? Icons.pending_outlined
                                          : statusFilter == 1
                                              ? Icons.check_circle_outline
                                              : statusFilter == 2
                                                  ? Icons.celebration_outlined
                                                  : Icons.cancel_outlined,
                                      size: 32,
                                      color: tc.hint,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    statusFilter == 0
                                        ? 'No pending bookings'
                                        : statusFilter == 1
                                            ? 'No confirmed bookings'
                                            : statusFilter == 2
                                                ? 'No completed bookings'
                                                : 'No cancelled bookings',
                                    style: TextStyle(color: tc.subtitle, fontSize: 15),
                                  ),
                                ],
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: _fetchBookings,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (ctx, i) => BookingCard(
                                booking: filtered[i],
                                onTap: () => Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailScreen(booking: filtered[i]),
                                  ),
                                ).then((_) => _fetchBookings()),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeColors tc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text('Unable to connect', style: TextStyle(color: tc.subtitle, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Check your connection and try again', style: TextStyle(color: tc.hint, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _fetchBookings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
