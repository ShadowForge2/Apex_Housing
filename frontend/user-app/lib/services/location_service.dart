import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppLocationService {
  static final AppLocationService _instance = AppLocationService._();
  static AppLocationService get instance => _instance;
  AppLocationService._();

  Position? _cachedPosition;
  Position? get currentPosition => _cachedPosition;

  Future<bool> checkAndRequestPermission({BuildContext? context}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (context != null && context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Location Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
              'APEX Housing needs your location to show nearby properties and improve your search results.',
              style: TextStyle(fontSize: 14),
            ),
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

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      final opened = await openAppSettings();
      if (!opened) return false;
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }

    return true;
  }

  Future<Position?> getCurrentLocation({BuildContext? context}) async {
    final hasPermission = await checkAndRequestPermission(context: context);
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cachedPosition = position;
      return position;
    } catch (e) {
      debugPrint('LocationService: getCurrentPosition failed: $e');
      return _cachedPosition;
    }
  }

  double distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
