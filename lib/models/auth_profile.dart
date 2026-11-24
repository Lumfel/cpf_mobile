import 'package:cpf_mobile/models/cpf_role.dart';

/// User identity block returned in auth responses.
class CpfUser {
  const CpfUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.mustChangePassword,
    this.emailVerifiedAt,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool mustChangePassword;
  final String? emailVerifiedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'must_change_password': mustChangePassword,
        'email_verified_at': emailVerifiedAt,
      };

  factory CpfUser.fromJson(Map<String, dynamic> json) {
    return CpfUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      emailVerifiedAt: json['email_verified_at'] as String?,
    );
  }
}

/// Server-computed permissions for the authenticated member.
class CpfPermissions {
  const CpfPermissions({
    required this.isOfficerOrAdviser,
    required this.isClubAdviser,
    required this.canProposeEvents,
    required this.canScanAttendance,
    required this.canAccessArchive,
  });

  final bool isOfficerOrAdviser;
  final bool isClubAdviser;
  final bool canProposeEvents;
  final bool canScanAttendance;
  final bool canAccessArchive;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'is_officer_or_adviser': isOfficerOrAdviser,
        'is_club_adviser': isClubAdviser,
        'can_propose_events': canProposeEvents,
        'can_scan_attendance': canScanAttendance,
        'can_access_archive': canAccessArchive,
      };

  factory CpfPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CpfPermissions(
        isOfficerOrAdviser: false,
        isClubAdviser: false,
        canProposeEvents: false,
        canScanAttendance: false,
        canAccessArchive: false,
      );
    }
    return CpfPermissions(
      isOfficerOrAdviser: json['is_officer_or_adviser'] as bool? ?? false,
      isClubAdviser: json['is_club_adviser'] as bool? ?? false,
      canProposeEvents: json['can_propose_events'] as bool? ?? false,
      canScanAttendance: json['can_scan_attendance'] as bool? ?? false,
      canAccessArchive: json['can_access_archive'] as bool? ?? false,
    );
  }
}

/// Campus context for the authenticated member.
class CpfCampus {
  const CpfCampus({
    required this.id,
    required this.code,
    required this.name,
    required this.slug,
    required this.currentAcademicYear,
    this.gcGroupName,
  });

  final int id;
  final String code;
  final String name;
  final String slug;
  final String currentAcademicYear;
  final String? gcGroupName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'slug': slug,
        'current_academic_year': currentAcademicYear,
        'gc_group_name': gcGroupName,
      };

  factory CpfCampus.fromJson(Map<String, dynamic> json) {
    return CpfCampus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      currentAcademicYear: json['current_academic_year'] as String? ?? '',
      gcGroupName: json['gc_group_name'] as String?,
    );
  }
}

/// Active campus membership details.
class CpfMembership {
  const CpfMembership({
    required this.id,
    required this.status,
    required this.fullNameLastFirstMi,
    this.course,
    this.yearLevel,
    this.section,
    this.courseYearSection,
    required this.isInMessengerGc,
    required this.hasPaidDues,
  });

  final int id;
  final String status;
  final String fullNameLastFirstMi;
  final String? course;
  final String? yearLevel;
  final String? section;
  final String? courseYearSection;
  final bool isInMessengerGc;
  final bool hasPaidDues;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'status': status,
        'full_name_last_first_mi': fullNameLastFirstMi,
        'course': course,
        'year_level': yearLevel,
        'section': section,
        'course_year_section': courseYearSection,
        'is_in_messenger_gc': isInMessengerGc,
        'has_paid_dues': hasPaidDues,
      };

  factory CpfMembership.fromJson(Map<String, dynamic> json) {
    return CpfMembership(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      fullNameLastFirstMi: json['full_name_last_first_mi'] as String? ?? '',
      course: json['course'] as String?,
      yearLevel: json['year_level']?.toString(),
      section: json['section'] as String?,
      courseYearSection: json['course_year_section'] as String?,
      isInMessengerGc: json['is_in_messenger_gc'] as bool? ?? false,
      hasPaidDues: json['has_paid_dues'] as bool? ?? false,
    );
  }
}

/// Daily encouragement quote shown on the Peer Dashboard.
class DailyQuote {
  const DailyQuote({
    required this.id,
    required this.quoteText,
    required this.authorName,
    this.moodTag,
  });

  final int id;
  final String quoteText;
  final String authorName;
  final String? moodTag;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'quote_text': quoteText,
        'author_name': authorName,
        'mood_tag': moodTag,
      };

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      id: (json['id'] as num?)?.toInt() ?? 0,
      quoteText: json['quote_text'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Circle of Peer Facilitators',
      moodTag: json['mood_tag'] as String?,
    );
  }
}

/// Full authenticated profile payload from `/auth/login`, `/auth/passkey-code`,
/// and `/auth/me`.
class AuthProfile {
  const AuthProfile({
    required this.user,
    this.verifiedRole,
    this.verifiedRoleRaw,
    this.verifiedRoleLabel,
    required this.isAlumni,
    this.formerRole,
    this.formerRoleLabel,
    required this.permissions,
    this.campus,
    this.membership,
    required this.qrUnlocked,
    this.memberIdCode,
    this.qrPayload,
    this.dailyQuote,
  });

  final CpfUser user;
  final CpfRole? verifiedRole;
  final String? verifiedRoleRaw;
  final String? verifiedRoleLabel;
  final bool isAlumni;
  final String? formerRole;
  final String? formerRoleLabel;
  final CpfPermissions permissions;
  final CpfCampus? campus;
  final CpfMembership? membership;
  final bool qrUnlocked;
  final String? memberIdCode;
  final String? qrPayload;
  final DailyQuote? dailyQuote;

  /// Preferred full display name.
  String get displayName {
    final membershipName = membership?.fullNameLastFirstMi.trim() ?? '';
    if (membershipName.isNotEmpty) return membershipName;
    return user.name;
  }

  /// Display role badge label accounting for alumni / pending status.
  String get effectiveRoleLabel {
    if (isAlumni) {
      return formerRoleLabel ?? 'Former Member';
    }
    if (verifiedRoleLabel != null && verifiedRoleLabel!.trim().isNotEmpty) {
      return verifiedRoleLabel!;
    }
    if (verifiedRole != null) {
      return verifiedRole!.label;
    }
    return 'Pending Verification';
  }

  /// Whether this user holds active officer or Club Adviser authority.
  bool get isOfficerOrAdviser =>
      !isAlumni &&
      (permissions.isOfficerOrAdviser ||
          (verifiedRole?.isOfficerOrAdviser ?? false));

  /// Whether this user is an active same-campus Officer or Club Adviser allowed
  /// to operate the 2-stage QR attendance scanner.
  bool get canScanEvents =>
      !isAlumni && permissions.canScanAttendance && isOfficerOrAdviser;

  /// Whether this user can confirm the Messenger GC checklist.
  bool get canConfirmMessengerGc =>
      !isAlumni &&
      (verifiedRole == CpfRole.adviser ||
          verifiedRole == CpfRole.president ||
          verifiedRole == CpfRole.vicePresident ||
          verifiedRole == CpfRole.secretary ||
          verifiedRoleRaw == 'pio');

  /// Whether this user can validate chapter dues/payment receipts.
  bool get canValidatePayments =>
      !isAlumni &&
      (verifiedRole == CpfRole.treasurer ||
          verifiedRole == CpfRole.adviser ||
          verifiedRole == CpfRole.president ||
          verifiedRole == CpfRole.vicePresident);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user': user.toJson(),
        'verified_role': verifiedRole?.apiValue ?? verifiedRoleRaw,
        'verified_role_label': verifiedRoleLabel,
        'is_alumni': isAlumni,
        'former_role': formerRole,
        'former_role_label': formerRoleLabel,
        'permissions': permissions.toJson(),
        'campus': campus?.toJson(),
        'membership': membership?.toJson(),
        'qr_unlocked': qrUnlocked,
        'member_id_code': memberIdCode,
        'qr_payload': qrPayload,
        'daily_quote': dailyQuote?.toJson(),
      };

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    final campusJson = json['campus'] as Map<String, dynamic>?;
    final membershipJson = json['membership'] as Map<String, dynamic>?;
    final quoteJson = json['daily_quote'] as Map<String, dynamic>?;
    final rawRole = json['verified_role'] as String?;

    return AuthProfile(
      user: CpfUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      verifiedRole: CpfRole.fromApi(rawRole),
      verifiedRoleRaw: rawRole,
      verifiedRoleLabel: json['verified_role_label'] as String?,
      isAlumni: json['is_alumni'] as bool? ?? false,
      formerRole: json['former_role'] as String?,
      formerRoleLabel: json['former_role_label'] as String?,
      permissions: CpfPermissions.fromJson(
        json['permissions'] as Map<String, dynamic>?,
      ),
      campus: campusJson == null ? null : CpfCampus.fromJson(campusJson),
      membership: membershipJson == null
          ? null
          : CpfMembership.fromJson(membershipJson),
      qrUnlocked: json['qr_unlocked'] as bool? ?? false,
      memberIdCode: json['member_id_code'] as String?,
      qrPayload: json['qr_payload'] as String?,
      dailyQuote: quoteJson == null ? null : DailyQuote.fromJson(quoteJson),
    );
  }
}

/// Login / Passkey claim response containing the Sanctum Bearer token and
/// authenticated profile.
class LoginResponse {
  const LoginResponse({
    required this.tokenType,
    required this.token,
    required this.profile,
  });

  final String tokenType;
  final String token;
  final AuthProfile profile;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokenType: json['token_type'] as String? ?? 'Bearer',
      token: json['token'] as String? ?? '',
      profile: AuthProfile.fromJson(json),
    );
  }
}
