import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/models/campus_event.dart';
import 'package:cpf_mobile/models/cpf_role.dart';
import 'package:cpf_mobile/models/election_models.dart';
import 'package:cpf_mobile/screens/elections_screen.dart';
import 'package:cpf_mobile/screens/events_screen.dart';
import 'package:cpf_mobile/screens/home_shell.dart';
import 'package:cpf_mobile/screens/landing_login_screen.dart';
import 'package:cpf_mobile/screens/password_change_required_screen.dart';
import 'package:cpf_mobile/screens/payments_screen.dart';
import 'package:cpf_mobile/screens/peer_dashboard_screen.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/elections_service.dart';
import 'package:cpf_mobile/services/events_service.dart';
import 'package:cpf_mobile/services/local_db_service.dart';
import 'package:cpf_mobile/services/membership_payment_service.dart';
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

  final Map<int, List<ManualChecklistEntry>> _checklists =
      <int, List<ManualChecklistEntry>>{};

  @override
  Future<List<ManualChecklistEntry>> readEventChecklist(int eventId) async =>
      List<ManualChecklistEntry>.from(
        _checklists[eventId] ?? const <ManualChecklistEntry>[],
      );

  @override
  Future<void> writeEventChecklist(
    int eventId,
    List<ManualChecklistEntry> entries,
  ) async {
    _checklists[eventId] = List<ManualChecklistEntry>.from(entries);
  }

  @override
  Future<void> clearAllEventChecklists() async {
    _checklists.clear();
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
    test('supports all 11 native roles, gates guidance_counselor, and rejects admin', () {
      expect(CpfRole.values.length, 11);
      expect(CpfRole.fromApi('adviser'), CpfRole.adviser);
      expect(CpfRole.fromApi('guidance_counselor'), CpfRole.guidanceCounselor);
      expect(CpfRole.fromApi('president'), CpfRole.president);
      expect(CpfRole.fromApi('vice_president'), CpfRole.vicePresident);
      expect(CpfRole.fromApi('secretary'), CpfRole.secretary);
      expect(CpfRole.fromApi('treasurer'), CpfRole.treasurer);
      expect(CpfRole.fromApi('auditor'), CpfRole.auditor);
      expect(CpfRole.fromApi('business_manager'), CpfRole.businessManager);
      expect(CpfRole.fromApi('pio'), CpfRole.pio);
      expect(CpfRole.fromApi('sergeant_at_arms'), CpfRole.sergeantAtArms);
      expect(CpfRole.fromApi('member'), CpfRole.member);

      expect(CpfRole.guidanceCounselor.isGuidanceCounselorOnly, isTrue);
      expect(CpfRole.guidanceCounselor.isOfficerOrAdviser, isFalse);
      expect(CpfRole.adviser.isGuidanceCounselorOnly, isFalse);

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
        localDb: LocalDbService(inMemoryOnly: true),
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
        localDb: LocalDbService(inMemoryOnly: true),
      );
      await tester.runAsync(
        () => authController.signInWithEmail(
          email: 'sofia@chmsu.edu.ph',
          password: 'secret',
        ),
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

  testWidgets(
    'Guidance Counselor role hides Events, Dues, Elections, and Messenger GC tabs in HomeShell',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      final themeController = ThemeController();
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      apiClient.dio.httpClientAdapter = _StubAdapter((_) {
        return ResponseBody.fromString(
          '{"token_type":"Bearer","token":"1|gc","user":{"id":25,"name":"Soriano, Clarissa D.","email":"counselor@chmsu.edu.ph","must_change_password":false},"verified_role":"guidance_counselor","verified_role_label":"Guidance Counselor","is_alumni":false,"permissions":{"is_officer_or_adviser":false,"is_club_adviser":false,"can_propose_events":false,"can_scan_attendance":false,"can_access_archive":true},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":false,"member_id_code":null,"qr_payload":null}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );
      await tester.runAsync(
        () => authController.signInWithEmail(
          email: 'counselor@chmsu.edu.ph',
          password: 'secret',
        ),
      );

      expect(authController.profile?.isGuidanceCounselorOnly, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeController.themeData,
          home: HomeShell(
            authController: authController,
            eventsService: EventsService(apiClient),
            paymentService: MembershipPaymentService(apiClient),
            electionsService: ElectionsService(apiClient),
            storage: storage,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coordination-Only Role'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Events'), findsNothing);
      expect(find.text('Dues'), findsNothing);
      expect(find.text('Elections'), findsNothing);
      expect(find.text('Messenger GC A–Z Checklist'), findsNothing);
    },
  );

  testWidgets(
    'PasswordChangeRequiredScreen submits new password via /auth/password/force-change, unlocks QR pass, and transitions into HomeShell',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|tempToken',
      });
      final themeController = ThemeController();
      final localDb = LocalDbService(inMemoryOnly: true);
      var triggered = false;
      RequestOptions? forceChangeRequest;

      final apiClient = ApiClient(
        apiConfig: apiConfig,
        storage: storage,
        onMustChangePasswordRequired: () => triggered = true,
      );
      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        if (options.path.endsWith('/events')) {
          return ResponseBody.fromString(
            '{"code":"must_change_password_required","message":"Password change required."}',
            403,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path.endsWith('/auth/login')) {
          return ResponseBody.fromString(
            '{"token_type":"Bearer","token":"1|tempToken","user":{"id":19,"name":"Reyes, Katrina M.","email":"katrina@chmsu.edu.ph","must_change_password":true},"verified_role":"member","verified_role_label":"Member","is_alumni":false,"permissions":{"is_officer_or_adviser":false,"is_club_adviser":false,"can_propose_events":false,"can_scan_attendance":false,"can_access_archive":false},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":false,"member_id_code":null,"qr_payload":null}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path.endsWith('/auth/password/force-change')) {
          forceChangeRequest = options;
          return ResponseBody.fromString(
            '{"status":"password_updated","user":{"id":19,"name":"Reyes, Katrina M.","email":"katrina@chmsu.edu.ph","must_change_password":false},"verified_role":"member","verified_role_label":"Member","is_alumni":false,"permissions":{"is_officer_or_adviser":false,"is_club_adviser":false,"can_propose_events":false,"can_scan_attendance":false,"can_access_archive":false},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0019","qr_payload":"CPF|campus:ALIJIS|user:19|role:member|sig:unlocked123"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      await tester.runAsync(() async {
        await expectLater(
          () => apiClient.dio.get<dynamic>('/events'),
          throwsA(isA<DioException>()),
        );
      });
      expect(triggered, isTrue);

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: localDb,
      );
      await tester.runAsync(
        () => authController.signInWithEmail(
          email: 'katrina@chmsu.edu.ph',
          password: 'TempPassword1!',
        ),
      );
      expect(authController.requiresPasswordChange, isTrue);
      expect(authController.profile?.qrUnlocked, isFalse);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: authController,
          builder: (context, _) {
            return MaterialApp(
              theme: themeController.themeData,
              home: authController.requiresPasswordChange
                  ? PasswordChangeRequiredScreen(
                      authController: authController,
                      apiConfig: apiConfig,
                      themeController: themeController,
                      storage: storage,
                    )
                  : HomeShell(
                      authController: authController,
                      eventsService: EventsService(apiClient),
                      paymentService: MembershipPaymentService(apiClient),
                      electionsService: ElectionsService(apiClient),
                      storage: storage,
                      themeController: themeController,
                    ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Change Required'), findsOneWidget);
      expect(find.text('Update Password & Continue'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verify validation catches mismatched passwords before hitting API.
      await tester.enterText(
        find.byKey(const ValueKey<String>('force_new_password_field')),
        'PersonalSecret2026!',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('force_confirm_password_field')),
        'DifferentSecret2026!',
      );
      await tester.ensureVisible(find.text('Update Password & Continue'));
      await tester.tap(find.text('Update Password & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(forceChangeRequest, isNull);

      // Submit matching valid password and transition cleanly into HomeShell.
      await tester.enterText(
        find.byKey(const ValueKey<String>('force_confirm_password_field')),
        'PersonalSecret2026!',
      );
      await tester.ensureVisible(find.text('Update Password & Continue'));
      await tester.tap(find.text('Update Password & Continue'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(forceChangeRequest, isNotNull);
      expect(
        forceChangeRequest?.headers['Authorization'],
        'Bearer 1|tempToken',
      );
      expect(
        forceChangeRequest?.data,
        <String, dynamic>{
          'password': 'PersonalSecret2026!',
          'password_confirmation': 'PersonalSecret2026!',
        },
      );
      expect(authController.requiresPasswordChange, isFalse);
      expect(authController.profile?.user.mustChangePassword, isFalse);
      expect(authController.profile?.qrUnlocked, isTrue);

      final cached = await localDb.readCachedProfile();
      expect(cached?.user.mustChangePassword, isFalse);
      expect(cached?.qrUnlocked, isTrue);
      expect(cached?.qrPayload, 'CPF|campus:ALIJIS|user:19|role:member|sig:unlocked123');

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  group('Two-Factor Authentication (two_factor_required) login & passkey flow', () {
    test(
      'detects HTTP 422 two_factor_required on email login and retries with 6-digit code',
      () async {
        final apiConfig = ApiConfig();
        final storage = _InMemorySecureStorage();
        final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
        final sentPayloads = <Map<String, dynamic>>[];

        apiClient.dio.httpClientAdapter = _StubAdapter((options) {
          final body = Map<String, dynamic>.from(options.data as Map);
          sentPayloads.add(body);

          if (body['code'] == null) {
            return ResponseBody.fromString(
              '{"message":"Two-factor authentication code is required.","two_factor_required":true,"errors":{"code":["Enter your 6-digit code."]}}',
              422,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }

          if (body['code'] != '654321') {
            return ResponseBody.fromString(
              '{"message":"The provided two-factor authentication code was invalid.","two_factor_required":true}',
              422,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }

          return ResponseBody.fromString(
            '{"token_type":"Bearer","token":"2|verified2fa","user":{"id":12,"name":"Mercado, Sofia R.","email":"sofia@chmsu.edu.ph","must_change_password":false},"verified_role":"president","verified_role_label":"President","is_alumni":false,"permissions":{"is_officer_or_adviser":true,"is_club_adviser":false,"can_propose_events":true,"can_scan_attendance":true,"can_access_archive":true},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0012","qr_payload":"CPF|campus:ALIJIS|user:12|role:president|sig:2faok"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

        final authController = AuthController(
          apiConfig: apiConfig,
          storage: storage,
          apiClient: apiClient,
          authService: AuthService(apiClient),
          localDb: LocalDbService(inMemoryOnly: true),
        );

        final firstAttempt = await authController.signInWithEmail(
          email: 'sofia@chmsu.edu.ph',
          password: 'PersonalSecret2026!',
        );
        expect(firstAttempt, isFalse);
        expect(authController.isTwoFactorRequired, isTrue);
        expect(authController.errorMessage, isNull);
        expect(authController.isAuthenticated, isFalse);

        // Wrong code keeps 2FA challenge open with server error message.
        final wrongCodeAttempt =
            await authController.submitTwoFactorChallenge(code: '000000');
        expect(wrongCodeAttempt, isFalse);
        expect(authController.isTwoFactorRequired, isTrue);
        expect(authController.errorMessage, contains('invalid'));

        // Valid 6-digit code completes login and clears pending challenge.
        final verifiedAttempt =
            await authController.submitTwoFactorChallenge(code: '654321');
        expect(verifiedAttempt, isTrue);
        expect(authController.isTwoFactorRequired, isFalse);
        expect(authController.isAuthenticated, isTrue);
        expect(await storage.readToken(), '2|verified2fa');
        expect(sentPayloads.length, 3);
        expect(sentPayloads.last['code'], '654321');
        expect(sentPayloads.last.containsKey('recovery_code'), isFalse);
      },
    );

    test(
      'detects HTTP 422 two_factor_required on passkey claim and retries with recovery_code',
      () async {
        final apiConfig = ApiConfig();
        final storage = _InMemorySecureStorage();
        final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
        final sentPayloads = <Map<String, dynamic>>[];

        apiClient.dio.httpClientAdapter = _StubAdapter((options) {
          final body = Map<String, dynamic>.from(options.data as Map);
          sentPayloads.add(body);

          if (body['recovery_code'] != 'recov-998877') {
            return ResponseBody.fromString(
              '{"message":"Two-factor verification required.","two_factor_required":true}',
              422,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }

          return ResponseBody.fromString(
            '{"token_type":"Bearer","token":"3|passkey2fa","user":{"id":19,"name":"Reyes, Katrina M.","email":"katrina@chmsu.edu.ph","must_change_password":true},"verified_role":"member","verified_role_label":"Member","is_alumni":false,"permissions":{"is_officer_or_adviser":false,"is_club_adviser":false,"can_propose_events":false,"can_scan_attendance":false,"can_access_archive":false},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":false,"member_id_code":null,"qr_payload":null}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

        final authController = AuthController(
          apiConfig: apiConfig,
          storage: storage,
          apiClient: apiClient,
          authService: AuthService(apiClient),
          localDb: LocalDbService(inMemoryOnly: true),
        );

        final firstAttempt = await authController.signInWithPasskey(
          email: 'katrina@chmsu.edu.ph',
          passkeyCode: 'ABCD-EFGH-JKLM',
        );
        expect(firstAttempt, isFalse);
        expect(authController.isTwoFactorRequired, isTrue);
        expect(
          authController.pendingTwoFactor?.method,
          TwoFactorLoginMethod.passkeyCode,
        );

        final secondAttempt = await authController.submitTwoFactorChallenge(
          recoveryCode: 'recov-998877',
        );
        expect(secondAttempt, isTrue);
        expect(authController.isTwoFactorRequired, isFalse);
        expect(authController.isAuthenticated, isTrue);
        expect(authController.requiresPasswordChange, isTrue);
        expect(sentPayloads.last['passkey_code'], 'ABCD-EFGH-JKLM');
        expect(sentPayloads.last['recovery_code'], 'recov-998877');
        expect(sentPayloads.last.containsKey('code'), isFalse);
      },
    );
  });

  testWidgets(
    'ElectionsScreen handles vacant seats, paused/completed chat wipe, and silent /auth/me role refresh',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|memberToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);

      var currentRole = 'member';
      var currentRoleLabel = 'Member';
      var meFetchCount = 0;
      var electionStatus = 'paused';

      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        if (options.path.endsWith('/auth/login') ||
            options.path.endsWith('/auth/me')) {
          if (options.path.endsWith('/auth/me')) {
            meFetchCount++;
          }
          return ResponseBody.fromString(
            '{"token_type":"Bearer","token":"1|memberToken","user":{"id":19,"name":"Reyes, Katrina M.","email":"katrina@chmsu.edu.ph","must_change_password":false},"verified_role":"$currentRole","verified_role_label":"$currentRoleLabel","is_alumni":false,"permissions":{"is_officer_or_adviser":${currentRole != 'member'},"is_club_adviser":false,"can_propose_events":${currentRole == 'president'},"can_scan_attendance":${currentRole != 'member'},"can_access_archive":${currentRole != 'member'}},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0019","qr_payload":"CPF|campus:ALIJIS|user:19|role:$currentRole|sig:123456"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }

        if (options.path.endsWith('/elections/active')) {
          return ResponseBody.fromString(
            '{"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus"},"seats":[{"key":"president","label":"President","optional":false,"seat_order":1,"is_current":false,"result":{"status":"elected","winner_user_id":19,"winner_name":"Reyes, Katrina M."}},{"key":"auditor","label":"Auditor","optional":true,"seat_order":2,"is_current":false,"result":{"status":"vacant"}}],"active_election":{"id":5,"title":"AY 2026-2027 CPF General Election","academic_year":"2026-2027","status":"$electionStatus","current_position":"auditor","current_position_label":"Auditor","current_phase":"voting","round_number":1,"nominees":[],"current_position_nominees":[],"voting_status":{"can_nominate":false,"can_vote":false,"has_voted_current_round":false,"my_current_vote_candidate_id":null,"has_opted_out":false,"is_already_elected":true},"live_chat":{"enabled":true}}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }

        return ResponseBody.fromString('{}', 200);
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );

      await tester.runAsync(
        () => authController.signInWithEmail(
          email: 'katrina@chmsu.edu.ph',
          password: 'secret',
        ),
      );
      expect(authController.profile?.verifiedRole, CpfRole.member);

      // Update server-side role to newly elected President.
      currentRole = 'president';
      currentRoleLabel = 'President';

      await tester.pumpWidget(
        MaterialApp(
          theme: CpfThemes.themeDataFor(CpfThemeId.light),
          home: Scaffold(
            body: ElectionsScreen(
              authController: authController,
              electionsService: ElectionsService(apiClient),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Paused state hides Session Chat, renders Vacant seat badge, and syncs newly won seat.
      expect(find.text('SESSION PAUSED'), findsOneWidget);
      expect(find.text('Vacant'), findsOneWidget);
      expect(find.textContaining('Session Chat'), findsNothing);
      expect(meFetchCount, greaterThanOrEqualTo(1));
      expect(authController.profile?.verifiedRole, CpfRole.president);

      // Transition election to completed and pull-to-refresh.
      electionStatus = 'completed';
      final prevMeFetches = meFetchCount;
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('ELECTION COMPLETED'), findsOneWidget);
      expect(find.text('Vacant'), findsOneWidget);
      expect(find.textContaining('Session Chat'), findsNothing);
      expect(meFetchCount, greaterThan(prevMeFetches));

      // Unit-verify ActiveElectionSession runoff & already-elected eligibility.
      final session = ActiveElectionSession.fromJson(<String, dynamic>{
        'id': 9,
        'status': 'open',
        'current_position': 'vice_president',
        'current_phase': 'tie_breaker',
        'round_number': 2,
        'position_results': <String, dynamic>{
          'president': <String, dynamic>{
            'status': 'elected',
            'winner_user_id': 19,
          },
        },
        'current_position_nominees': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'user_id': 20,
            'name': 'Contender A',
            'position': 'vice_president',
            'nomination_status': 'accepted',
            'is_tie_contender': true,
            'votes': 5,
          },
          <String, dynamic>{
            'id': 2,
            'user_id': 21,
            'name': 'Non-Contender B',
            'position': 'vice_president',
            'nomination_status': 'accepted',
            'is_tie_contender': false,
            'votes': 2,
          },
          <String, dynamic>{
            'id': 3,
            'user_id': 19,
            'name': 'Already Elected Winner',
            'position': 'vice_president',
            'nomination_status': 'accepted',
            'is_tie_contender': true,
            'votes': 5,
          },
        ],
        'voting_status': <String, dynamic>{
          'can_nominate': false,
          'can_vote': true,
        },
      });
      expect(
        session.isCandidateEligibleForCurrentRound(
          session.currentPositionNominees[0],
        ),
        isTrue,
      );
      expect(
        session.isCandidateEligibleForCurrentRound(
          session.currentPositionNominees[1],
        ),
        isFalse,
      );
      expect(
        session.isCandidateEligibleForCurrentRound(
          session.currentPositionNominees[2],
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'EventsScreen treats both scheduled and upcoming events as Upcoming [L-01]',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|memberToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        return ResponseBody.fromString(
          '{"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus"},"can_scan_events":false,"events":[{"id":1,"title":"Scheduled Seminar","location":"AVR","event_date":"2026-12-01","event_date_label":"Dec 1, 2026","start_time":"09:00","end_time":"11:00","status":"approved","effective_status":"scheduled","reflection_enabled":false,"logged_in_count":0,"logged_out_count":0,"can_scan":false,"my_attendance":{"status":"not_checked_in"}},{"id":2,"title":"Upcoming Workshop","location":"Room 102","event_date":"2026-12-05","event_date_label":"Dec 5, 2026","start_time":"13:00","end_time":"15:00","status":"approved","effective_status":"upcoming","reflection_enabled":false,"logged_in_count":0,"logged_out_count":0,"can_scan":false,"my_attendance":{"status":"not_checked_in"}},{"id":3,"title":"Active Assembly","location":"Gym","event_date":"2026-11-26","event_date_label":"Nov 26, 2026","start_time":"08:00","end_time":"17:00","status":"approved","effective_status":"active","reflection_enabled":false,"logged_in_count":10,"logged_out_count":0,"can_scan":true,"my_attendance":{"status":"logged_in"}},{"id":4,"title":"Completed Orientation","location":"Hall","event_date":"2026-10-01","event_date_label":"Oct 1, 2026","start_time":"08:00","end_time":"10:00","status":"approved","effective_status":"completed","reflection_enabled":false,"logged_in_count":20,"logged_out_count":20,"can_scan":false,"my_attendance":{"status":"completed"}}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CpfThemes.themeDataFor(CpfThemeId.light),
          home: Scaffold(
            body: EventsScreen(
              authController: authController,
              eventsService: EventsService(apiClient),
              storage: storage,
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Tap Upcoming filter -> shows both 'scheduled' and 'upcoming' events.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled Seminar'), findsOneWidget);
      expect(find.text('Upcoming Workshop'), findsOneWidget);
      expect(find.text('Active Assembly'), findsNothing);
      expect(find.text('Completed Orientation'), findsNothing);

      // Tap Past / Other filter -> excludes scheduled & upcoming.
      await tester.tap(find.text('Past / Other'));
      await tester.pumpAndSettle();
      expect(find.text('Completed Orientation'), findsOneWidget);
      expect(find.text('Scheduled Seminar'), findsNothing);
      expect(find.text('Upcoming Workshop'), findsNothing);
    },
  );

  testWidgets(
    'ElectionsScreen renders completed_election when active_election is null and supports pending nominee Accept/Decline [H-07]',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|memberToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);

      var mode = 'completed_only';
      RequestOptions? respondRequest;

      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        if (options.path.endsWith('/auth/login') ||
            options.path.endsWith('/auth/me')) {
          return ResponseBody.fromString(
            '{"token_type":"Bearer","token":"1|memberToken","user":{"id":19,"name":"Reyes, Katrina M.","email":"katrina@chmsu.edu.ph","must_change_password":false},"verified_role":"member","verified_role_label":"Member","is_alumni":false,"permissions":{"is_officer_or_adviser":false,"is_club_adviser":false,"can_propose_events":false,"can_scan_attendance":false,"can_access_archive":false},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0019","qr_payload":"CPF|campus:ALIJIS|user:19|role:member|sig:abc"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }

        if (options.path.contains('/candidates/77/respond')) {
          respondRequest = options;
          mode = 'accepted';
          return ResponseBody.fromString(
            '{"status":"accepted","nomination_status":"accepted"}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }

        if (options.path.endsWith('/elections/active')) {
          if (mode == 'completed_only') {
            return ResponseBody.fromString(
              '{"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus"},"seats":[],"active_election":null,"completed_election":{"id":10,"title":"AY 2026-2027 Finalized Election","academic_year":"2026-2027","status":"completed","current_phase":"completed","round_number":1,"position_results":{"president":{"status":"elected","winner_user_id":12,"winner_name":"Mercado, Sofia R."},"auditor":{"status":"vacant"}}}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }

          final nomStatus = mode == 'accepted' ? 'accepted' : 'pending';
          return ResponseBody.fromString(
            '{"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus"},"seats":[{"key":"president","label":"President","optional":false,"seat_order":1,"is_current":true,"result":null}],"active_election":{"id":11,"title":"AY 2026-2027 Open Election","academic_year":"2026-2027","status":"open","current_position":"president","current_position_label":"President","current_phase":"nomination","round_number":1,"nominees":[],"current_position_nominees":[{"id":77,"user_id":19,"name":"Reyes, Katrina M.","course_year_section":"BSIT 4A","position":"president","nomination_status":"$nomStatus","is_tie_contender":false,"votes":0}],"voting_status":{"can_nominate":false,"can_vote":false,"has_voted_current_round":false,"has_opted_out":false},"live_chat":{"enabled":true}}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }

        return ResponseBody.fromString('{}', 200);
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );
      await tester.runAsync(
        () => authController.signInWithEmail(
          email: 'katrina@chmsu.edu.ph',
          password: 'secret',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CpfThemes.themeDataFor(CpfThemeId.light),
          home: Scaffold(
            body: ElectionsScreen(
              authController: authController,
              electionsService: ElectionsService(apiClient),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Renders completed_election slate even though active_election is null.
      expect(find.text('ELECTION COMPLETED'), findsOneWidget);
      expect(find.text('AY 2026-2027 Finalized Election'), findsOneWidget);
      expect(find.text('Mercado, Sofia R.'), findsOneWidget);
      expect(find.text('Vacant'), findsOneWidget);

      // Switch backend to an open election with a pending nomination for user 19.
      mode = 'pending_nominee';
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(respondRequest, isNotNull);
      expect(
        respondRequest?.path,
        '/elections/11/candidates/77/respond',
      );
      expect(respondRequest?.method, 'PATCH');
      expect(
        (respondRequest?.data as Map<String, dynamic>?)?['decision'],
        'accepted',
      );
      expect(find.text('Accept'), findsNothing);
    },
  );

  testWidgets(
    'PaymentsScreen attaches receipt image bytes and displays receipt badges [H-04]',
    (WidgetTester tester) async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|memberToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      RequestOptions? submitRequest;

      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        if (options.path.endsWith('/payments')) {
          return ResponseBody.fromString(
            '{"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus"},"my_dues_status":{"has_paid_dues":false},"permissions":{"can_validate_payments":false,"can_audit_finances":false},"destinations":[{"id":1,"channel":"GCash","account_name":"CPF Alijis","account_number":"0917-000-1111"}],"my_submissions":[{"id":9,"user_id":19,"member_name":"Reyes, Katrina M.","destination_id":1,"channel":"GCash","purpose":"Membership Dues","amount":100,"reference_number":"GCASH-111","has_receipt":true,"status":"pending"}],"validation_queue":[]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path.endsWith('/payments/submit')) {
          submitRequest = options;
          return ResponseBody.fromString('{"status":"submitted"}', 201);
        }
        return ResponseBody.fromString('{}', 200);
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CpfThemes.themeDataFor(CpfThemeId.light),
          home: Scaffold(
            body: PaymentsScreen(
              authController: authController,
              paymentService: MembershipPaymentService(apiClient),
              pickReceiptImage: () async => PickedReceiptImage(
                bytes: Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
                fileName: 'gcash_receipt.png',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Attach Receipt Screenshot'));
      await tester.tap(find.text('Attach Receipt Screenshot'));
      await tester.pumpAndSettle();

      expect(find.text('ATTACHED'), findsOneWidget);
      expect(find.text('gcash_receipt.png'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reference No.'),
        'GCASH-778899',
      );
      await tester.ensureVisible(find.text('Submit Payment'));
      await tester.tap(find.text('Submit Payment'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(submitRequest, isNotNull);
      expect(submitRequest?.data, isA<FormData>());
      expect(find.text('Receipt Uploaded'), findsOneWidget);
    },
  );

  group('Manual checklist & shared-device / offline QR hygiene [L-02, M-05]', () {
    test('EventsService fetches A–Z checklist and posts manual-attendance', () async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|officerToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      RequestOptions? manualReq;

      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        if (options.path.endsWith('/events/4/checklist')) {
          return ResponseBody.fromString(
            '{"logged_in_count":1,"logged_out_count":0,"checklist":[{"user_id":2,"full_name_last_first_mi":"Santos, Marco P.","course_year_section":"BSIT 3A","logged_in_at":null,"logged_out_at":null},{"user_id":1,"full_name_last_first_mi":"Alvarez, Hannah G.","course_year_section":"BSIT 4A","logged_in_at":"2026-11-26T09:00:00Z","logged_out_at":null}]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        if (options.path.endsWith('/events/4/manual-attendance')) {
          manualReq = options;
          return ResponseBody.fromString(
            '{"status":"logged_in","member_name":"Santos, Marco P.","course_year_section":"BSIT 3A","attendance":{"id":10,"campus_event_id":4,"user_id":2,"logged_in_at":"2026-11-26T09:10:00Z"}}',
            201,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromString('{}', 200);
      });

      final service = EventsService(apiClient);
      final checklist = await service.fetchEventChecklist(4);
      expect(checklist.entries.length, 2);
      expect(checklist.entries.first.memberName, 'Alvarez, Hannah G.');
      expect(checklist.entries.first.isCheckedIn, isTrue);
      expect(checklist.entries.last.memberName, 'Santos, Marco P.');

      final res = await service.recordManualAttendance(
        eventId: 4,
        userId: 2,
        scanType: 'login',
      );
      expect(res.status, 'logged_in');
      expect(manualReq?.data, <String, dynamic>{
        'user_id': 2,
        'scan_type': 'login',
      });
    });

    test('signOut and handleUnauthorized clear event checklists and LocalDbService expires QR cache after 7 days', () async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|sharedToken',
      });
      await storage.writeEventChecklist(
        4,
        const <ManualChecklistEntry>[
          ManualChecklistEntry(
            userId: 2,
            identifier: 'CPF-1',
            memberName: 'Santos, Marco P.',
            lastStatus: 'logged_in',
          ),
        ],
      );
      expect((await storage.readEventChecklist(4)).length, 1);

      var now = DateTime(2026, 11, 20, 9, 0);
      final localDb = LocalDbService(inMemoryOnly: true, clock: () => now);
      final sampleProfile = AuthProfile.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'id': 12,
          'name': 'Mercado, Sofia R.',
          'email': 'sofia@chmsu.edu.ph',
          'must_change_password': false,
        },
        'verified_role': 'president',
        'is_alumni': false,
        'qr_unlocked': true,
        'qr_payload': 'CPF|campus:ALIJIS|user:12|role:president|sig:valid',
      });

      await localDb.cacheProfile(sampleProfile);
      now = now.add(const Duration(days: 6, hours: 23));
      expect(await localDb.readCachedProfile(), isNotNull);
      expect(localDb.lastReadWasStale, isFalse);

      // Advance past 7 days -> offline QR cache is rejected & wiped.
      now = now.add(const Duration(hours: 2));
      expect(await localDb.readCachedProfile(), isNull);
      expect(localDb.lastReadWasStale, isTrue);

      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      apiClient.dio.httpClientAdapter = _StubAdapter(
        (_) => ResponseBody.fromString('{"status":"logged_out"}', 200),
      );
      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: localDb,
      );

      await authController.signOut();
      expect(await storage.readEventChecklist(4), isEmpty);

      // Also verify handleUnauthorized clears checklists.
      await storage.writeEventChecklist(
        5,
        const <ManualChecklistEntry>[
          ManualChecklistEntry(
            userId: 3,
            identifier: 'CPF-2',
            memberName: 'Reyes, Katrina M.',
            lastStatus: 'logged_in',
          ),
        ],
      );
      authController.handleUnauthorized();
      await Future<void>.delayed(Duration.zero);
      expect(await storage.readEventChecklist(5), isEmpty);
    });

    test('ElectionsService.respondToNomination sends accepted/declined decision payload [HIGH-05]', () async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage(<String, String>{
        'token': '1|memberToken',
      });
      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      final sentPayloads = <Map<String, dynamic>>[];

      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        final body = Map<String, dynamic>.from(options.data as Map);
        sentPayloads.add(body);
        return ResponseBody.fromString(
          '{"nomination_status":"${body['decision']}"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final service = ElectionsService(apiClient);
      final acceptedStatus = await service.respondToNomination(
        electionId: 11,
        candidateId: 77,
        accept: true,
      );
      final declinedStatus = await service.respondToNomination(
        electionId: 11,
        candidateId: 78,
        accept: false,
      );

      expect(acceptedStatus, 'accepted');
      expect(declinedStatus, 'declined');
      expect(sentPayloads[0]['decision'], 'accepted');
      expect(sentPayloads[0]['status'], 'accepted');
      expect(sentPayloads[1]['decision'], 'declined');
      expect(sentPayloads[1]['status'], 'declined');
    });

    test('AuthController._persistSession clears leftover event checklists on sign-in [MEDIUM-04]', () async {
      final apiConfig = ApiConfig();
      final storage = _InMemorySecureStorage();
      await storage.writeEventChecklist(
        42,
        const <ManualChecklistEntry>[
          ManualChecklistEntry(
            userId: 9,
            identifier: 'CPF-PREV-009',
            memberName: 'Previous Officer Roster Entry',
            lastStatus: 'logged_in',
          ),
        ],
      );
      expect((await storage.readEventChecklist(42)).length, 1);

      final apiClient = ApiClient(apiConfig: apiConfig, storage: storage);
      apiClient.dio.httpClientAdapter = _StubAdapter((options) {
        return ResponseBody.fromString(
          '{"token_type":"Bearer","token":"9|freshOfficerToken","user":{"id":22,"name":"Cruz, Paolo D.","email":"paolo@chmsu.edu.ph","must_change_password":false},"verified_role":"secretary","verified_role_label":"Secretary","is_alumni":false,"permissions":{"is_officer_or_adviser":true,"is_club_adviser":false,"can_propose_events":true,"can_scan_attendance":true,"can_access_archive":true},"campus":{"id":1,"code":"ALIJIS","name":"CHMSU Alijis Campus","slug":"alijis","current_academic_year":"2026-2027"},"qr_unlocked":true,"member_id_code":"CPF-ALIJIS-2026-0022","qr_payload":"CPF|campus:ALIJIS|user:22|role:secretary|sig:fresh"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final authController = AuthController(
        apiConfig: apiConfig,
        storage: storage,
        apiClient: apiClient,
        authService: AuthService(apiClient),
        localDb: LocalDbService(inMemoryOnly: true),
      );

      final okEmail = await authController.signInWithEmail(
        email: 'paolo@chmsu.edu.ph',
        password: 'Password123!',
      );
      expect(okEmail, isTrue);
      expect(await storage.readEventChecklist(42), isEmpty);
      expect(await storage.readToken(), '9|freshOfficerToken');

      // Also verify passkey sign-in clears leftover checklists via _persistSession.
      await storage.writeEventChecklist(
        43,
        const <ManualChecklistEntry>[
          ManualChecklistEntry(
            userId: 10,
            identifier: 'CPF-PREV-010',
            memberName: 'Another Leftover Entry',
            lastStatus: 'completed',
          ),
        ],
      );
      expect((await storage.readEventChecklist(43)).length, 1);

      final okPasskey = await authController.signInWithPasskey(
        email: 'paolo@chmsu.edu.ph',
        passkeyCode: 'ABCD-EFGH-JKLM',
      );
      expect(okPasskey, isTrue);
      expect(await storage.readEventChecklist(43), isEmpty);
    });
  });
}
