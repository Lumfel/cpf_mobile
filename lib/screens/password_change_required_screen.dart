import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/animated_entrance.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';
import 'package:cpf_mobile/widgets/theme_switcher_button.dart';

/// Blocking security gate shown whenever `user.must_change_password` is true
/// or any protected API responds with HTTP 403 `must_change_password_required`.
class PasswordChangeRequiredScreen extends StatefulWidget {
  const PasswordChangeRequiredScreen({
    super.key,
    required this.authController,
    required this.apiConfig,
    required this.themeController,
    required this.storage,
  });

  final AuthController authController;
  final ApiConfig apiConfig;
  final ThemeController themeController;
  final SecureStorageService storage;

  @override
  State<PasswordChangeRequiredScreen> createState() =>
      _PasswordChangeRequiredScreenState();
}

class _PasswordChangeRequiredScreenState
    extends State<PasswordChangeRequiredScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final err = await widget.authController.refreshProfile();
    if (!mounted) return;
    setState(() => _isRefreshing = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }

    if (widget.authController.requiresPasswordChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Temporary password is still active. Update it on the CPF web portal first, then tap Refresh Status.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final profile = widget.authController.profile;
    final changeUrl = '${widget.apiConfig.originUrl}/force-password-change';

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Row(
          children: [
            CpfEmblem(size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Security Verification',
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
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.accent.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 34,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Password Change Required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'For your account security, temporary and passkey-issued passwords must be replaced before accessing CPF Mobile features or your Peer QR ID.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: p.muted,
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                profile.displayName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: p.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.user.email,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update your password on the CPF web portal:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    changeUrl,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: p.primary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy web portal link',
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: changeUrl),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied password portal URL'),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: p.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _isRefreshing ? null : _refreshStatus,
                        icon: _isRefreshing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.themeId.isDark ? p.bg : Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Status'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isRefreshing
                            ? null
                            : () => widget.authController.signOut(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.error,
                          side: BorderSide(color: p.error.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
