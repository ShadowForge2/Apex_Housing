import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BridgeAPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w * 0.05, h * 0.85);
    path.lineTo(w * 0.2, h * 0.85);
    path.lineTo(w * 0.5, h * 0.22);
    path.lineTo(w * 0.8, h * 0.85);
    path.lineTo(w * 0.95, h * 0.85);
    path.close();
    canvas.drawPath(path, paint);

    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.52, w * 0.76, h * 0.08),
      const Radius.circular(4),
    );
    canvas.drawRRect(bar, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ApexLoading extends StatefulWidget {
  final double size;
  final String? label;

  const ApexLoading({super.key, this.size = 52, this.label});

  @override
  State<ApexLoading> createState() => _ApexLoadingState();
}

class _ApexLoadingState extends State<ApexLoading>
    with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bridgeAWidth = widget.size * 0.55;
    final bridgeAHeight = widget.size * 0.55;

    return AnimatedBuilder(
      animation: Listenable.merge([_sweepController, _pulseController]),
      builder: (_, __) {
        final pulse = 0.94 + (_pulseController.value * 0.06);
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              stops: [
                (_sweepController.value - 0.3).clamp(0.0, 1.0),
                _sweepController.value,
                (_sweepController.value + 0.3).clamp(0.0, 1.0),
                (_sweepController.value + 0.6).clamp(0.0, 1.0),
              ],
              colors: const [
                Colors.transparent,
                AppColors.primary,
                AppColors.primaryLight,
                Colors.transparent,
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Transform.scale(
            scale: pulse,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size(bridgeAWidth, bridgeAHeight),
                  painter: BridgeAPainter(),
                ),
                const SizedBox(height: 0),
                Text(
                  "pex",
                  style: GoogleFonts.caveat(
                    fontSize: widget.size * 0.42,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ApexLoadingFull extends StatelessWidget {
  final String? label;

  const ApexLoadingFull({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.94),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ApexLoading(),
            const SizedBox(height: 20),
            Text(
              label ?? "Loading...",
              style: GoogleFonts.caveat(
                color: AppColors.subtitle,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
