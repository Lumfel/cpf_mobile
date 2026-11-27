import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// All 5 official CPF themes matching `resources/css/cpf-soft-cream.css`.
enum CpfThemeId {
  light,
  dark,
  sunrise,
  joy,
  vice;

  String get storageKey => name;

  String get label => switch (this) {
        CpfThemeId.light => 'Soft Cream',
        CpfThemeId.dark => 'Dark',
        CpfThemeId.sunrise => 'Sunrise',
        CpfThemeId.joy => 'Joy',
        CpfThemeId.vice => 'Vice',
      };

  String get subtitle => switch (this) {
        CpfThemeId.light => 'Warm cream & official blue',
        CpfThemeId.dark => 'Low-glare slate & sky blue',
        CpfThemeId.sunrise => 'Rose blush & coral glow',
        CpfThemeId.joy => 'Golden parchment & teal',
        CpfThemeId.vice => 'Midnight violet & neon cyan',
      };

  bool get isDark => this == CpfThemeId.dark || this == CpfThemeId.vice;

  static CpfThemeId fromKey(String? raw) {
    if (raw == null) return CpfThemeId.light;
    final normalized = raw.trim().toLowerCase();
    for (final value in CpfThemeId.values) {
      if (value.storageKey == normalized) {
        return value;
      }
    }
    return CpfThemeId.light;
  }
}

/// Complete CPF color palette exposed as a Material 3 [ThemeExtension].
class CpfPalette extends ThemeExtension<CpfPalette> {
  const CpfPalette({
    required this.themeId,
    required this.bg,
    required this.surface,
    required this.card,
    required this.primary,
    required this.accent,
    required this.success,
    required this.text,
    required this.muted,
    required this.border,
    required this.error,
    required this.heroCard,
    required this.heroCardElevated,
    required this.heroText,
    required this.heroMuted,
  });

  /// Strict high-contrast QR quiet-zone colors shared across ALL 5 themes.
  static const Color qrQuietZoneBackground = Color(0xFFFFFFFF);
  static const Color qrModuleColor = Color(0xFF0F172A);

  final CpfThemeId themeId;
  final Color bg;
  final Color surface;
  final Color card;
  final Color primary;
  final Color accent;
  final Color success;
  final Color text;
  final Color muted;
  final Color border;
  final Color error;
  final Color heroCard;
  final Color heroCardElevated;
  final Color heroText;
  final Color heroMuted;

  @override
  CpfPalette copyWith({
    CpfThemeId? themeId,
    Color? bg,
    Color? surface,
    Color? card,
    Color? primary,
    Color? accent,
    Color? success,
    Color? text,
    Color? muted,
    Color? border,
    Color? error,
    Color? heroCard,
    Color? heroCardElevated,
    Color? heroText,
    Color? heroMuted,
  }) {
    return CpfPalette(
      themeId: themeId ?? this.themeId,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      error: error ?? this.error,
      heroCard: heroCard ?? this.heroCard,
      heroCardElevated: heroCardElevated ?? this.heroCardElevated,
      heroText: heroText ?? this.heroText,
      heroMuted: heroMuted ?? this.heroMuted,
    );
  }

  @override
  CpfPalette lerp(covariant ThemeExtension<CpfPalette>? other, double t) {
    if (other is! CpfPalette) return this;
    return CpfPalette(
      themeId: t < 0.5 ? themeId : other.themeId,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      heroCard: Color.lerp(heroCard, other.heroCard, t)!,
      heroCardElevated:
          Color.lerp(heroCardElevated, other.heroCardElevated, t)!,
      heroText: Color.lerp(heroText, other.heroText, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
    );
  }
}

/// Convenience accessor for the active [CpfPalette] from [BuildContext].
extension CpfPaletteContext on BuildContext {
  CpfPalette get cpf =>
      Theme.of(this).extension<CpfPalette>() ??
      CpfThemes.paletteFor(CpfThemeId.light);
}

/// Exact hex palettes and Material 3 [ThemeData] builders matching the web app.
abstract final class CpfThemes {
  static const CpfPalette light = CpfPalette(
    themeId: CpfThemeId.light,
    bg: Color(0xFFFBF6EE),
    surface: Color(0xFFF3EBDD),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF0384C5),
    accent: Color(0xFFFF8D06),
    success: Color(0xFF1A8F26),
    text: Color(0xFF0F172A),
    muted: Color(0xFF475569),
    border: Color(0xFFE5DAC8),
    error: Color(0xFFC62828),
    heroCard: Color(0xFF0F2537),
    heroCardElevated: Color(0xFF17344D),
    heroText: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFCBD8E4),
  );

  static const CpfPalette dark = CpfPalette(
    themeId: CpfThemeId.dark,
    bg: Color(0xFF0E141A),
    surface: Color(0xFF141C24),
    card: Color(0xFF18212A),
    primary: Color(0xFF56B4E3),
    accent: Color(0xFFF4A94A),
    success: Color(0xFF4CC37A),
    text: Color(0xFFEFE9DF),
    muted: Color(0xFF9EABB8),
    border: Color(0xFF273442),
    error: Color(0xFFF87171),
    heroCard: Color(0xFF18212A),
    heroCardElevated: Color(0xFF222E3B),
    heroText: Color(0xFFEFE9DF),
    heroMuted: Color(0xFF9EABB8),
  );

  static const CpfPalette sunrise = CpfPalette(
    themeId: CpfThemeId.sunrise,
    bg: Color(0xFFFBD8D5),
    surface: Color(0xFFF7C4CC),
    card: Color(0xFFFFF1F0),
    primary: Color(0xFFC94576),
    accent: Color(0xFFEC5E4B),
    success: Color(0xFF2A8767),
    text: Color(0xFF2D1628),
    muted: Color(0xFF73475F),
    border: Color(0xFFEBACB7),
    error: Color(0xFFB91C1C),
    heroCard: Color(0xFF2D1628),
    heroCardElevated: Color(0xFF42213B),
    heroText: Color(0xFFFFF1F0),
    heroMuted: Color(0xFFE7C7D4),
  );

  static const CpfPalette joy = CpfPalette(
    themeId: CpfThemeId.joy,
    bg: Color(0xFFFBF4E4),
    surface: Color(0xFFF5EBD7),
    card: Color(0xFFFFFCF5),
    primary: Color(0xFF2C7FB8),
    accent: Color(0xFFDF725B),
    success: Color(0xFF358F66),
    text: Color(0xFF2B2621),
    muted: Color(0xFF61584E),
    border: Color(0xFFE3D5BC),
    error: Color(0xFFC62828),
    heroCard: Color(0xFF2B2621),
    heroCardElevated: Color(0xFF3E3730),
    heroText: Color(0xFFFFFCF5),
    heroMuted: Color(0xFFD8CFC2),
  );

  static const CpfPalette vice = CpfPalette(
    themeId: CpfThemeId.vice,
    bg: Color(0xFF120B1F),
    surface: Color(0xFF211336),
    card: Color(0xFF1C112E),
    primary: Color(0xFF3CE4E8),
    accent: Color(0xFFFF5CAA),
    success: Color(0xFF3BE098),
    text: Color(0xFFF8F0FF),
    muted: Color(0xFFC4B0DC),
    border: Color(0xFF362157),
    error: Color(0xFFFF6B8B),
    heroCard: Color(0xFF1C112E),
    heroCardElevated: Color(0xFF2B1B45),
    heroText: Color(0xFFF8F0FF),
    heroMuted: Color(0xFFC4B0DC),
  );

  static CpfPalette paletteFor(CpfThemeId id) => switch (id) {
        CpfThemeId.light => light,
        CpfThemeId.dark => dark,
        CpfThemeId.sunrise => sunrise,
        CpfThemeId.joy => joy,
        CpfThemeId.vice => vice,
      };

  static ThemeData themeDataFor(CpfThemeId id) {
    final p = paletteFor(id);
    final isDark = id.isDark;
    final onPrimary = isDark ? p.bg : Colors.white;
    final onAccent = isDark ? p.bg : Colors.white;
    final onSuccess = isDark ? p.bg : Colors.white;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: p.primary,
      onPrimary: onPrimary,
      primaryContainer: p.primary.withValues(alpha: 0.16),
      onPrimaryContainer: p.text,
      secondary: p.accent,
      onSecondary: onAccent,
      secondaryContainer: p.accent.withValues(alpha: 0.16),
      onSecondaryContainer: p.text,
      tertiary: p.success,
      onTertiary: onSuccess,
      tertiaryContainer: p.success.withValues(alpha: 0.16),
      onTertiaryContainer: p.text,
      error: p.error,
      onError: isDark ? p.bg : Colors.white,
      errorContainer: p.error.withValues(alpha: 0.14),
      onErrorContainer: p.error,
      surface: p.card,
      onSurface: p.text,
      surfaceContainerHighest: p.surface,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border.withValues(alpha: 0.7),
      shadow: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      scrim: Colors.black.withValues(alpha: 0.55),
      inverseSurface: p.heroCard,
      onInverseSurface: p.heroText,
      inversePrimary: p.primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg,
      extensions: <ThemeExtension<dynamic>>[p],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: TextStyle(
          color: p.muted,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: p.muted, fontSize: 13.5),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border, width: 1.2),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: p.card,
        indicatorColor: p.primary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.primary : p.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.primary : p.muted,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.heroCard,
        contentTextStyle: TextStyle(color: p.heroText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Persistent active theme controller backed by [SecureStorageService].
class ThemeController extends ChangeNotifier {
  ThemeController({CpfThemeId initialTheme = CpfThemeId.light})
      : _themeId = initialTheme;

  CpfThemeId _themeId;

  CpfThemeId get themeId => _themeId;
  CpfPalette get palette => CpfThemes.paletteFor(_themeId);
  ThemeData get themeData => CpfThemes.themeDataFor(_themeId);

  Future<void> loadFromStorage(SecureStorageService storage) async {
    final stored = await storage.readThemeId();
    final parsed = CpfThemeId.fromKey(stored);
    if (parsed != _themeId) {
      _themeId = parsed;
      notifyListeners();
    }
  }

  Future<void> setTheme(
    CpfThemeId id,
    SecureStorageService storage,
  ) async {
    if (_themeId != id) {
      _themeId = id;
      notifyListeners();
    }
    try {
      await storage.writeThemeId(id.storageKey);
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
