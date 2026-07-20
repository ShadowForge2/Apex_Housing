import 'package:flutter/material.dart';

enum UserRole { tenant, landlord }

class RoleProvider extends InheritedWidget {
  final UserRole role;
  final VoidCallback switchRole;

  const RoleProvider({
    super.key,
    required this.role,
    required this.switchRole,
    required super.child,
  });

  static RoleProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<RoleProvider>();
    assert(provider != null, 'No RoleProvider found in context');
    return provider!;
  }

  bool get isLandlord => role == UserRole.landlord;
  bool get isTenant => role == UserRole.tenant;

  @override
  bool updateShouldNotify(RoleProvider oldWidget) => role != oldWidget.role;
}
