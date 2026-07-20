import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin that saves/restores screen state when the app is minimized.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with AppStateRestoration {
///   @override
///   String get screenId => 'add_property_step1';
///
///   @override
///   Map<String, dynamic> get restorationData => {
///     'title': _titleController.text,
///     'price': _priceController.text,
///     'category': _selectedCategory,
///     'step': _currentStep,
///   };
///
///   @override
///   void restoreState(Map<String, dynamic> data) {
///     _titleController.text = data['title'] ?? '';
///     _priceController.text = data['price'] ?? '';
///     _selectedCategory = data['category'];
///     _currentStep = data['step'] ?? 0;
///   }
/// }
/// ```
mixin AppStateRestoration<T extends StatefulWidget> on State<T> {
  String get screenId;
  Map<String, dynamic> get restorationData => {};
  void restoreState(Map<String, dynamic> data) {}
  ScrollController? get scrollController => null;

  static const _prefix = 'screen_state_';
  static const _scrollPrefix = 'scroll_';

  final _AppLifecycleObserver _observer = _AppLifecycleObserver();

  @override
  void initState() {
    super.initState();
    _observer._mixin = this;
    WidgetsBinding.instance.addObserver(_observer);
    _restoreState();
    _restoreScrollPosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    _saveState();
    _saveScrollPosition();
    super.dispose();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = restorationData;
      if (data.isNotEmpty) {
        await prefs.setString('$_prefix$screenId', jsonEncode(data));
      }
    } catch (e) {
      debugPrint('AppStateRestoration($screenId): saveState failed: $e');
    }
  }

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$screenId');
      if (raw != null && mounted) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        restoreState(data);
      }
    } catch (e) {
      debugPrint('AppStateRestoration($screenId): restoreState failed: $e');
    }
  }

  Future<void> _saveScrollPosition() async {
    if (scrollController == null || !scrollController!.hasClients) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_scrollPrefix$screenId', scrollController!.offset);
    } catch (e) {
      debugPrint('AppStateRestoration($screenId): saveScrollPosition failed: $e');
    }
  }

  Future<void> _restoreScrollPosition() async {
    if (scrollController == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getDouble('$_scrollPrefix$screenId');
      if (offset != null && scrollController!.hasClients) {
        scrollController!.jumpTo(offset);
      }
    } catch (e) {
      debugPrint('AppStateRestoration($screenId): restoreScrollPosition failed: $e');
    }
  }

  Future<void> clearSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$screenId');
      await prefs.remove('$_scrollPrefix$screenId');
    } catch (e) {
      debugPrint('AppStateRestoration($screenId): clearSavedState failed: $e');
    }
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  AppStateRestoration? _mixin;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _mixin?._saveState();
      _mixin?._saveScrollPosition();
    } else if (state == AppLifecycleState.resumed) {
      _mixin?._restoreScrollPosition();
    }
  }
}
