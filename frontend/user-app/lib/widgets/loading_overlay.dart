import 'package:flutter/material.dart';
import '../theme/theme_colors.dart';
import 'apex_loading.dart';

OverlayEntry? _currentOverlay;

void showApexLoading(BuildContext context, {Duration duration = const Duration(milliseconds: 1200), String? label}) {
  dismissApexLoading();
  final tc = context.colors;
  _currentOverlay = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: Material(
        color: tc.card,
        child: Center(
          child: ApexLoadingFull(label: label),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(_currentOverlay!);
  Future.delayed(duration, () => dismissApexLoading());
}

void dismissApexLoading() {
  _currentOverlay?.remove();
  _currentOverlay = null;
}

void showApexLoadingThen(BuildContext context, VoidCallback after, {Duration duration = const Duration(milliseconds: 1200), String? label}) {
  showApexLoading(context, duration: duration, label: label);
  Future.delayed(duration, () {
    if (context.mounted) after();
  });
}
