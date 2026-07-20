import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/apex_loading.dart';

OverlayEntry? _currentOverlay;

void showAppLoading(BuildContext context, {String message = 'Processing...'}) {
  dismissAppLoading();
  _currentOverlay = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ApexLoadingFull(label: message),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(_currentOverlay!);
}

void dismissAppLoading() {
  _currentOverlay?.remove();
  _currentOverlay = null;
}

/// Runs an async action with the branded Apex loading overlay shown.
/// After [action] completes, the overlay is dismissed and the action's result is returned.
Future<T> runWithLoading<T>(
  BuildContext context, {
  required Future<T> Function() action,
  String message = 'Processing...',
}) async {
  final navigator = Navigator.of(context);
  showAppLoading(context, message: message);
  try {
    final result = await action();
    dismissAppLoading();
    return result;
  } catch (e) {
    dismissAppLoading();
    rethrow;
  }
}

void showAppToast(BuildContext context, String message, {Color? backgroundColor}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: backgroundColor ?? AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}
