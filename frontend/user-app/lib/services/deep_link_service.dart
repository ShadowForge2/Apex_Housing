import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final StreamController<String> _propertySlugController =
      StreamController<String>.broadcast();

  Stream<String> get propertySlugStream => _propertySlugController.stream;

  void init() {
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final slug = _parsePropertySlug(uri);
        if (slug != null) {
          _propertySlugController.add(slug);
        }
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  Future<void> checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        final slug = _parsePropertySlug(uri);
        if (slug != null) {
          _propertySlugController.add(slug);
        }
      }
    } catch (e) {
      debugPrint('Initial link error: $e');
    }
  }

  String? _parsePropertySlug(Uri uri) {
    // https://apex-housing.online/p/{slug}
    if (uri.host == 'apex-housing.online' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'p') {
      return uri.pathSegments[1];
    }

    // apexhousing://property/{slug}
    if (uri.scheme == 'apexhousing' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'property') {
      return uri.pathSegments[1];
    }

    return null;
  }

  static String buildShareUrl(String slug) {
    return 'https://apex-housing.online/p/$slug';
  }

  void dispose() {
    _sub?.cancel();
    _propertySlugController.close();
  }
}
