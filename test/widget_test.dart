import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/models/cpf_role.dart';
import 'package:cpf_mobile/screens/landing_login_screen.dart';
import 'package:cpf_mobile/screens/peer_dashboard_screen.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/server_url_dialog.dart';

class _InMemorySecureStorage extends SecureStorageService {
  _InMemorySecureStorage([Map<String, String>? initial])
      : _store = Map<String, String>.from(initial ?? <String, String>{});

  final Map<String, String> _store;

  @override
  Future<String?> readToken() async => _store['token'];

  @override
  Future<void> writeToken(String token) async {
    _store['token'] = token;
  }

  @override
  Future<void> deleteToken() async {
    _store.remove('token');
  }

  @override
  Future<String?> readServerUrl() async => _store['server_url'];

  @override
  Future<void> writeServerUrl(String url) async {
    _store['server_url'] = url;
  }

  @override
  Future<void> deleteServerUrl() async {
    _store.remove('server_url');
  }

  @override
  Future<String?> readThemeId() async => _store['theme_id'];

  @override
  Future<void> writeThemeId(String themeId) async {
    _store['theme_id'] = themeId;
  }
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }
}

void main() {
  group('CpfRole domain constraints', () {
    test('supports exactly 6 native roles and rejects admin', () {
      expect(CpfRole.values.length, 6);
      expect(CpfRole.fromApi('adviser'), CpfRole.adviser);
      expect(CpfRole.fromApi('president'), CpfRole.president);
      expect(CpfRole.fromApi('vice_president'), CpfRole.vicePresident);
      expect(CpfRole.fromApi('secretary'), CpfRole.secretary);
      expect(CpfRole.fromApi('treasurer'), CpfRole.treasurer);
      expect(CpfRole.fromApi('member'), CpfRole.member);

      expect(CpfRole.fromApi('admin'), isNull);
      expect(CpfRole.fromApi('super_admin'), isNull);
      expect(CpfRole.fromApi(null), isNull);
    });
  });

  group('5-Theme palette sync & persistence', () {
    test('all 5 web themes match exact hex tokens from cpf-soft-cream.css', () {
      expect(CpfThemes.light.bg, const Color(0xFFFBF6EE));
      expect(CpfThemes.light.surface, const Color(0xFFF3EBDD));
      expect(CpfThemes.light.card, const Color(0xFFFFFFFF));
      expect(CpfThemes.light.primary, const Color(0xFF0384C5));
      expect(CpfThemes.light.accent, const Color(0xFFFF8D06));
      expect(CpfThemes.light.success, const Color(0xFF1A8F26));
      expect(CpfThemes.light.text, const Color(0xFF0F172A));
      expect(CpfThemes.light.muted, const Color(0xFF475569));

      expect(CpfThemes.dark.bg, const Color(0xFF0E141A));
      expect(CpfThemes.dark.surface, const Color(0xFF141C24));
      expect(CpfThemes.dark.card, const Color(0xFF18212A));
      expect(CpfThemes.dark.primary, const Color(0xFF56B4E3));
      expect(CpfThemes.dark.accent, const Color(0xFFF4A94A));
      expect(CpfThemes.dark.success, const Color(0xFF4CC37A));
      expect(CpfThemes.dark.text, const Color(0xFFEFE9DF));
      expect(CpfThemes.dark.muted, const Color(0xFF9EABB8));

      expect(CpfThemes.sunrise.bg, const Color(0xFFFBD8D5));
      expect(CpfThemes.sunrise.surface, const Color(0xFFF7C4CC));
      expect(CpfThemes.sunrise.card, const Color(0xFFFFF1F0));
      expect(CpfThemes.sunrise.primary, const Color(0xFFC94576));
      expect(CpfThemes.sunrise.accent, const Color(0xFFEC5E4B));
      expect(CpfThemes.sunrise.success, const Color(0xFF2A8767));
      expect(CpfThemes.sunrise.text, const Color(0xFF2D1628));
      expect(CpfThemes.sunrise.muted, const Color(0xFF73475F));

      expect(CpfThemes.joy.bg, const Color(0xFFFBF4E4));
      expect(CpfThemes.joy.surface, const Color(0xFFF5EBD7));
      expect(CpfThemes.joy.card, const Color(0xFFFFFCF5));
      expect(CpfThemes.joy.primary, const Color(0xFF2C7FB8));
      expect(CpfThemes.joy.accent, const Color(0xFFDF725B));
      expect(CpfThemes.joy.success, const Color(0xFF358F66));
      expect(CpfThemes.joy.text, const Color(0xFF2B2621));
      expect(CpfThemes.joy.muted, const Color(0xFF61584E));

      expect(CpfThemes.vice.bg, const Color(0xFF120B1F));
      expect(CpfThemes.vice.surface, const Color(0xFF211336));
      expect(CpfThemes.vice.card, const Color(0xFF1C112E));
      expect(CpfThemes.vice.primary, const Color(0xFF3CE4E8));
      expect(CpfThemes.vice.accent, const Color(0xFFFF5CAA));
      expect(CpfThemes.vice.success, const Color(0xFF3BE098));
      expect(CpfThemes.vice.text, const Color(0xFFF8F0FF));
      expect(CpfThemes.vice.muted, const Color(0xFFC4B0DC));
    });

    test('ThemeController persists and restores theme id', () async {
      final storage = _InMemorySecureStorage();
      final controller = ThemeController();
      expect(controller.themeId, CpfThemeId.light);

      await controller.setTheme(CpfThemeId.vice, storage);
      expect(controller.themeId, CpfThemeId.vice);
      expect(await storage.readThemeId(), 'vice');

      final restored = ThemeController();
      await restored.loadFromStorage(storage);
      expect(restored.themeId, CpfThemeId.vice);
    });
  });

  group('ApiConfig URL normalization', () {
    test('uses platform-aware defaultBaseUrl and normalizes stored URLs', () async {
      expect(
        defaultBaseUrl,
        kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000',
      );
      expect(
        ApiConfig.normalizeBaseUrl('http://10.0.2.2:8000/'),
        'http://10.0.2.2:8000',
      );
      expect(
        ApiConfig.normalizeBaseUrl('http://127.0.0.1:8000///'),
        'http://127.0.0.1:8000',
      );
      expect(
        ApiConfig.normalizeBaseUrl('https://demo.trycloudflare.com/api/v1/'),
        'https://demo.trycloudflare.com',
      );
      final config = ApiConfig(
        initialBaseUrl: 'https://demo.trycloudflare.com/api/v1',
      );
      expect(config.baseUrl, 'https://demo.trycloudflare.com');
      expect(config.apiBaseUrl, 'https://demo.trycloudflare.com/api/v1');
      expect(
        config.androidDownloadUrl,
        'https://demo.trycloudflare.com/download/android',
      );

      final storage = _InMemorySecureStorage(<String, String>{
        'server_url': '  https://stored.trycloudflare.com///  ',
      });
      final loaded = ApiConfig();
      await loaded.loadFromStorage(storage);
      expect(loaded.baseUrl, 'https://stored.trycloudflare.com');
    });
  });

  group('ApiClient error handling and Bearer interceptor', () {
    test('handles DioExceptionType.transformTimeout cleanly', () {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      final client = ApiClient(apiConfig: apiConfig, storage: storage);

      final ex = client.toApiException(
        DioException(
          requestOptions: RequestOptions(path: '/events'),
          type: DioExceptionType.transformTimeout,
        ),
      );
      expect(ex.message, contains('timed out'));
    });

    test(
      'attaches Bearer token on protected routes, omits on login, clears on 401',
      () async {
        final apiConfig = ApiConfig();
        final storage = _InMemorySecureStorage(<String, String>{
          'token': '1|testTokenValue',
        });
        var unauthorizedCalled = false;

        final client = ApiClient(
          apiConfig: apiConfig,
          storage: storage,
          onUnauthorized: () => unauthorizedCalled = true,
        );

        final adapter = _StubAdapter((options) {
          if (options.path.endsWith('/events')) {
            return ResponseBody.fromString(
              '{"message":"Unauthenticated."}',
              401,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          return ResponseBody.fromString(
            '{"token":"new"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
        client.dio.httpClientAdapter = adapter;

        await client.dio.post<dynamic>('/auth/login', data: {'email': 'a@b.c'});
        expect(adapter.lastRequest?.headers['Authorization'], isNull);

        await expectLater(
          () => client.dio.get<dynamic>('/events'),
          throwsA(isA<DioException>()),
        );
        expect(
          adapter.lastRequest?.headers['Authorization'],
          'Bearer 1|testTokenValue',
        );
        expect(unauthorizedCalled, isTrue);
        expect(await storage.readToken(), isNull);
      },
    );
  });

  group('AuthProfile JSON parsing', () {
    test('parses sample login response from API_CONTRACT.md', () {
      final profile = AuthProfile.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 12,
          'name': 'Mercado, Sofia R.',
          'email': 'sofia.mercado@chmsu.edu.ph',
          'must_change_password': false,
        },
        'verified_role': 'president',
        'verified_role_label': 'President',
        'is_alumni': false,
        'permissions': <String, dynamic>{
          'is_officer_or_adviser': true,
          'is_club_adviser': false,
          'can_propose_events': true,
          'can_scan_attendance': true,
          'can_access_archive': true,
        },
        'campus': <String, dynamic>{
          'id': 1,
          'code': 'ALIJIS',
          'name': 'CHMSU Alijis Campus',
          'slug': 'alijis',
          'current_academic_year': '2026-2027',
        },
        'qr_unlocked': true,
        'member_id_code': 'CPF-ALIJIS-2026-0012',
        'qr_payload': 'CPF|campus:ALIJIS|user:12|role:president|sig:a1b2c3',
      });

      expect(profile.verifiedRole, CpfRole.president);
      expect(profile.canScanEvents, isTrue);
      expect(profile.qrUnlocked, isTrue);
      expect(profile.memberIdCode, 'CPF-ALIJIS-2026-0012');
    });
  });

  testWidgets(
    'Landing + Login switches themes, opens Server URL & Data Privacy, and omits Awards/Intercampus',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      final themeController = ThemeController();
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
      );

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            return MaterialApp(
              theme: themeController.themeData,
              home: PublicLandingLoginScreen(
                authController: authController,
                apiConfig: apiConfig,
                storage: storage,
                themeController: themeController,
              ),
            );
          },
        ),
      );

      expect(find.text('Email & Password'), findsOneWidget);
      expect(find.text('12-Char Passkey'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Data Privacy'), findsOneWidget);
      expect(find.textContaining('Awards'), findsNothing);
      expect(find.textContaining('Intercampus'), findsNothing);

      // Switch theme using the Theme Switcher button.
      await tester.tap(find.byIcon(Icons.palette_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Choose CPF Theme'), findsOneWidget);
      await tester.tap(find.text('Vice'));
      await tester.pumpAndSettle();
      expect(themeController.themeId, CpfThemeId.vice);

      // Switch to 12-Char Passkey tab.
      await tester.tap(find.text('12-Char Passkey'));
      await tester.pumpAndSettle();
      expect(find.text('Claim Passkey & Sign In'), findsOneWidget);

      // Open Server URL dialog.
      await tester.tap(find.text('Server URL'));
      await tester.pumpAndSettle();
      expect(find.text('Server Root URL'), findsOneWidget);
      expect(find.text('Local Chrome: http://127.0.0.1:8000'), findsOneWidget);
      expect(find.text('Emulator: http://10.0.2.2:8000'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Open Data Privacy modal.
      await tester.ensureVisible(find.text('Data Privacy'));
      await tester.tap(find.text('Data Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Data Privacy Notice'), findsOneWidget);
    },
  );

  testWidgets(
    'PeerDashboard QR pass keeps pure white quiet-zone and dark modules on Dark and Vice themes',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      final stubAdapter = _StubAdapter((_) {
        return ResponseBody.fromString(
          '{"token_type":"Bearer","token":"1|abc","user":{"id":12,"name":"Mercado, Sofia R.","email":"sofia@chmsu.edu.ph","must_change_password":false},"verified_role":"president","verified_role_label":"President","is_alumni":false,"permissions":{"is_officer_or_adviser":true,"is_club_adviser":false,"can_propose_events":true,"can_scan_attendance":true,"can_access_archive":true},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0012","qr_payload":"CPF|campus:ALIJIS|user:12|role:president|sig:a1b2c3"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      apiClient.dio.httpClientAdapter = stubAdapter;

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
      );
      await authController.signInWithEmail(
        email: 'sofia@chmsu.edu.ph',
        password: 'secret',
      );

      for (final themeId in [CpfThemeId.dark, CpfThemeId.vice]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CpfThemes.themeDataFor(themeId),
            home: Scaffold(
              body: PeerDashboardScreen(
                authController: authController,
                onOpenEvents: () {},
              ),
            ),
          ),
        );

        final qrView = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(qrView.backgroundColor, const Color(0xFFFFFFFF));
        expect(qrView.eyeStyle.color, const Color(0xFF0F172A));
        expect(qrView.dataModuleStyle.color, const Color(0xFF0F172A));
      }
    },
  );

  testWidgets(
    'Server URL dialog tests GET /api/v1/health and displays green or red badge',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      var shouldFail = false;

      final healthDio = Dio();
      final adapter = _StubAdapter((options) {
        if (shouldFail) {
          return ResponseBody.fromString(
            '{"message":"Database unavailable"}',
            503,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString(
          '{"ok":true,"database":true}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      healthDio.httpClientAdapter = adapter;

      await tester.pumpWidget(
        MaterialApp(
          theme: CpfThemes.themeDataFor(CpfThemeId.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showServerUrlDialog(
                    context,
                    apiConfig: apiConfig,
                    storage: storage,
                    healthCheckDio: healthDio,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Local Chrome: http://127.0.0.1:8000'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(
        adapter.lastRequest?.uri.toString(),
        'http://127.0.0.1:8000/api/v1/health',
      );
      expect(find.text('Connected to CPF API + DB'), findsOneWidget);

      // Now simulate failing health endpoint.
      shouldFail = true;
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      expect(find.text('Database unavailable'), findsOneWidget);
    },
  );
}
