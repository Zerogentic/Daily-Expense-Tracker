import 'package:flutter/material.dart';

/// Black and electric-blue palette shared across the app.
class AppColors {
  static const bg = Color(0xFF05070D);
  static const surface = Color(0xFF0D1322);
  static const surface2 = Color(0xFF141C2F);
  static const border = Color(0xFF1E2A44);
  static const accent = Color(0xFF2F7BFF);
  static const accent2 = Color(0xFF22D3EE);
  static const text = Color(0xFFF2F5FB);
  static const muted = Color(0xFF8A96B0);
  static const good = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);

  /// Money going out.
  static const spend = Color(0xFFFF6B81);

  /// Money coming in.
  static const receive = Color(0xFF34D399);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.accent2,
    onSecondary: AppColors.bg,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface2,
    surfaceContainerHighest: AppColors.surface2,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.bad,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.border,
  );
}

/// Rounded card used for every section of the app.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding, this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? const EdgeInsets.all(16), child: child);
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: content)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}

InputDecoration fieldDecoration(String label, {String? hint, Widget? prefix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefix,
    filled: true,
    fillColor: AppColors.surface2,
    labelStyle: const TextStyle(color: AppColors.muted),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
  );
}

/// Green under 80% of a limit, amber up to 100%, red above.
Color usageColor(double fraction) {
  if (fraction >= 1) return AppColors.bad;
  if (fraction >= 0.8) return AppColors.warn;
  return AppColors.good;
}
