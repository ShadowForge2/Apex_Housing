import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';
import '../../services/token_storage.dart';

class AdminGroupManageScreen extends StatefulWidget {
  final String currentAdminId;
  final ValueChanged<List<Map<String, dynamic>>> onMembersChanged;

  const AdminGroupManageScreen({
    super.key,
    required this.currentAdminId,
    required this.onMembersChanged,
  });

  @override
  State<AdminGroupManageScreen> createState() => _AdminGroupManageScreenState();
}

class _AdminGroupManageScreenState extends State<AdminGroupManageScreen> {
  final AdminService _adminService = AdminService();
  final TokenStorage _storage = TokenStorage();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _currentUserId = '';
  bool _isSuperAdmin = false;

  List<Map<String, dynamic>> _groupMembers = [];
  List<Map<String, dynamic>> _allAdmins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _currentUserId = (await _storage.getUserId()) ?? '';
    _isSuperAdmin = await _storage.getIsSuperAdmin();
    try {
      final chatResult = await _adminService.getAdminGroupChat();
      final data = chatResult['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        _groupMembers = List<Map<String, dynamic>>.from(data['members'] ?? []);
        _allAdmins = List.from(_groupMembers);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _inGroup => _groupMembers;
  List<Map<String, dynamic>> get _filteredInGroup {
    if (_searchQuery.isEmpty) return _inGroup;
    return _inGroup.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _addMember(Map<String, dynamic> member) async {
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can manage group members'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userId = member['id'];
    try {
      await runWithLoading(
        context,
        action: () => _adminService.addGroupChatMember(userId),
        message: 'Adding member...',
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member['name']} added to group'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can manage group members'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userId = member['id'];
    try {
      await runWithLoading(
        context,
        action: () => _adminService.removeGroupChatMember(userId),
        message: 'Removing member...',
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member['name']} removed from group'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final isCurrentUser = member['id'] == _currentUserId;
    final isSuperAdminMember = member['is_super_admin'] == true;
    final name = member['name'] ?? 'Unknown';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadow.minimal,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (isSuperAdminMember ? AppColors.primary : AppColors.subtitle).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSuperAdminMember ? AppColors.primary : AppColors.subtitle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.xsAll,
                        ),
                        child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isSuperAdminMember ? AppColors.primary : AppColors.subtitle).withValues(alpha: 0.1),
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Text(
                    isSuperAdminMember ? 'Super Admin' : 'Admin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSuperAdminMember ? AppColors.primary : AppColors.subtitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSuperAdmin && !isCurrentUser)
            IconButton(
              onPressed: () => _confirmRemove(member),
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
            ),
        ],
      ),
    );
  }

  void _confirmRemove(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Remove from Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('Remove ${member['name']} from the admin group chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredInGroup;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Group Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (!_isSuperAdmin)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only Super Admin can add or remove group members.',
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: const TextStyle(color: AppColors.hint),
                      prefixIcon: const Icon(Icons.search, color: AppColors.hint),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.hint),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildStat('Members', _inGroup.length, AppColors.success),
                      const SizedBox(width: 8),
                      _buildStat('Super Admin', _inGroup.where((m) => m['is_super_admin'] == true).length, AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredMembers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_off, size: 40, color: AppColors.hint.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('No members found', style: TextStyle(fontSize: 13, color: AppColors.hint)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) => _buildMemberCard(filteredMembers[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.smAll,
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
