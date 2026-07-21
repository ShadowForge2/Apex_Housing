import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AdminSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const AdminSplashScreen({super.key, required this.onComplete});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Phase 2: switch to loading screen at 3s
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLoading = true;
        });
      }
    });

    // Complete after 5s total
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: _showLoading ? _buildLoadingPhase() : _buildLogoPhase(),
    );
  }

  Widget _buildLogoPhase() {
    return Container(
      key: const ValueKey('logo'),
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF5B21B6),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Image.asset(
            'assets/images/apex_no_bg.png',
            width: 220,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPhase() {
    return Container(
      key: const ValueKey('loading'),
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading admin panel...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.text,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
