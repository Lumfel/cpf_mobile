import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// All 11 native Circle of Peer Facilitators roles (matching `docs/RULES.md`).
/// There is intentionally NO admin role in the CPF domain.
enum CpfRole {
  adviser,
  guidanceCounselor,
  president,
  vicePresident,
  secretary,
  treasurer,
  auditor,
  businessManager,
  pio,
  sergeantAtArms,
  member;

  /// Canonical API string value.
  String get apiValue => switch (this) {
        CpfRole.adviser => 'adviser',
        CpfRole.guidanceCounselor => 'guidance_counselor',
        CpfRole.president => 'president',
        CpfRole.vicePresident => 'vice_president',
        CpfRole.secretary => 'secretary',
        CpfRole.treasurer => 'treasurer',
        CpfRole.auditor => 'auditor',
        CpfRole.businessManager => 'business_manager',
        CpfRole.pio => 'pio',
        CpfRole.sergeantAtArms => 'sergeant_at_arms',
        CpfRole.member => 'member',
      };

  /// Human-readable role label.
  String get label => switch (this) {
        CpfRole.adviser => 'Club Adviser',
        CpfRole.guidanceCounselor => 'Guidance Counselor',
        CpfRole.president => 'President',
        CpfRole.vicePresident => 'Vice President',
        CpfRole.secretary => 'Secretary',
        CpfRole.treasurer => 'Treasurer',
        CpfRole.auditor => 'Auditor',
        CpfRole.businessManager => 'Business Manager',
        CpfRole.pio => 'Public Information Officer (PIO)',
        CpfRole.sergeantAtArms => 'Sergeant-at-Arms',
        CpfRole.member => 'Member',
      };

  /// Non-Adviser Guidance Counselor has strictly coordination-only access
  /// (Counselors GC, Testing Room, Guidance Referrals) — never club affairs.
  bool get isGuidanceCounselorOnly => this == CpfRole.guidanceCounselor;

  /// Whether this role holds campus officer or Club Adviser club governance.
  bool get isOfficerOrAdviser =>
      this != CpfRole.member && this != CpfRole.guidanceCounselor;

  /// Roles allowed to confirm the Messenger GC checklist.
  bool get canConfirmMessengerGc =>
      this == CpfRole.adviser ||
      this == CpfRole.president ||
      this == CpfRole.vicePresident ||
      this == CpfRole.secretary ||
      this == CpfRole.pio;

  /// Roles allowed to validate dues/payment submissions.
  bool get canValidatePayments =>
      this == CpfRole.treasurer ||
      this == CpfRole.adviser ||
      this == CpfRole.president ||
      this == CpfRole.vicePresident;

  /// Accent color for UI role badges using the active [CpfPalette].
  Color badgeColorFor(CpfPalette palette) => switch (this) {
        CpfRole.adviser => palette.accent,
        CpfRole.guidanceCounselor => palette.primary,
        CpfRole.president => palette.primary,
        CpfRole.vicePresident => palette.primary,
        CpfRole.secretary => palette.success,
        CpfRole.treasurer => palette.success,
        CpfRole.auditor => palette.primary,
        CpfRole.businessManager => palette.accent,
        CpfRole.pio => palette.accent,
        CpfRole.sergeantAtArms => palette.success,
        CpfRole.member => palette.muted,
      };

  /// Parses strictly one of the 11 native CPF roles. Returns null for unknown
  /// or non-native strings (such as `'admin'`).
  static CpfRole? fromApi(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'adviser':
        return CpfRole.adviser;
      case 'guidance_counselor':
        return CpfRole.guidanceCounselor;
      case 'president':
        return CpfRole.president;
      case 'vice_president':
        return CpfRole.vicePresident;
      case 'secretary':
        return CpfRole.secretary;
      case 'treasurer':
        return CpfRole.treasurer;
      case 'auditor':
        return CpfRole.auditor;
      case 'business_manager':
        return CpfRole.businessManager;
      case 'pio':
        return CpfRole.pio;
      case 'sergeant_at_arms':
        return CpfRole.sergeantAtArms;
      case 'member':
        return CpfRole.member;
      default:
        return null;
    }
  }
}
