import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextScaleProvider extends ChangeNotifier {
  bool _isLargeText = false;
  bool get isLargeText => _isLargeText;

  double get scaleFactor => _isLargeText ? 1.3 : 1.0;

  static const _textScaleKey = 'app_text_scale';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLargeText = prefs.getBool(_textScaleKey) ?? false;
    notifyListeners();
  }

  void toggleLargeText() {
    _isLargeText = !_isLargeText;
    _persist();
    notifyListeners();
  }

  void setLargeText(bool large) {
    _isLargeText = large;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_textScaleKey, _isLargeText);
  }
}

class TextScaleScope extends InheritedNotifier<TextScaleProvider> {
  const TextScaleScope({super.key, required TextScaleProvider model, required super.child})
      : super(notifier: model);

  static TextScaleProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TextScaleScope>()!.notifier!;
  }
}
