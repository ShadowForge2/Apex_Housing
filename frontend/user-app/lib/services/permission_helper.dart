import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class PermissionHelper {
  static Future<bool> showRationaleAndRequest(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String explanation,
    required IconData icon,
  }) async {
    if (await permission.isGranted) return true;

    if (await permission.isPermanentlyDenied) {
      if (context.mounted) {
        final opened = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: Text(
              'This permission has been permanently denied. Please enable it in your device settings to continue.',
              style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (opened == true) openAppSettings();
      }
      return false;
    }

    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: Text(explanation, style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Now')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }

    final status = await permission.request();
    return status.isGranted;
  }
}
