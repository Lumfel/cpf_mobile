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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passkeyEmailController = TextEditingController();
  final _passkeyCodeController = TextEditingController();

  _SignInTab _activeTab = _SignInTab.emailPassword;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passkeyEmailController.dispose();
    _passkeyCodeController.dispose();
    super.dispose();
  }

  String _rawPasskeyChars(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> _submitEmailLogin() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await widget.authController.signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _submitPasskeyLogin() async {
    if (!(_passkeyFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await widget.authController.signInWithPasskey(
      email: _passkeyEmailController.text,
      passkeyCode: _passkeyCodeController.text,
    );
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

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(context, p),
                  const SizedBox(height: 14),
                  _buildLandingHero(p),
                  const SizedBox(height: 18),
                  if (sessionNotice != null) ...[
                    _NoticeBanner(
                      icon: Icons.info_outline_rounded,
                      color: p.accent,
                      message: sessionNotice,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (error != null) ...[
                    _NoticeBanner(
                      icon: Icons.error_outline_rounded,
                      color: p.error,
                      message: error,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildSignInCard(p, isLoading),
                  const SizedBox(height: 16),
                  _buildPrivacyFooter(context, p),
                ],
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
        const CpfEmblem(size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPF Mobile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              Text(
                'Circle of Peer Facilitators',
                style: TextStyle(
                  fontSize: 12,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          icon: Icon(
            Icons.dns_outlined,
            size: 16,
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

  Widget _buildLandingHero(CpfPalette p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(22),
        border: p.themeId.isDark ? Border.all(color: p.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.themeId.isDark ? 0.3 : 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CpfEmblem(size: 36),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: p.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'CHMSU PEER FACILITATORS',
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'One safe campus space for peer care and attendance.',
            style: TextStyle(
              color: p.heroText,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with your verified account or one-time 12-character passkey to access your official Peer QR ID and campus activities.',
            style: TextStyle(
              color: p.heroMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.qr_code_2_rounded,
                label: 'Verified Peer QR',
                palette: p,
              ),
              _HeroPill(
                icon: Icons.event_available_rounded,
                label: 'Campus Events',
                palette: p,
              ),
              _HeroPill(
                icon: Icons.wb_sunny_outlined,
                label: 'Daily Quotes',
                palette: p,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard(CpfPalette p, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Member Sign In',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Server: ${widget.apiConfig.baseUrl}',
            style: TextStyle(
              fontSize: 11.5,
              color: p.muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
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
                            setState(() => _activeTab = _SignInTab.passkeyCode);
                          },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_activeTab == _SignInTab.emailPassword)
            _buildEmailPasswordForm(p, isLoading)
          else
            _buildPasskeyForm(p, isLoading),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: p.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_key_rounded, size: 18, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'One-time 12-character claim code (e.g. ABCD-EFGH-JKLM).',
                    style: TextStyle(
                      fontSize: 12,
                      color: p.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: p.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Protected under RA 10173 (Data Privacy Act).',
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ),
          TextButton(
            onPressed: () => showDataPrivacyModal(context),
            child: const Text(
              'Data Privacy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final CpfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.heroCardElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.heroText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
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
