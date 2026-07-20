import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_models.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';
import '../../services/exceptions.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  late List<AdminKycEntry> _kycQueue;
  String _searchQuery = '';
  int _selectedFilter = 0;
  bool _isLoading = true;
  String? _error;

  static const _filters = ['All', 'Needs Review', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _kycQueue = [];
    _fetchKyc();
  }

  Future<void> _fetchKyc() async {
    try {
      final response = await AdminService().listPendingKyc();
      final data = response['data'];
      if (data != null && mounted) {
        final kycList = data['kyc_entries'] as List<dynamic>? ?? [];
        setState(() {
          _kycQueue = kycList.map<AdminKycEntry>((k) => AdminKycEntry(
            name: '${k['first_name'] ?? ''} ${k['last_name'] ?? ''}'.trim(),
            userId: k['user_id'] as String? ?? '',
            role: _parseRole(k['role'] as String? ?? 'tenant'),
            documentType: k['document_type'] as String? ?? '',
            submittedDate: k['submitted_date'] as String? ?? '',
            status: _parseKycStatus(k['status'] as String? ?? 'pending'),
            avatarUrl: k['document_url'] as String? ?? '',
          )).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _kycQueue = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load KYC entries. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  UserRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'landlord': return UserRole.landlord;
      case 'agent': return UserRole.agent;
      default: return UserRole.tenant;
    }
  }

  KycStatus _parseKycStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified': return KycStatus.verified;
      case 'rejected': return KycStatus.rejected;
      default: return KycStatus.pending;
    }
  }

  int get _pendingCount => _kycQueue.where((e) => e.status == KycStatus.pending).length;
  int get _autoVerifiedCount => _kycQueue.where((e) => e.status == KycStatus.verified).length;
  int get _rejectedCount => _kycQueue.where((e) => e.status == KycStatus.rejected).length;

  List<AdminKycEntry> get _filteredEntries {
    var list = _kycQueue.toList();

    if (_selectedFilter > 0) {
      final statusMap = {
        1: KycStatus.pending,
        2: KycStatus.rejected,
      };
      list = list.where((e) => e.status == statusMap[_selectedFilter]).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.userId.toLowerCase().contains(q) ||
                e.documentType.toLowerCase().contains(q),
          )
          .toList();
    }

    return list;
  }

  void _showConfirmDialog(AdminKycEntry entry, bool approve) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(approve ? 'Clear KYC Issue' : 'Reject KYC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${approve ? 'Clear the issue and approve' : 'Reject'} KYC for ${entry.name}?',
              style: const TextStyle(fontSize: 14, color: AppColors.text),
            ),
            if (!approve) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Rejection reason (optional)',
                  hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  try {
                    await AdminService().approveKyc(entry.userId, approve, rejectionReason: approve ? null : reasonController.text);
                    setState(() {
                      final index = _kycQueue.indexWhere((e) => e.userId == entry.userId);
                      if (index != -1) {
                        _kycQueue[index] = AdminKycEntry(
                          name: entry.name,
                          userId: entry.userId,
                          role: entry.role,
                          documentType: entry.documentType,
                          submittedDate: entry.submittedDate,
                          status: approve ? KycStatus.verified : KycStatus.rejected,
                          avatarUrl: entry.avatarUrl,
                        );
                      }
                    });
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Operation failed: ${e.toString()}'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                message: approve ? 'Approving KYC...' : 'Rejecting KYC...',
              );
              if (context.mounted) {
                showAppToast(
                  context,
                  'KYC ${approve ? "approved" : "rejected"} for ${entry.name}',
                  backgroundColor: approve ? AppColors.success : AppColors.error,
                );
              }
            },
            child: Text(
              approve ? 'Clear' : 'Reject',
              style: TextStyle(
                color: approve ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentSheet(AdminKycEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KycDocumentSheet(
        entry: entry,
        onApprove: () {
          Navigator.pop(context);
          _showConfirmDialog(entry, true);
        },
        onReject: () {
          Navigator.pop(context);
          _showConfirmDialog(entry, false);
        },
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
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchKyc(); }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final entries = _filteredEntries;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('KYC Manual Review', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Row(
              children: [
                _statCard('Needs Review', _pendingCount, AppColors.warning, AppColors.warningLight),
                const SizedBox(width: 10),
                _statCard('Auto-Verified', _autoVerifiedCount, AppColors.success, AppColors.successLight),
                const SizedBox(width: 10),
                _statCard('Rejected', _rejectedCount, AppColors.error, AppColors.errorLight),
              ],
            ),
          ),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, document type...',
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.hint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _searchQuery = ''),
                        child: const Icon(Icons.close, size: 18, color: AppColors.hint),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
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
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 56, color: AppColors.hint),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No entries match your search' : 'No KYC entries found',
                          style: const TextStyle(fontSize: 15, color: AppColors.subtitle),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchKyc,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _KycCard(
                        entry: entries[i],
                        onApprove: () => _showConfirmDialog(entries[i], true),
                        onReject: () => _showConfirmDialog(entries[i], false),
                        onViewDoc: () => _showDocumentSheet(entries[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _KycCard extends StatelessWidget {
  final AdminKycEntry entry;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDoc;

  const _KycCard({
    required this.entry,
    required this.onApprove,
    required this.onReject,
    required this.onViewDoc,
  });

  Color _statusColor(KycStatus status) => switch (status) {
    KycStatus.pending => AppColors.warning,
    KycStatus.verified => AppColors.success,
    KycStatus.rejected => AppColors.error,
  };

  Color _statusBg(KycStatus status) => switch (status) {
    KycStatus.pending => AppColors.warningLight,
    KycStatus.verified => AppColors.successLight,
    KycStatus.rejected => AppColors.errorLight,
  };

  String _statusLabel(KycStatus status) => switch (status) {
    KycStatus.pending => 'Pending',
    KycStatus.verified => 'Verified',
    KycStatus.rejected => 'Rejected',
  };

  Color _roleColor(UserRole role) => switch (role) {
    UserRole.tenant => AppColors.primary,
    UserRole.landlord => AppColors.success,
    UserRole.agent => AppColors.warning,
  };

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.tenant => 'Tenant',
    UserRole.landlord => 'Landlord',
    UserRole.agent => 'Agent',
  };

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(entry.status);
    final sBg = _statusBg(entry.status);
    final rColor = _roleColor(entry.role);

    return GestureDetector(
      onTap: entry.status == KycStatus.pending ? onViewDoc : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.minimal,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: rColor.withValues(alpha: 0.1),
              child: Text(
                _initials(entry.name),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: rColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          _statusLabel(entry.status),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(entry.userId, style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: rColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          _roleLabel(entry.role),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: rColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 12, color: AppColors.hint),
                      const SizedBox(width: 4),
                      Text(entry.documentType, style: const TextStyle(fontSize: 11, color: AppColors.subtitle)),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.hint),
                      const SizedBox(width: 4),
                      Text(entry.submittedDate, style: const TextStyle(fontSize: 10, color: AppColors.hint)),
                    ],
                  ),
                  if (entry.status == KycStatus.pending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: onApprove,
                              icon: const Icon(Icons.check, size: 15),
                              label: const Text('Clear', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.textWhite,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: onReject,
                              icon: const Icon(Icons.close, size: 15),
                              label: const Text('Reject', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.textWhite,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          width: 32,
                          child: OutlinedButton(
                            onPressed: onViewDoc,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                            ),
                            child: const Icon(Icons.visibility_outlined, size: 15, color: AppColors.subtitle),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KycDocumentSheet extends StatelessWidget {
  final AdminKycEntry entry;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _KycDocumentSheet({
    required this.entry,
    required this.onApprove,
    required this.onReject,
  });

  Color _roleColor(UserRole role) => switch (role) {
    UserRole.tenant => AppColors.primary,
    UserRole.landlord => AppColors.success,
    UserRole.agent => AppColors.warning,
  };

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.tenant => 'Tenant',
    UserRole.landlord => 'Landlord',
    UserRole.agent => 'Agent',
  };

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0][0];
  }

  @override
  Widget build(BuildContext context) {
    final rColor = _roleColor(entry.role);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: rColor.withValues(alpha: 0.1),
                    child: Text(
                      _initials(entry.name),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: rColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(entry.userId, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: rColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                _roleLabel(entry.role),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: rColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Submitted Document',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined, size: 20, color: rColor),
                        const SizedBox(width: 8),
                        Text(
                          entry.documentType,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Document submitted on ${entry.submittedDate}',
                      style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined, size: 32, color: AppColors.hint),
                            SizedBox(height: 4),
                            Text('Document preview', style: TextStyle(fontSize: 12, color: AppColors.hint)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Full Name', entry.name),
              const SizedBox(height: 8),
              _infoRow('User ID', entry.userId),
              const SizedBox(height: 8),
              _infoRow('Role', _roleLabel(entry.role)),
              const SizedBox(height: 8),
              _infoRow('Document Type', entry.documentType),
              const SizedBox(height: 8),
              _infoRow('Submitted', entry.submittedDate),
              if (entry.status != KycStatus.pending) ...[
                const SizedBox(height: 8),
                _infoRow(
                  'Status',
                  entry.status == KycStatus.verified ? 'Verified' : 'Rejected',
                ),
              ],
              const SizedBox(height: 24),
              if (entry.status == KycStatus.pending)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.textWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
