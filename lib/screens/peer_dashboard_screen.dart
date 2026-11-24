import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/state/auth_controller.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';
import 'package:cpf_mobile/widgets/cpf_emblem.dart';
import 'package:cpf_mobile/widgets/data_privacy_modal.dart';

/// Screen 2: QR-First Peer Dashboard displaying the member's official QR
/// strictly inside a pure white (`#FFFFFF`) quiet-zone box with dark
/// (`#0F172A`) modules across all 5 themes, daily quote, and quick links.
class PeerDashboardScreen extends StatelessWidget {
  const PeerDashboardScreen({
    super.key,
    required this.authController,
    required this.onOpenEvents,
  });

  final AuthController authController;
  final VoidCallback onOpenEvents;

  Future<void> _handleRefresh(BuildContext context) async {
    final err = await authController.refreshProfile();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  void _copyMemberId(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied Member ID: $code')),
    );
  }

  void _showExpandedQr(BuildContext context, AuthProfile profile) {
    final payload = profile.qrPayload;
    if (payload == null || payload.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final p = dialogContext.cpf;
        return Dialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.effectiveRoleLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
                  ),
                ),
                const SizedBox(height: 16),
                // Strictly pure white quiet-zone box across ALL 5 themes.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CpfPalette.qrQuietZoneBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.border),
                  ),
                  child: QrImageView(
                    data: payload,
                    size: 230,
                    backgroundColor: CpfPalette.qrQuietZoneBackground,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    gapless: true,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: CpfPalette.qrModuleColor,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: CpfPalette.qrModuleColor,
                    ),
                  ),
                ),
                if (profile.memberIdCode != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    profile.memberIdCode!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMembershipInfoSheet(BuildContext context, AuthProfile profile) {
    final campus = profile.campus;
    final membership = profile.membership;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final p = sheetContext.cpf;
        return Container(
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Membership & Campus Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoTile(label: 'Full Name', value: profile.displayName),
                  _InfoTile(label: 'Email', value: profile.user.email),
                  _InfoTile(label: 'Role', value: profile.effectiveRoleLabel),
                  if (campus != null) ...[
                    _InfoTile(
                      label: 'Campus',
                      value: '${campus.name} (${campus.code})',
                    ),
                    if (campus.currentAcademicYear.isNotEmpty)
                      _InfoTile(
                        label: 'Academic Year',
                        value: campus.currentAcademicYear,
                      ),
                    if (campus.gcGroupName != null &&
                        campus.gcGroupName!.isNotEmpty)
                      _InfoTile(
                        label: 'Official Messenger GC',
                        value: campus.gcGroupName!,
                      ),
                  ],
                  if (membership != null) ...[
                    _InfoTile(
                      label: 'Course / Year / Section',
                      value: membership.courseYearSection ?? 'Not specified',
                    ),
                    _InfoTile(
                      label: 'Membership Status',
                      value: membership.status.toUpperCase(),
                    ),
                    _InfoTile(
                      label: 'Messenger GC & Dues',
                      value:
                          '${membership.isInMessengerGc ? "In GC" : "Pending GC"} • ${membership.hasPaidDues ? "Dues Settled" : "Dues Pending"}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = authController.profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    final p = context.cpf;
    final roleColor = profile.isAlumni
        ? p.muted
        : (profile.verifiedRole?.badgeColorFor(p) ?? p.accent);

    return RefreshIndicator(
      color: p.primary,
      onRefresh: () => _handleRefresh(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildWelcomeHeader(p, profile, roleColor),
          if (profile.user.mustChangePassword ||
              profile.isAlumni ||
              !profile.qrUnlocked) ...[
            const SizedBox(height: 12),
            _buildStatusAlert(p, profile),
          ],
          const SizedBox(height: 14),
          _buildQrCard(context, p, profile),
          if (profile.dailyQuote != null) ...[
            const SizedBox(height: 14),
            _buildQuoteCard(p, profile.dailyQuote!),
          ],
          const SizedBox(height: 18),
          Text(
            'Quick Links',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          const SizedBox(height: 10),
          _buildQuickLinks(context, p, profile),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(
    CpfPalette p,
    AuthProfile profile,
    Color roleColor,
  ) {
    final campusName = profile.campus?.name ?? 'CHMSU Campus';
    final ay = profile.campus?.currentAcademicYear;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          const CpfEmblem(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        profile.effectiveRoleLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: roleColor,
                        ),
                      ),
                    ),
                    Text(
                      ay != null && ay.isNotEmpty
                          ? '$campusName • AY $ay'
                          : campusName,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAlert(CpfPalette p, AuthProfile profile) {
    final String message;
    if (profile.user.mustChangePassword) {
      message =
          'Password update required on the CPF web portal before your Peer QR ID unlocks.';
    } else if (profile.isAlumni) {
      message =
          'Former/Alumni account (${profile.effectiveRoleLabel}). Active QR attendance and officer tools are locked.';
    } else {
      message =
          'Your campus role is pending verification. Your Peer QR ID will unlock once approved.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.accent.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: p.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context,
    CpfPalette p,
    AuthProfile profile,
  ) {
    final hasQr = profile.qrUnlocked &&
        profile.qrPayload != null &&
        profile.qrPayload!.isNotEmpty;
    final courseSection = profile.membership?.courseYearSection;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.heroCard,
        borderRadius: BorderRadius.circular(24),
        border: p.themeId.isDark ? Border.all(color: p.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.themeId.isDark ? 0.32 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'OFFICIAL PEER QR ID',
                style: TextStyle(
                  color: p.heroMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (profile.campus != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.campus!.code,
                    style: TextStyle(
                      color: p.heroText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Strictly pure white quiet-zone box with dark #0F172A modules across ALL 5 themes.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CpfPalette.qrQuietZoneBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: hasQr
                ? QrImageView(
                    data: profile.qrPayload!,
                    size: 196,
                    backgroundColor: CpfPalette.qrQuietZoneBackground,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    gapless: true,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: CpfPalette.qrModuleColor,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: CpfPalette.qrModuleColor,
                    ),
                  )
                : const SizedBox(
                    width: 196,
                    height: 196,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 46,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'QR Locked',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CpfPalette.qrModuleColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Available once verified',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (profile.memberIdCode != null &&
              profile.memberIdCode!.isNotEmpty) ...[
            InkWell(
              onTap: () => _copyMemberId(context, profile.memberIdCode!),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: p.heroCardElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.memberIdCode!,
                      style: TextStyle(
                        color: p.heroText,
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: p.accent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (courseSection != null && courseSection.isNotEmpty)
                Text(
                  courseSection,
                  style: TextStyle(
                    color: p.heroMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (hasQr) ...[
                if (courseSection != null && courseSection.isNotEmpty)
                  Text(
                    '  •  ',
                    style: TextStyle(color: p.heroMuted),
                  ),
                TextButton.icon(
                  onPressed: () => _showExpandedQr(context, profile),
                  style: TextButton.styleFrom(
                    foregroundColor: p.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text(
                    'Expand QR',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(CpfPalette p, DailyQuote quote) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: p.accent,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                'Daily Peer Quote',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const Spacer(),
              if (quote.moodTag != null && quote.moodTag!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    quote.moodTag!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${quote.quoteText}"',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${quote.authorName}',
            style: TextStyle(
              fontSize: 12.5,
              color: p.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks(
    BuildContext context,
    CpfPalette p,
    AuthProfile profile,
  ) {
    return Column(
      children: [
        _QuickLinkTile(
          icon: Icons.event_note_rounded,
          accent: p.primary,
          title: 'Events & Activities',
          subtitle: 'View campus schedule and your attendance status',
          onTap: onOpenEvents,
        ),
        if (profile.canScanEvents) ...[
          const SizedBox(height: 10),
          _QuickLinkTile(
            icon: Icons.qr_code_scanner_rounded,
            accent: p.success,
            title: 'Officer QR Attendance Scanner',
            subtitle: 'Check-In / Check-Out peers on active campus events',
            onTap: onOpenEvents,
          ),
        ],
        const SizedBox(height: 10),
        _QuickLinkTile(
          icon: Icons.badge_outlined,
          accent: p.accent,
          title: 'Membership & Campus Info',
          subtitle: 'Course, academic year, Messenger GC, and dues',
          onTap: () => _showMembershipInfoSheet(context, profile),
        ),
        const SizedBox(height: 10),
        _QuickLinkTile(
          icon: Icons.verified_user_outlined,
          accent: p.muted,
          title: 'Data Privacy Notice',
          subtitle: 'RA 10173 protection and campus isolation policy',
          onTap: () => showDataPrivacyModal(context),
        ),
      ],
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.cpf;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
