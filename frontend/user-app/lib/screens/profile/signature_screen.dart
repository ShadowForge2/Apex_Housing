import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/apex_loading.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/user_service.dart';
import 'bank_account_screen.dart';

class SignatureScreen extends StatefulWidget {
  final bool isPostSignup;
  const SignatureScreen({super.key, this.isPostSignup = false});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _signatureKey = GlobalKey<SignatureState>();
  bool _hasSignature = false;
  bool _savedSignature = false;
  bool _isLoading = true;
  bool _isSaving = false;
  int _strokeVersion = 0;
  String? _savedAt;

  @override
  void initState() {
    super.initState();
    _loadExistingSignature();
  }

  Future<void> _loadExistingSignature() async {
    try {
      final sig = await UserService().getMySignature();
      if (mounted) {
        setState(() {
          _savedSignature = sig.data != null && sig.data!.isNotEmpty;
          _hasSignature = _savedSignature;
          _savedAt = sig.createdAt;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSignature() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final state = _signatureKey.currentState;
      if (state == null) return;
      final data = await state.toBase64Png();
      if (data == null || data.isEmpty) return;

      await UserService().saveSignature(signatureData: 'data:image/png;base64,$data');
      if (mounted) {
        setState(() {
          _savedSignature = true;
          _savedAt = DateTime.now().toIso8601String();
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Signature saved successfully'),
            ]),
            backgroundColor: AppColors.success,
          ),
        );

        if (widget.isPostSignup && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const BankAccountScreen(isPostSignup: true),
            ),
            (route) => route.isFirst,
          );
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Signature'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: ApexLoading())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (_savedSignature) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 22, color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Signature Saved', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                                const SizedBox(height: 2),
                                Text(
                                  _savedAt != null ? 'Last updated: ${_savedAt!.substring(0, 10)}' : 'Your signature is on file',
                                  style: TextStyle(fontSize: 12, color: AppColors.success.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text('EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tc.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your digital signature will be used on lease agreements and booking confirmations.',
                              style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(_savedSignature ? 'Update your signature' : 'Draw your signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tc.text)),
                  const SizedBox(height: 4),
                  Text('Sign in the box below', style: TextStyle(fontSize: 13, color: tc.hint)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: _hasSignature ? AppColors.primary.withValues(alpha: 0.4) : tc.border, width: 2),
                        boxShadow: AppShadow.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: Signature(
                          key: _signatureKey,
                          onSigned: () {
                            if (!_hasSignature) setState(() => _hasSignature = true);
                            setState(() {
                              _strokeVersion++;
                              _savedSignature = false;
                            });
                          },
                          version: _strokeVersion,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Clear',
                          onPressed: () {
                            _signatureKey.currentState?.clear();
                            setState(() => _hasSignature = false);
                          },
                          isOutlined: true,
                          color: tc.text,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppButton(
                          text: _savedSignature ? 'Update Signature' : 'Save Signature',
                          onPressed: _hasSignature && !_isSaving ? _saveSignature : null,
                          icon: Icons.check_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class Signature extends StatefulWidget {
  final VoidCallback? onSigned;
  final int version;
  const Signature({super.key, this.onSigned, this.version = 0});

  @override
  SignatureState createState() => SignatureState();
}

class SignatureState extends State<Signature> {
  final List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  int _version = 0;
  final GlobalKey _repaintKey = GlobalKey();

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _version++;
    });
  }

  Future<String?> toBase64Png() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = boundary.toImageSync(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      if (bytes.isEmpty) return null;

      final hasContent = _strokes.isNotEmpty;
      return hasContent ? base64Encode(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        final box = context.findRenderObject() as RenderBox;
        final point = box.globalToLocal(details.globalPosition);
        setState(() {
          _currentStroke = Stroke(points: [point], speed: 0);
          _strokes.add(_currentStroke!);
          _version++;
        });
        widget.onSigned?.call();
      },
      onPanUpdate: (details) {
        if (_currentStroke == null) return;
        final box = context.findRenderObject() as RenderBox;
        final point = box.globalToLocal(details.globalPosition);
        final last = _currentStroke!.points.last;
        final dist = (point - last).distance;
        if (dist < 0.5) return;
        setState(() {
          _currentStroke!.points.add(point);
          _currentStroke!.speed = dist.clamp(2.0, 20.0);
          _version++;
        });
        widget.onSigned?.call();
      },
      onPanEnd: (_) {
        setState(() {
          _currentStroke = null;
          _version++;
        });
      },
      child: Stack(
        children: [
          RepaintBoundary(
            key: _repaintKey,
            child: CustomPaint(
              painter: _SignaturePainter(_strokes, tc.text, _version),
              size: Size.infinite,
            ),
          ),
          if (_strokes.isEmpty)
            Positioned.fill(
              child: Center(
                child: Text(
                  'Tap and sign here',
                  style: TextStyle(fontSize: 15, color: tc.hint, fontWeight: FontWeight.w400),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Stroke {
  final List<Offset> points;
  double speed;
  Stroke({required this.points, this.speed = 5});
}

class _SignaturePainter extends CustomPainter {
  final List<Stroke> strokes;
  final Color textColor;
  final int version;
  _SignaturePainter(this.strokes, this.textColor, this.version);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = textColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;

      if (pts.length == 1) {
        paint.strokeWidth = 2.5;
        canvas.drawCircle(pts[0], 1.25, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }

      final path = ui.Path();
      path.moveTo(pts[0].dx, pts[0].dy);

      if (pts.length == 2) {
        path.lineTo(pts[1].dx, pts[1].dy);
      } else {
        for (int i = 1; i < pts.length - 1; i++) {
          final p0 = pts[i];
          final p1 = pts[i + 1];
          final midX = (p0.dx + p1.dx) / 2;
          final midY = (p0.dy + p1.dy) / 2;
          path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        }
        final last = pts.last;
        path.lineTo(last.dx, last.dy);
      }

      final baseWidth = 2.2 + (stroke.speed.clamp(2, 12) - 2) * 0.12;
      paint.strokeWidth = baseWidth;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.version != version;
}
