import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/screens/events_screen.dart';
import 'package:cpf_mobile/screens/peer_dashboard_screen.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';
import 'package:cpf_mobile/widgets/theme_switcher_button.dart';

/// Authenticated 2-tab shell (Peer Dashboard & Campus Events).
/// Awards and Intercampus are intentionally omitted for Wave 1.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.authController,
    required this.eventsService,
    required this.storage,
    required this.themeController,
  });

  final AuthController authController;
  final EventsService eventsService;
  final SecureStorageService storage;
  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  Future<void> _confirmSignOut() async {
    final p = context.cpf;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Sign Out', style: TextStyle(color: p.text)),
        content: Text(
          'Sign out and revoke your active mobile session token?',
          style: TextStyle(color: p.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.error,
              foregroundColor: p.themeId.isDark ? p.bg : Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.authController.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final campusCode = widget.authController.profile?.campus?.code ?? 'CPF';

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Row(
              children: [
                const CpfEmblem(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedIndex == 0
                        ? 'Peer Dashboard • $campusCode'
                        : 'Events & Activities',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              ThemeSwitcherButton(
                themeController: widget.themeController,
                storage: widget.storage,
                iconOnly: true,
              ),
              IconButton(
                tooltip: 'Refresh profile',
                onPressed: () async {
                  final err = await widget.authController.refreshProfile();
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              PeerDashboardScreen(
                authController: widget.authController,
                onOpenEvents: () => setState(() => _selectedIndex = 1),
              ),
              EventsScreen(
                authController: widget.authController,
                eventsService: widget.eventsService,
                storage: widget.storage,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.qr_code_2_outlined),
                selectedIcon: Icon(Icons.qr_code_2_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note_rounded),
                label: 'Events',
              ),
            ],
          ),
        );
      },
    );
  }
}
