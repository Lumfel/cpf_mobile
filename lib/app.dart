import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/screens/home_shell.dart';
import 'package:cpf_mobile/screens/landing_login_screen.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';

/// Root application widget for Circle of Peer Facilitators (CPF) Mobile.
class CpfApp extends StatefulWidget {
  const CpfApp({super.key, this.initialInitialize = true});

  final bool initialInitialize;

  @override
  State<CpfApp> createState() => _CpfAppState();
}

class _CpfAppState extends State<CpfApp> {
  late final ApiConfig _apiConfig;
  late final SecureStorageService _storage;
  late final ThemeController _themeController;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final EventsService _eventsService;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _apiConfig = ApiConfig();
    _storage = const SecureStorageService();
    _themeController = ThemeController();

    late final AuthController controller;
    _apiClient = ApiClient(
      apiConfig: _apiConfig,
      storage: _storage,
      onUnauthorized: () => controller.handleUnauthorized(),
    );
    _authService = AuthService(_apiClient);
    _eventsService = EventsService(_apiClient);
    controller = AuthController(
      apiConfig: _apiConfig,
      storage: _storage,
      apiClient: _apiClient,
      authService: _authService,
    );
    _authController = controller;

    if (widget.initialInitialize) {
      _themeController.loadFromStorage(_storage);
      _authController.initialize();
    }
  }

  @override
  void dispose() {
    _authController.dispose();
    _themeController.dispose();
    _apiConfig.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeController, _authController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'CPF Mobile',
          debugShowCheckedModeBanner: false,
          theme: _themeController.themeData,
          home: (_authController.isInitializing && widget.initialInitialize)
              ? const _SplashScreen()
              : _authController.isAuthenticated
                  ? HomeShell(
                      authController: _authController,
                      eventsService: _eventsService,
                      storage: _storage,
                      themeController: _themeController,
                    )
                  : PublicLandingLoginScreen(
                      authController: _authController,
                      apiConfig: _apiConfig,
                      storage: _storage,
                      themeController: _themeController,
                    ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CpfEmblem(size: 76),
            const SizedBox(height: 16),
            Text(
              'Circle of Peer Facilitators',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: p.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
