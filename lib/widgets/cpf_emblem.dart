import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// Official Circle of Peer Facilitators emblem inside a clean circular badge.
class CpfEmblem extends StatelessWidget {
  const CpfEmblem({
    super.key,
    this.size = 40,
    this.padding = const EdgeInsets.all(2),
  });

  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.themeId.isDark ? 0.28 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/cpf_logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
