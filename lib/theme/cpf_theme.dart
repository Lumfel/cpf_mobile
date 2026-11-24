import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

export 'package:cpf_mobile/theme/cpf_themes.dart';

/// Backward-compatible alias for the default Soft Cream palette constants.
abstract final class CpfColors {
  static const Color softCream = Color(0xFFFBF6EE);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color creamTint = Color(0xFFF3EBDD);
  static const Color creamBorder = Color(0xFFE5DAC8);

  static const Color primaryBlue = Color(0xFF0384C5);
  static const Color warmOrange = Color(0xFFFF8D06);
  static const Color forestGreen = Color(0xFF1A8F26);
  static const Color darkCard = Color(0xFF0F2537);
  static const Color darkCardElevated = Color(0xFF17344D);

  static const Color inkPrimary = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF475569);
  static const Color errorRed = Color(0xFFC62828);
}

/// Default Material 3 Soft Cream theme helper.
abstract final class CpfTheme {
  static ThemeData lightTheme() => CpfThemes.themeDataFor(CpfThemeId.light);
}
