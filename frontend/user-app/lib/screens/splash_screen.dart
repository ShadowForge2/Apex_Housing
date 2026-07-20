import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../widgets/apex_loading.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  bool _showLogo = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: _showLogo ? const Color(0xFF5B21B6) : tc.card,
        child: Center(
          child: _showLogo
              ? FadeTransition(
                  opacity: _fade,
                  child: Image.asset(
                    'assets/images/apex_no_bg.png',
                    width: 220,
                  ),
                )
              : const ApexLoading(size: 64),
        ),
      ),
    );
  }
}
