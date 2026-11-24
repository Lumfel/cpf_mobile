import 'package:material_ui/material_ui.dart';
import 'package:cpf_mobile/theme/cpf_themes.dart';

/// The 6 native Circle of Peer Facilitators roles.
/// There is intentionally NO admin role in the CPF domain.
enum CpfRole {
  adviser,
  president,
  vicePresident,
  secretary,
  treasurer,
  member;

  /// Canonical API string value.
  String get apiValue => switch (this) {
        CpfRole.adviser => 'adviser',
        CpfRole.president => 'president',
        CpfRole.vicePresident => 'vice_president',
        CpfRole.secretary => 'secretary',
        CpfRole.treasurer => 'treasurer',
        CpfRole.member => 'member',
      };

  /// Human-readable role label.
  String get label => switch (this) {
        CpfRole.adviser => 'Club Adviser',
        CpfRole.president => 'President',
        CpfRole.vicePresident => 'Vice President',
        CpfRole.secretary => 'Secretary',
        CpfRole.treasurer => 'Treasurer',
        CpfRole.member => 'Member',
      };

  /// Whether this role holds campus officer or adviser privileges.
  bool get isOfficerOrAdviser => this != CpfRole.member;

  /// Accent color for UI role badges using the active [CpfPalette].
  Color badgeColorFor(CpfPalette palette) => switch (this) {
        CpfRole.adviser => palette.accent,
        CpfRole.president => palette.primary,
        CpfRole.vicePresident => palette.primary,
        CpfRole.secretary => palette.success,
        CpfRole.treasurer => palette.success,
        CpfRole.member => palette.muted,
      };

  /// Parses strictly one of the 6 native CPF roles. Returns null for unknown
  /// or non-native strings (such as `'admin'`).
  static CpfRole? fromApi(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'adviser':
        return CpfRole.adviser;
      case 'president':
        return CpfRole.president;
      case 'vice_president':
        return CpfRole.vicePresident;
      case 'secretary':
        return CpfRole.secretary;
      case 'treasurer':
        return CpfRole.treasurer;
      case 'member':
        return CpfRole.member;
      default:
        return null;
    }
  }
}
