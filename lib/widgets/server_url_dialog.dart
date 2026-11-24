import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// Opens a dialog allowing demo testers to point the app at a Cloudflare
/// Tunnel HTTPS URL or a local server (`127.0.0.1:8000` / `10.0.2.2:8000`)
/// and verify connectivity against `GET /api/v1/health`.
Future<void> showServerUrlDialog(
  BuildContext context, {
  required ApiConfig apiConfig,
  required SecureStorageService storage,
  Dio? healthCheckDio,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ServerUrlDialog(
      apiConfig: apiConfig,
      storage: storage,
      healthCheckDio: healthCheckDio,
    ),
  );
}

class _ServerUrlDialog extends StatefulWidget {
  const _ServerUrlDialog({
    required this.apiConfig,
    required this.storage,
    this.healthCheckDio,
  });

  final ApiConfig apiConfig;
  final SecureStorageService storage;
  final Dio? healthCheckDio;

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _HealthCheckResult {
  const _HealthCheckResult({
    required this.isHealthy,
    required this.message,
  });

  final bool isHealthy;
  final String message;
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late final TextEditingController _controller;
  late final Dio _dio;
  String? _errorText;
  bool _saving = false;
  bool _testing = false;
  _HealthCheckResult? _healthResult;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.apiConfig.baseUrl);
    _dio = widget.healthCheckDio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            headers: const <String, dynamic>{
              'Accept': 'application/json',
            },
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(String url) {
    setState(() {
      _controller.text = url;
      _errorText = null;
      _healthResult = null;
    });
  }

  Future<void> _testConnection() async {
    final raw = _controller.text.trim();
    if (!ApiConfig.isValidUrl(raw)) {
      setState(() {
        _errorText =
            'Enter a valid http:// or https:// URL (no spaces, valid host).';
        _healthResult = null;
      });
      return;
    }

    final normalized = ApiConfig.normalizeBaseUrl(raw);
    final healthUrl = '$normalized/api/v1/health';

    setState(() {
      _testing = true;
      _errorText = null;
      _healthResult = null;
    });

    try {
      final response = await _dio.get<dynamic>(healthUrl);
      if (!mounted) return;

      final data = response.data;
      bool unhealthyPayload = false;
      String? detailMessage;

      if (data is Map) {
        final ok = data['ok'];
        final db = data['database'] ?? data['db'];
        final status = data['status']?.toString().toLowerCase();
        if (ok == false ||
            db == false ||
            status == 'error' ||
            status == 'unhealthy') {
          unhealthyPayload = true;
          detailMessage = data['message']?.toString();
        }
      }

      if (response.statusCode == 200 && !unhealthyPayload) {
        setState(() {
          _healthResult = const _HealthCheckResult(
            isHealthy: true,
            message: 'Connected to CPF API + DB',
          );
        });
      } else {
        setState(() {
          _healthResult = _HealthCheckResult(
            isHealthy: false,
            message: detailMessage?.isNotEmpty == true
                ? detailMessage!
                : 'Health check failed (HTTP ${response.statusCode ?? 'error'}).',
          );
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      String msg;
      final respData = e.response?.data;
      if (respData is Map && respData['message'] != null) {
        msg = respData['message'].toString();
      } else if (status != null) {
        msg = 'Health check failed (HTTP $status).';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        msg = 'Connection timed out reaching $healthUrl.';
      } else {
        msg = 'Cannot reach $healthUrl. Check server & CORS.';
      }
      setState(() {
        _healthResult = _HealthCheckResult(isHealthy: false, message: msg);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthResult = _HealthCheckResult(
          isHealthy: false,
          message: 'Health check error: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (!ApiConfig.isValidUrl(raw)) {
      setState(() {
        _errorText =
            'Enter a valid http:// or https:// URL (no spaces, valid host).';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await widget.apiConfig.updateBaseUrl(raw, widget.storage);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL set to ${widget.apiConfig.apiBaseUrl}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _reset() async {
    setState(() {
      _saving = true;
      _errorText = null;
      _healthResult = null;
    });
    await widget.apiConfig.resetToDefault(widget.storage);
    if (!mounted) return;
    _controller.text = widget.apiConfig.baseUrl;
    setState(() {
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final busy = _saving || _testing;
    final preview = ApiConfig.isValidUrl(_controller.text)
        ? '${ApiConfig.normalizeBaseUrl(_controller.text)}/api/v1'
        : 'Enter a valid http:// or https:// host';

    return AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.dns_rounded, color: p.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Server URL',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Point CPF Mobile to your Cloudflare Tunnel HTTPS URL or local Laravel server for testing.',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() {
                _errorText = null;
                _healthResult = null;
              }),
              decoration: InputDecoration(
                labelText: 'Server Root URL',
                hintText: 'https://your-tunnel.trycloudflare.com',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Text(
                'API endpoint: $preview',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: p.text,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.public_rounded, size: 16),
                  label: const Text('Local Chrome: http://127.0.0.1:8000'),
                  onPressed:
                      busy ? null : () => _applyPreset(defaultWebBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android_rounded, size: 16),
                  label: const Text('Emulator: http://10.0.2.2:8000'),
                  onPressed:
                      busy ? null : () => _applyPreset(defaultAndroidBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Reset Default'),
                  onPressed: busy ? null : _reset,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _testConnection,
                icon: _testing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.primary,
                        ),
                      )
                    : Icon(Icons.network_check_rounded, color: p.primary),
                label: Text(_testing ? 'Testing...' : 'Test Connection'),
              ),
            ),
            if (_healthResult != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (_healthResult!.isHealthy ? p.success : p.error)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_healthResult!.isHealthy ? p.success : p.error)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _healthResult!.isHealthy
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 18,
                      color: _healthResult!.isHealthy ? p.success : p.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _healthResult!.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color:
                              _healthResult!.isHealthy ? p.success : p.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.themeId.isDark ? p.bg : Colors.white,
                  ),
                )
              : const Text('Save URL'),
        ),
      ],
    );
  }
}
