import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/loading_overlay.dart';

class TenantDetailScreen extends StatelessWidget {
  final String name;
  final String property;
  final int rent;
  final String leaseEnd;
  final String status;
  final String avatar;
  final String tenantSince;

  const TenantDetailScreen({
    super.key,
    required this.name,
    required this.property,
    required this.rent,
    required this.leaseEnd,
    required this.status,
    required this.avatar,
    this.tenantSince = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tenant Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildLeaseInfo(),
            const SizedBox(height: 20),
            _buildPaymentHistory(context),
            const SizedBox(height: 20),
            _buildActions(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final statusColor = status == 'active' ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.lightPurple,
            child: Text(avatar, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 22)),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(property, style: const TextStyle(fontSize: 14, color: AppColors.subtitle)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              status == 'active' ? 'Active Tenant' : 'Notice Period',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaseInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lease Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 16),
          _infoRow(Icons.payments_rounded, 'Monthly Rent', '₦${rent.toString().replaceAll(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), ',')}'),
          const SizedBox(height: 14),
          _infoRow(Icons.calendar_today_rounded, 'Lease Ends', leaseEnd),
          const SizedBox(height: 14),
          _infoRow(Icons.home_rounded, 'Property', property),
          const SizedBox(height: 14),
          _infoRow(Icons.date_range_rounded, 'Tenant Since', tenantSince.isNotEmpty ? tenantSince : '—'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.subtitle))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }

  Widget _buildPaymentHistory(BuildContext context) {
    final payments = <Map<String, String>>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const Spacer(),
              TextButton(
                onPressed: () => showApexLoading(context, duration: const Duration(milliseconds: 800), label: 'Loading...'),
                child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...payments.map((p) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['amount']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                        Text('${p['month']} • Paid on ${p['date']}', style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.text),
                SizedBox(width: 8),
                Text('Message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_outlined, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Call', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
