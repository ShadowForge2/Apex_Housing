import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService _instance = SecurityService._();
  static SecurityService get instance => _instance;

  static const _channel = MethodChannel('com.apexhousing/security');

  bool _isRooted = false;
  bool _isDebugged = false;
  bool _isEmulator = false;
  bool _integrityVerified = false;

  bool get isRooted => _isRooted;
  bool get isDebugged => _isDebugged;
  bool get isEmulator => _isEmulator;
  bool get integrityVerified => _integrityVerified;

  Future<void> runChecks() async {
    if (kIsWeb) return;

    await Future.wait([
      _checkRoot(),
      _checkDebugger(),
      _checkEmulator(),
    ]);
  }

  Future<void> _checkRoot() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final result = await _channel.invokeMethod<bool>('isJailbroken');
      _isRooted = result ?? false;
    } catch (_) {
      _isRooted = false;
    }
  }

  Future<void> _checkDebugger() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final result = await _channel.invokeMethod<bool>('isDebugged');
      _isDebugged = result ?? false;
    } catch (_) {
      _isDebugged = false;
    }
  }

  Future<void> _checkEmulator() async {
    if (!Platform.isAndroid) return;

    try {
      final result = await _channel.invokeMethod<bool>('isEmulator');
      _isEmulator = result ?? false;
    } catch (_) {
      _isEmulator = false;
    }
  }

  Future<String> getAppSignature() async {
    if (!Platform.isAndroid) return 'not-android';

    try {
      final result = await _channel.invokeMethod<String>('getAppSignature');
      return result ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  bool get isCompromised => _isRooted || _isDebugged;

  Map<String, dynamic> getReport() => {
        'rooted': _isRooted,
        'debugger': _isDebugged,
        'emulator': _isEmulator,
        'compromised': isCompromised,
      };
}
