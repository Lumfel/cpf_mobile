import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// Compact theme switcher trigger opening the 5-theme selector bottom sheet.
class ThemeSwitcherButton extends StatelessWidget {
  const ThemeSwitcherButton({
    super.key,
    required this.themeController,
    required this.storage,
    this.iconOnly = false,
  });

  final ThemeController themeController;
  final SecureStorageService storage;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final p = context.cpf;
        final current = themeController.themeId;

        if (iconOnly) {
          return IconButton(
            tooltip: 'Theme (${current.label})',
            onPressed: () => showThemePickerSheet(
              context,
              themeController: themeController,
              storage: storage,
            ),
            icon: Icon(Icons.palette_outlined, color: p.primary),
          );
        }

        return OutlinedButton.icon(
          onPressed: () => showThemePickerSheet(
            context,
            themeController: themeController,
            storage: storage,
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: p.card,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          icon: Icon(Icons.palette_outlined, size: 16, color: p.primary),
          label: Text(
            current.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
        );
      },
    );
  }
}

/// Modal bottom sheet allowing selection across all 5 synced CPF themes.
Future<void> showThemePickerSheet(
  BuildContext context, {
  required ThemeController themeController,
  required SecureStorageService storage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          final p = context.cpf;
          final activeId = themeController.themeId;

          return Container(
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.palette_rounded, color: p.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Choose CPF Theme',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(Icons.close_rounded, color: p.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final id in CpfThemeId.values) ...[
                      _ThemeOptionTile(
                        id: id,
                        selected: id == activeId,
                        onTap: () async {
                          await themeController.setTheme(id, storage);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                      if (id != CpfThemeId.values.last)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final CpfThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final optionPalette = CpfThemes.paletteFor(id);

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? p.primary : p.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwatchDot(color: optionPalette.bg, borderColor: p.border),
                  const SizedBox(width: 4),
                  _SwatchDot(
                    color: optionPalette.primary,
                    borderColor: p.border,
                  ),
                  const SizedBox(width: 4),
                  _SwatchDot(
                    color: optionPalette.accent,
                    borderColor: p.border,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    Text(
                      id.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: p.primary)
              else
                Icon(Icons.radio_button_unchecked_rounded, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
    );
  }
}
