import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';
import 'package:cpf_mobile/widgets/data_privacy_modal.dart';
import 'package:cpf_mobile/widgets/server_url_dialog.dart';
import 'package:cpf_mobile/widgets/theme_switcher_button.dart';

enum _SignInTab { emailPassword, passkeyCode }

/// Screen 1: Public Landing + Sign In (Email/Password & 12-Char Passkey Code
/// tabs + Data Privacy modal + Server URL config + Theme Switcher).
class PublicLandingLoginScreen extends StatefulWidget {
  const PublicLandingLoginScreen({
    super.key,
    required this.authController,
    required this.apiConfig,
    required this.storage,
    required this.themeController,
  });

  final AuthController authController;
  final ApiConfig apiConfig;
  final SecureStorageService storage;
  final ThemeController themeController;

  @override
  State<PublicLandingLoginScreen> createState() =>
      _PublicLandingLoginScreenState();
}

class _PublicLandingLoginScreenState extends State<PublicLandingLoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passkeyFormKey = GlobalKey<FormState>();
  final _twoFactorFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passkeyEmailController = TextEditingController();
  final _passkeyCodeController = TextEditingController();
  final _twoFactorCodeController = TextEditingController();
  final _recoveryCodeController = TextEditingController();

  _SignInTab _activeTab = _SignInTab.emailPassword;
  bool _obscurePassword = true;
  bool _useRecoveryCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passkeyEmailController.dispose();
    _passkeyCodeController.dispose();
    _twoFactorCodeController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  String _rawPasskeyChars(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> _submitEmailLogin() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    _twoFactorCodeController.clear();
    _recoveryCodeController.clear();
    _useRecoveryCode = false;
    await widget.authController.signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _submitPasskeyLogin() async {
    if (!(_passkeyFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    _twoFactorCodeController.clear();
    _recoveryCodeController.clear();
    _useRecoveryCode = false;
    await widget.authController.signInWithPasskey(
      email: _passkeyEmailController.text,
      passkeyCode: _passkeyCodeController.text,
    );
  }

  Future<void> _submitTwoFactorChallenge() async {
    if (!(_twoFactorFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await widget.authController.submitTwoFactorChallenge(
      code: _useRecoveryCode ? null : _twoFactorCodeController.text,
      recoveryCode: _useRecoveryCode ? _recoveryCodeController.text : null,
    );
  }

  void _cancelTwoFactor() {
    _twoFactorCodeController.clear();
    _recoveryCodeController.clear();
    setState(() => _useRecoveryCode = false);
    widget.authController.cancelTwoFactorChallenge();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.authController, widget.apiConfig]),
          builder: (context, _) {
            final isLoading = widget.authController.isLoading;
            final error = widget.authController.errorMessage;
            final sessionNotice = widget.authController.sessionExpiredNotice;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(context, p),
                      const SizedBox(height: 12),
                      _buildBrandStrip(p),
                      if (sessionNotice != null) ...[
                        const SizedBox(height: 10),
                        _NoticeBanner(
                          icon: Icons.info_outline_rounded,
                          color: p.accent,
                          message: sessionNotice,
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        _NoticeBanner(
                          icon: Icons.error_outline_rounded,
                          color: p.error,
                          message: error,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildSignInCard(p, isLoading),
                      const SizedBox(height: 10),
                      _buildPrivacyFooter(context, p),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CpfPalette p) {
    return Row(
      children: [
        const CpfEmblem(size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPF Mobile',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              Text(
                'Circle of Peer Facilitators',
                style: TextStyle(
                  fontSize: 11.5,
                  color: p.muted,
                ),
              ),
            ],
          ),
        ),
        ThemeSwitcherButton(
          themeController: widget.themeController,
          storage: widget.storage,
          iconOnly: true,
        ),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          onPressed: () => showServerUrlDialog(
            context,
            apiConfig: widget.apiConfig,
            storage: widget.storage,
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: p.card,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 34),
          ),
          icon: Icon(
            Icons.dns_outlined,
            size: 15,
            color: widget.apiConfig.isCustom ? p.success : p.primary,
          ),
          label: Text(
            'Server URL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandStrip(CpfPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(16),
        border: p.themeId.isDark ? Border.all(color: p.border) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: p.heroCardElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code_2_rounded, size: 22, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHMSU Peer Facilitators',
                  style: TextStyle(
                    color: p.heroText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Peer QR ID, campus events, dues & elections.',
                  style: TextStyle(
                    color: p.heroMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard(CpfPalette p, bool isLoading) {
    final challenge = widget.authController.pendingTwoFactor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge != null
                      ? 'Two-Factor Verification'
                      : 'Member Sign In',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  widget.apiConfig.baseUrl,
                  style: TextStyle(fontSize: 11, color: p.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (challenge != null)
            _buildTwoFactorChallengeForm(p, challenge, isLoading)
          else ...[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Email & Password',
                      selected: _activeTab == _SignInTab.emailPassword,
                      onTap: isLoading
                          ? null
                          : () {
                              widget.authController.clearMessages();
                              setState(
                                () => _activeTab = _SignInTab.emailPassword,
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _TabButton(
                      label: '12-Char Passkey',
                      selected: _activeTab == _SignInTab.passkeyCode,
                      onTap: isLoading
                          ? null
                          : () {
                              widget.authController.clearMessages();
                              setState(
                                () => _activeTab = _SignInTab.passkeyCode,
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_activeTab == _SignInTab.emailPassword)
              _buildEmailPasswordForm(p, isLoading)
            else
              _buildPasskeyForm(p, isLoading),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoFactorChallengeForm(
    CpfPalette p,
    PendingTwoFactorChallenge challenge,
    bool isLoading,
  ) {
    final spinnerColor = p.themeId.isDark ? p.bg : Colors.white;
    final methodLabel = challenge.method == TwoFactorLoginMethod.passkeyCode
        ? '12-Char Passkey'
        : 'Email & Password';

    return Form(
      key: _twoFactorFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security_rounded, size: 20, color: p.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${challenge.email} ($methodLabel)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _useRecoveryCode
                            ? 'Enter one of your single-use 2FA recovery codes to finish signing in.'
                            : 'Enter the 6-digit code from your authenticator app to finish signing in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: p.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!_useRecoveryCode)
            TextFormField(
              key: const ValueKey<String>('two_factor_code_field'),
              controller: _twoFactorCodeController,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitTwoFactorChallenge(),
              style: const TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 3.0,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
              decoration: const InputDecoration(
                labelText: '6-Digit Authenticator Code',
                hintText: '123456',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: (value) {
                final clean = (value ?? '').trim();
                if (clean.length != 6) {
                  return 'Enter the 6-digit code from your authenticator app.';
                }
                return null;
              },
            )
          else
            TextFormField(
              key: const ValueKey<String>('two_factor_recovery_field'),
              controller: _recoveryCodeController,
              enabled: !isLoading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitTwoFactorChallenge(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                labelText: 'Recovery Code',
                hintText: 'xxxxx-xxxxx',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Enter a valid recovery code.';
                }
                return null;
              },
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      widget.authController.clearMessages();
                      setState(() => _useRecoveryCode = !_useRecoveryCode);
                    },
              child: Text(
                _useRecoveryCode
                    ? 'Use 6-digit authenticator code instead'
                    : 'Use a recovery code instead',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: isLoading ? null : _submitTwoFactorChallenge,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: spinnerColor,
                    ),
                  )
                : const Text('Verify & Sign In'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isLoading ? null : _cancelTwoFactor,
            child: const Text('Back to Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailPasswordForm(CpfPalette p, bool isLoading) {
    final spinnerColor = p.themeId.isDark ? p.bg : Colors.white;

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'CHMSU Email',
              hintText: 'name@chmsu.edu.ph',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty || !text.contains('@')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitEmailLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter your password.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: isLoading ? null : _submitEmailLogin,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: spinnerColor,
                    ),
                  )
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasskeyForm(CpfPalette p, bool isLoading) {
    final cleanLength = _rawPasskeyChars(_passkeyCodeController.text).length;
    final onAccent = p.themeId.isDark ? p.bg : Colors.white;

    return Form(
      key: _passkeyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _passkeyEmailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'CHMSU Email',
              hintText: 'name@chmsu.edu.ph',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty || !text.contains('@')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _passkeyCodeController,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              _UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(14),
            ],
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitPasskeyLogin(),
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: '12-Char Passkey Code',
              hintText: 'ABCD-EFGH-JKLM',
              helperText: 'One-time 12-character claim code',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixText: '$cleanLength / 12',
            ),
            validator: (value) {
              final clean = _rawPasskeyChars(value ?? '');
              if (clean.length != 12) {
                return 'Passkey code must contain 12 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: onAccent,
            ),
            onPressed: isLoading ? null : _submitPasskeyLogin,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: onAccent,
                    ),
                  )
                : const Text('Claim Passkey & Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyFooter(BuildContext context, CpfPalette p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 15, color: p.success),
        const SizedBox(width: 6),
        Text(
          'RA 10173 protected',
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
        Text(' • ', style: TextStyle(fontSize: 12, color: p.muted)),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => showDataPrivacyModal(context),
          child: const Text(
            'Data Privacy',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Material(
      color: selected ? p.card : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? p.primary : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
