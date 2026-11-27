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
///
/// Submits the new password in-app via `POST /api/v1/auth/password/force-change`
/// using the existing authenticated Sanctum Bearer token.
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
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPassword() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final err = await widget.authController.forceChangePassword(
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submitError = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;
    final profile = widget.authController.profile;
    final spinnerColor = p.themeId.isDark ? p.bg : Colors.white;

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
                  child: Form(
                    key: _formKey,
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
                          'For your account security, set a new personal password below to unlock CPF Mobile and your Peer QR ID.',
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
                        if (_submitError != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: p.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 20,
                                  color: p.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _submitError!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: p.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey<String>('force_new_password_field'),
                          controller: _passwordController,
                          enabled: !_isSubmitting,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            helperText: 'Minimum 8 characters',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show new password'
                                  : 'Hide new password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) {
                              return 'Enter a new password.';
                            }
                            if (text.length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey<String>(
                            'force_confirm_password_field',
                          ),
                          controller: _confirmPasswordController,
                          enabled: !_isSubmitting,
                          obscureText: _obscureConfirmPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitNewPassword(),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.verified_user_outlined),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmPassword
                                  ? 'Show confirm password'
                                  : 'Hide confirm password',
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) {
                              return 'Confirm your new password.';
                            }
                            if (text != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submitNewPassword,
                          icon: _isSubmitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: spinnerColor,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Update Password & Continue'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => widget.authController.signOut(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.error,
                            side: BorderSide(
                              color: p.error.withValues(alpha: 0.5),
                            ),
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
      ),
    );
  }
}
