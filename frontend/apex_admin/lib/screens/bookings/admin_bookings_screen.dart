import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_models.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _searchController = TextEditingController();
  int _selectedFilter = 0;
  String _searchQuery = '';
  List<AdminBooking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final response = await AdminService().listBookings();
      final data = response['data'];
      if (data != null && mounted) {
        final bookingsList = data['bookings'] as List<dynamic>? ?? [];
        setState(() {
          _bookings = bookingsList.map<AdminBooking>((b) {
            return AdminBooking(
              reference: b['reference'] as String? ?? 'BK-0000',
              tenantName: b['tenant_name'] as String? ?? 'Unknown',
              landlordName: b['landlord_name'] as String? ?? 'Unknown',
              property: b['property'] as String? ?? 'Unknown',
              amount: (b['amount'] as num?)?.toDouble() ?? 0.0,
              status: _parseBookingStatus(b['status'] as String? ?? 'active'),
              date: b['date'] as String? ?? '',
              escrowStatus: b['escrow_status'] as String? ?? 'held',
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _bookings = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load bookings. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  BookingStatus _parseBookingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return BookingStatus.completed;
      case 'disputed': return BookingStatus.disputed;
      case 'cancelled': return BookingStatus.cancelled;
      default: return BookingStatus.active;
    }
  }

  static const _filters = ['All', 'Active', 'Completed', 'Disputed', 'Cancelled'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminBooking> get _filteredBookings {
    var list = _bookings.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (b) =>
                b.reference.toLowerCase().contains(q) ||
                b.tenantName.toLowerCase().contains(q) ||
                b.landlordName.toLowerCase().contains(q) ||
                b.property.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_selectedFilter > 0) {
      final statusFilter = {
        1: BookingStatus.active,
        2: BookingStatus.completed,
        3: BookingStatus.disputed,
        4: BookingStatus.cancelled,
      }[_selectedFilter]!;
      list = list.where((b) => b.status == statusFilter).toList();
    }

    return list;
  }

  Color _statusColor(BookingStatus status) => switch (status) {
    BookingStatus.active => AppColors.success,
    BookingStatus.completed => AppColors.primary,
    BookingStatus.disputed => AppColors.error,
    BookingStatus.cancelled => AppColors.subtitle,
  };

  Color _statusBg(BookingStatus status) => switch (status) {
    BookingStatus.active => AppColors.successLight,
    BookingStatus.completed => AppColors.lightPurple,
    BookingStatus.disputed => AppColors.errorLight,
    BookingStatus.cancelled => AppColors.borderLight,
  };

  String _statusLabel(BookingStatus status) => switch (status) {
    BookingStatus.active => 'Active',
    BookingStatus.completed => 'Completed',
    BookingStatus.disputed => 'Disputed',
    BookingStatus.cancelled => 'Cancelled',
  };

  void _showDetailBottomSheet(AdminBooking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: booking),
    );
  }

  void _showDisputeDialog(AdminBooking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Open Dispute', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open a dispute for ${booking.reference}?',
              style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
            ),
            const SizedBox(height: 4),
            Text(
              booking.property,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...['Payment issue', 'Property condition', 'Landlord dispute', 'Escrow hold', 'Other'].map(
              (reason) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                leading: Icon(Icons.circle_outlined, size: 18, color: AppColors.hint),
                onTap: () async {
                  Navigator.pop(context);
                  await runWithLoading(
                    context,
                    action: () async {
                      await Future.delayed(const Duration(milliseconds: 800));
                      setState(() {
                        final index = _bookings.indexWhere((b) => b.reference == booking.reference);
                        if (index != -1) {
                          _bookings[index] = AdminBooking(
                            reference: booking.reference,
                            tenantName: booking.tenantName,
                            landlordName: booking.landlordName,
                            property: booking.property,
                            amount: booking.amount,
                            status: BookingStatus.disputed,
                            date: booking.date,
                            escrowStatus: 'Held',
                          );
                        }
                      });
                    },
                    message: 'Opening dispute...',
                  );
                  if (context.mounted) {
                    showAppToast(context, 'Dispute opened for ${booking.reference}', backgroundColor: AppColors.error);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 15, color: AppColors.subtitle), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchBookings(); }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bookings = _filteredBookings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Bookings Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search bookings...',
                prefixIcon: const Icon(Icons.search, color: AppColors.hint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Container(
            height: 40,
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _selectedFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.textWhite : AppColors.subtitle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bookings.isEmpty
                ? const Center(
                    child: Text('No bookings found', style: TextStyle(color: AppColors.hint)),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchBookings,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _BookingCard(
                        booking: bookings[i],
                        onView: () => _showDetailBottomSheet(bookings[i]),
                        onDispute: () => _showDisputeDialog(bookings[i]),
                        statusColor: _statusColor(bookings[i].status),
                        statusBg: _statusBg(bookings[i].status),
                        statusLabel: _statusLabel(bookings[i].status),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final AdminBooking booking;
  final VoidCallback onView;
  final VoidCallback onDispute;
  final Color statusColor;
  final Color statusBg;
  final String statusLabel;

  const _BookingCard({
    required this.booking,
    required this.onView,
    required this.onDispute,
    required this.statusColor,
    required this.statusBg,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.minimal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.reference,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.person_outline, '${booking.tenantName}  →  ${booking.landlordName}'),
          const SizedBox(height: 6),
          _infoRow(Icons.home_outlined, booking.property),
          const SizedBox(height: 6),
          _infoRow(Icons.account_balance_wallet_outlined, '₦${_formatAmount(booking.amount)}'),
          const SizedBox(height: 6),
          _infoRow(Icons.calendar_today_outlined, booking.date),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: AppColors.subtitle),
              const SizedBox(width: 6),
              Text(
                'Escrow: ${booking.escrowStatus}',
                style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDispute,
                  icon: const Icon(Icons.report_outlined, size: 16),
                  label: const Text('Dispute'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.subtitle),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
      buf.write(parts[i]);
    }
    return buf.toString();
  }
}

class _BookingDetailSheet extends StatelessWidget {
  final AdminBooking booking;
  const _BookingDetailSheet({required this.booking});

  Color _statusColor(BookingStatus status) => switch (status) {
    BookingStatus.active => AppColors.success,
    BookingStatus.completed => AppColors.primary,
    BookingStatus.disputed => AppColors.error,
    BookingStatus.cancelled => AppColors.subtitle,
  };

  Color _statusBg(BookingStatus status) => switch (status) {
    BookingStatus.active => AppColors.successLight,
    BookingStatus.completed => AppColors.lightPurple,
    BookingStatus.disputed => AppColors.errorLight,
    BookingStatus.cancelled => AppColors.borderLight,
  };

  String _statusLabel(BookingStatus status) => switch (status) {
    BookingStatus.active => 'Active',
    BookingStatus.completed => 'Completed',
    BookingStatus.disputed => 'Disputed',
    BookingStatus.cancelled => 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status);
    final bg = _statusBg(booking.status);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.reference,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _statusLabel(booking.status),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _detailTile('Tenant', booking.tenantName, Icons.person_outline),
              _detailTile('Landlord', booking.landlordName, Icons.person_outline),
              _detailTile('Property', booking.property, Icons.home_outlined),
              _detailTile('Amount', '₦${booking.amount.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined),
              _detailTile('Date', booking.date, Icons.calendar_today_outlined),
              _detailTile('Escrow Status', booking.escrowStatus, Icons.lock_outline),
            ],
          );
        },
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.subtitle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
