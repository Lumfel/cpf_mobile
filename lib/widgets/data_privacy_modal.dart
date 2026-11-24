import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// Displays the Data Privacy Notice modal bottom sheet aligned with the
/// Philippine Data Privacy Act of 2012 (RA 10173).
Future<void> showDataPrivacyModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final p = sheetContext.cpf;

      return DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: p.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Privacy Notice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                            Text(
                              'Circle of Peer Facilitators • RA 10173',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: Icon(Icons.close_rounded, color: p.muted),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: const [
                      _PrivacySection(
                        icon: Icons.badge_outlined,
                        title: '1. Personal Information Collected',
                        body:
                            'CPF Mobile displays and processes your verified CHMSU email, full name, course, year level, section, campus affiliation, native peer role, and HMAC-signed QR identity payload.',
                      ),
                      SizedBox(height: 12),
                      _PrivacySection(
                        icon: Icons.qr_code_2_rounded,
                        title: '2. Purpose of Processing',
                        body:
                            'Your information is used strictly for peer facilitator identity verification, same-campus event check-in/check-out attendance, and delivering daily peer wellness quotes.',
                      ),
                      SizedBox(height: 12),
                      _PrivacySection(
                        icon: Icons.security_rounded,
                        title: '3. Campus Isolation & Security',
                        body:
                            'Attendance scanning is restricted to verified Officers and Club Advisers within your own campus. Your Sanctum API token is stored encrypted on this device via Android Keystore.',
                      ),
                      SizedBox(height: 12),
                      _PrivacySection(
                        icon: Icons.gavel_rounded,
                        title: '4. Your Data Privacy Rights',
                        body:
                            'Under the Data Privacy Act of 2012 (RA 10173), you have the right to access, correct, or request review of your membership records through your campus Guidance Office and Club Adviser.',
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('I Understand'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
