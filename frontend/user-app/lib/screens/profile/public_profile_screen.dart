import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../services/token_storage.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/apex_loading.dart';
import '../messages/chat_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String name;
  final String initials;
  final String role;
  final String userId;
  final double rating;
  final int totalListings;
  final String memberSince;
  final String city;
  final bool isOnline;

  const PublicProfileScreen({
    super.key,
    required this.name,
    required this.initials,
    required this.role,
    this.userId = '',
    this.rating = 0,
    this.totalListings = 0,
    this.memberSince = '',
    this.city = '',
    this.isOnline = false,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _publicProfile;
  bool _isLoadingProfile = true;
  String? _currentUserId;
  String _currentRole = '';
  bool _isAgentViewingAgent = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      _currentUserId = await TokenStorage().getUserId();
      _currentRole = (await TokenStorage().getUserRole()) ?? '';

      if (widget.userId.isNotEmpty) {
        final response = await ApiClient.instance.get('/users/${widget.userId}/public');
        final data = response.data;
        if (data is Map && data['data'] is Map) {
          _publicProfile = Map<String, dynamic>.from(data['data']);
        }
      }

      final viewerIsLandlord = _currentRole.toUpperCase() == 'LANDLORD';
      final targetIsLandlord = (widget.role.toUpperCase() == 'LANDLORD') ||
          (_publicProfile?['role']?.toString().toUpperCase() == 'LANDLORD');

      _isAgentViewingAgent = viewerIsLandlord && targetIsLandlord && widget.userId != _currentUserId;
    } catch (e) {
      debugPrint('PublicProfile: Failed to load profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final displayRating = _publicProfile?['avg_rating'] != null
        ? (_publicProfile!['avg_rating'] as num).toDouble()
        : widget.rating;
    final displayRatingCount = _publicProfile?['rating_count'] ?? 0;
    final displayListings = _publicProfile?['total_properties'] ?? widget.totalListings;
    final displayRole = _publicProfile?['role'] ?? widget.role;
    final displayName = _publicProfile?['name'] ?? widget.name;
    final displayVerified = _publicProfile?['is_verified'] ?? false;

    final memberSinceStr = _publicProfile?['created_at'] != null
        ? _formatMemberSince(_publicProfile!['created_at'])
        : widget.memberSince;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text(_isAgentViewingAgent ? 'Agent Profile' : 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isAgentViewingAgent)
            IconButton(
              icon: Icon(Icons.flag_outlined, size: 22, color: tc.hint),
              onPressed: () => showApexLoading(context, duration: const Duration(milliseconds: 800), label: 'Reporting...'),
            ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: ApexLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildAvatar(tc, displayName),
                  const SizedBox(height: 18),
                  Text(displayName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tc.text)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: displayRole.toString().toUpperCase() == 'LANDLORD'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.lightPurple,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          displayRole.toString().toUpperCase() == 'LANDLORD' ? 'Agent' : 'Tenant',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: displayRole.toString().toUpperCase() == 'LANDLORD'
                                ? AppColors.primaryDark
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      if (displayVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.success),
                              SizedBox(width: 3),
                              Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildStatsRow(tc, displayRating, displayRatingCount as int, displayListings as int, memberSinceStr),
                  if (_isAgentViewingAgent) ...[
                    const SizedBox(height: 28),
                    _buildAgentLimitedInfo(tc, displayName, displayRole.toString()),
                  ] else ...[
                    const SizedBox(height: 28),
                    _buildInfoSection(tc, displayName, displayRole.toString()),
                  ],
                  if (!_isAgentViewingAgent) ...[
                    const SizedBox(height: 32),
                    _buildActionButtons(context, tc, displayName, displayRole.toString()),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  String _formatMemberSince(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildAvatar(ThemeColors tc, String displayName) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.primary,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(ThemeColors tc, double liveRating, int ratingCount, int listings, String memberSince) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(Icons.star_rounded, liveRating > 0 ? liveRating.toStringAsFixed(1) : '—', liveRating > 0 ? '$ratingCount ratings' : 'No ratings', tc, color: AppColors.rating),
          Container(width: 1, height: 32, color: tc.border),
          _statItem(Icons.home_work_outlined, '$listings', 'Listings', tc, color: AppColors.primary),
          Container(width: 1, height: 32, color: tc.border),
          _statItem(Icons.calendar_today_rounded, memberSince.isNotEmpty ? memberSince : '—', 'Member Since', tc, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, ThemeColors tc, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? tc.hint),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: tc.hint)),
      ],
    );
  }

  Widget _buildAgentLimitedInfo(ThemeColors tc, String name, String role) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Agent Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tc.text)),
          ),
          _infoTile(Icons.business_outlined, 'Agent', name, tc),
          _infoTile(Icons.star_outline_rounded, 'Average Price Point', 'See listings for pricing', tc),
          _infoTile(Icons.shield_outlined, 'Platform Rating', 'Based on tenant reviews', tc),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You can view this agent\'s listings to compare pricing, but direct messaging is only available between agents and tenants.',
                style: TextStyle(fontSize: 12, color: tc.subtitle, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeColors tc, String name, String role) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tc.text)),
          ),
          if (widget.userId.isNotEmpty)
            _infoTile(Icons.fingerprint_rounded, 'User ID', widget.userId, tc),
          _infoTile(Icons.verified_rounded, 'Verified Account', 'Identity verified by APEX Housing', tc),
          _infoTile(Icons.shield_rounded, 'Escrow Protected', 'All transactions are secured via escrow', tc),
          _infoTile(Icons.access_time_rounded, 'Response Time', 'Usually responds within 2 hours', tc),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: tc.subtitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(ThemeColors tc, List<Map<String, dynamic>> ratings) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Reviews (${ratings.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tc.text)),
          ),
          ...ratings.map((r) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text((r['tenantName'] as String)[0],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r['tenantName'] as String,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.text)),
                    ),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < (r['rating'] as int) ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14,
                        color: i < (r['rating'] as int) ? AppColors.rating : AppColors.border,
                      )),
                    ),
                  ],
                ),
                if ((r['review'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r['review'] as String,
                      style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text(r['date'] as String, style: TextStyle(fontSize: 11, color: tc.hint)),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeColors tc, String name, String role) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              try {
                final response = await ApiClient.instance.post('/messages/conversations', data: {
                  'participant_ids': [widget.userId],
                });
                final data = response.data;
                final convId = data is Map ? (data['data']?['id'] ?? '') : '';
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      name: name,
                      conversationId: convId.toString(),
                      otherUserId: widget.userId,
                      otherUserRole: role,
                    ),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to start chat: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
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
                  Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Message', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
