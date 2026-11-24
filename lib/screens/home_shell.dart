import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/screens/elections_screen.dart';
import 'package:cpf_mobile/screens/events_screen.dart';
import 'package:cpf_mobile/screens/messenger_gc_checklist_screen.dart';
import 'package:cpf_mobile/screens/payments_screen.dart';
import 'package:cpf_mobile/screens/peer_dashboard_screen.dart';
import 'package:cpf_mobile/services/elections_service.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/membership_payment_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';
import 'package:cpf_mobile/widgets/theme_switcher_button.dart';

/// Authenticated 4-tab shell (Dashboard, Events, Dues, Elections).
/// Awards and Intercampus remain strictly omitted.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.authController,
    required this.eventsService,
    required this.paymentService,
    required this.electionsService,
    required this.storage,
    required this.themeController,
  });

  final AuthController authController;
  final EventsService eventsService;
  final MembershipPaymentService paymentService;
  final ElectionsService electionsService;
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

  void _openGcChecklist() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessengerGcChecklistScreen(
          service: widget.paymentService,
          baseUrl: widget.authController.apiConfig.baseUrl,
        ),
      ),
    );
  }

  String _titleForTab(String campusCode) => switch (_selectedIndex) {
        0 => 'Peer Dashboard • $campusCode',
        1 => 'Events & Activities',
        2 => 'Dues & Payments',
        3 => 'Campus Elections',
        _ => 'CPF Mobile',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final campusCode =
            widget.authController.profile?.campus?.code ?? 'CPF';

        final tabs = <Widget>[
          PeerDashboardScreen(
            key: const ValueKey<String>('tab_dashboard'),
            authController: widget.authController,
            onOpenEvents: () => setState(() => _selectedIndex = 1),
            onOpenPayments: () => setState(() => _selectedIndex = 2),
            onOpenElections: () => setState(() => _selectedIndex = 3),
            onOpenGcChecklist: _openGcChecklist,
          ),
          EventsScreen(
            key: const ValueKey<String>('tab_events'),
            authController: widget.authController,
            eventsService: widget.eventsService,
            storage: widget.storage,
          ),
          PaymentsScreen(
            key: const ValueKey<String>('tab_payments'),
            authController: widget.authController,
            paymentService: widget.paymentService,
          ),
          ElectionsScreen(
            key: const ValueKey<String>('tab_elections'),
            authController: widget.authController,
            electionsService: widget.electionsService,
          ),
        ];

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Row(
              children: [
                const CpfEmblem(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _titleForTab(campusCode),
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
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: tabs[_selectedIndex],
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
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Dues',
              ),
              NavigationDestination(
                icon: Icon(Icons.how_to_vote_outlined),
                selectedIcon: Icon(Icons.how_to_vote_rounded),
                label: 'Elections',
              ),
            ],
          ),
        );
      },
    );
  }
}
