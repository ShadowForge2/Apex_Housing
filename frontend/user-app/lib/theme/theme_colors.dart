import 'package:flutter/material.dart';

@immutable
class ThemeColors extends ThemeExtension<ThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color border;
  final Color borderLight;
  final Color text;
  final Color subtitle;
  final Color hint;
  final Color iconBg;
  final Color shadow;
  final Color inputFill;
  final Color divider;
  final Color scaffoldBg;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.border,
    required this.borderLight,
    required this.text,
    required this.subtitle,
    required this.hint,
    required this.iconBg,
    required this.shadow,
    required this.inputFill,
    required this.divider,
    required this.scaffoldBg,
  });

  @override
  ThemeColors copyWith({
    Color? background, Color? surface, Color? surfaceVariant, Color? card,
    Color? border, Color? borderLight, Color? text, Color? subtitle,
    Color? hint, Color? iconBg, Color? shadow, Color? inputFill,
    Color? divider, Color? scaffoldBg,
  }) {
    return ThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      text: text ?? this.text,
      subtitle: subtitle ?? this.subtitle,
      hint: hint ?? this.hint,
      iconBg: iconBg ?? this.iconBg,
      shadow: shadow ?? this.shadow,
      inputFill: inputFill ?? this.inputFill,
      divider: divider ?? this.divider,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
    );
  }

  @override
  ThemeColors lerp(ThemeExtension<ThemeColors>? other, double t) {
    if (other is! ThemeColors) return this;
    return ThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtitle: Color.lerp(subtitle, other.subtitle, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
    );
  }

  static const light = ThemeColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAFA),
    surfaceVariant: Color(0xFFF5F3FF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFECECEC),
    borderLight: Color(0xFFF5F3FF),
    text: Color(0xFF111827),
    subtitle: Color(0xFF6B7280),
    hint: Color(0xFF9CA3AF),
    iconBg: Color(0xFFF5F3FF),
    shadow: Color(0x0D000000),
    inputFill: Color(0xFFFAFAFA),
    divider: Color(0xFFECECEC),
    scaffoldBg: Color(0xFFFFFFFF),
  );

  static const dark = ThemeColors(
    background: Color(0xFF0F0F14),
    surface: Color(0xFF1A1A24),
    surfaceVariant: Color(0xFF1E1E2E),
    card: Color(0xFF1A1A24),
    border: Color(0xFF2A2A3A),
    borderLight: Color(0xFF1E1E2E),
    text: Color(0xFFF1F1F6),
    subtitle: Color(0xFF9D9DB5),
    hint: Color(0xFF6B6B82),
    iconBg: Color(0xFF252536),
    shadow: Color(0x33000000),
    inputFill: Color(0xFF1A1A24),
    divider: Color(0xFF2A2A3A),
    scaffoldBg: Color(0xFF0F0F14),
  );
}

extension ThemeColorsExtension on BuildContext {
  ThemeColors get colors => Theme.of(this).extension<ThemeColors>()!;
}
