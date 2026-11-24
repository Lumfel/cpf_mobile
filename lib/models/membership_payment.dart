/// Models for `/api/v1/membership/roster` and `/api/v1/payments`.
class RosterMember {
  const RosterMember({
    required this.id,
    required this.userId,
    required this.fullNameLastFirstMi,
    this.course,
    this.yearLevel,
    this.section,
    this.courseYearSection,
    required this.role,
    required this.roleLabel,
    required this.isInMessengerGc,
    this.gcConfirmedAt,
    this.gcConfirmedByName,
    required this.hasPaidDues,
    this.duesConfirmedAt,
    this.duesConfirmedByName,
  });

  final int id;
  final int userId;
  final String fullNameLastFirstMi;
  final String? course;
  final String? yearLevel;
  final String? section;
  final String? courseYearSection;
  final String role;
  final String roleLabel;
  final bool isInMessengerGc;
  final String? gcConfirmedAt;
  final String? gcConfirmedByName;
  final bool hasPaidDues;
  final String? duesConfirmedAt;
  final String? duesConfirmedByName;

  RosterMember copyWith({
    bool? isInMessengerGc,
    String? gcConfirmedAt,
    bool? hasPaidDues,
    String? duesConfirmedAt,
  }) {
    return RosterMember(
      id: id,
      userId: userId,
      fullNameLastFirstMi: fullNameLastFirstMi,
      course: course,
      yearLevel: yearLevel,
      section: section,
      courseYearSection: courseYearSection,
      role: role,
      roleLabel: roleLabel,
      isInMessengerGc: isInMessengerGc ?? this.isInMessengerGc,
      gcConfirmedAt: gcConfirmedAt ?? this.gcConfirmedAt,
      gcConfirmedByName: gcConfirmedByName,
      hasPaidDues: hasPaidDues ?? this.hasPaidDues,
      duesConfirmedAt: duesConfirmedAt ?? this.duesConfirmedAt,
      duesConfirmedByName: duesConfirmedByName,
    );
  }

  factory RosterMember.fromJson(Map<String, dynamic> json) {
    return RosterMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullNameLastFirstMi: json['full_name_last_first_mi'] as String? ?? '',
      course: json['course'] as String?,
      yearLevel: json['year_level']?.toString(),
      section: json['section'] as String?,
      courseYearSection: json['course_year_section'] as String?,
      role: json['role'] as String? ?? 'member',
      roleLabel: json['role_label'] as String? ?? 'Member',
      isInMessengerGc: json['is_in_messenger_gc'] as bool? ?? false,
      gcConfirmedAt: json['gc_confirmed_at'] as String?,
      gcConfirmedByName: json['gc_confirmed_by_name'] as String?,
      hasPaidDues: json['has_paid_dues'] as bool? ?? false,
      duesConfirmedAt: json['dues_confirmed_at'] as String?,
      duesConfirmedByName: json['dues_confirmed_by_name'] as String?,
    );
  }
}

class RosterResponse {
  const RosterResponse({
    this.campusName,
    this.gcGroupName,
    required this.canConfirmMessengerGc,
    required this.canValidatePayments,
    required this.roster,
  });

  final String? campusName;
  final String? gcGroupName;
  final bool canConfirmMessengerGc;
  final bool canValidatePayments;
  final List<RosterMember> roster;

  factory RosterResponse.fromJson(Map<String, dynamic> json) {
    final campus = json['campus'] as Map<String, dynamic>?;
    final perms = json['permissions'] as Map<String, dynamic>?;
    final rawRoster = (json['roster'] as List<dynamic>?) ?? const <dynamic>[];

    return RosterResponse(
      campusName: campus?['name'] as String?,
      gcGroupName: campus?['gc_group_name'] as String?,
      canConfirmMessengerGc:
          perms?['can_confirm_messenger_gc'] as bool? ?? false,
      canValidatePayments: perms?['can_validate_payments'] as bool? ?? false,
      roster: rawRoster
          .whereType<Map<String, dynamic>>()
          .map(RosterMember.fromJson)
          .toList(),
    );
  }
}

class PaymentChannelDestination {
  const PaymentChannelDestination({
    required this.id,
    required this.channel,
    required this.accountName,
    required this.accountNumber,
  });

  final int id;
  final String channel;
  final String accountName;
  final String accountNumber;

  factory PaymentChannelDestination.fromJson(Map<String, dynamic> json) {
    return PaymentChannelDestination(
      id: (json['id'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String? ?? 'GCash',
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
    );
  }
}

class PaymentSubmissionItem {
  const PaymentSubmissionItem({
    required this.id,
    required this.userId,
    required this.memberName,
    this.courseYearSection,
    required this.destinationId,
    this.channel,
    this.accountName,
    required this.purpose,
    required this.amount,
    required this.referenceNumber,
    required this.hasReceipt,
    required this.status,
    this.treasurerNotes,
    this.validatedAt,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String memberName;
  final String? courseYearSection;
  final int destinationId;
  final String? channel;
  final String? accountName;
  final String purpose;
  final double amount;
  final String referenceNumber;
  final bool hasReceipt;
  final String status;
  final String? treasurerNotes;
  final String? validatedAt;
  final String? createdAt;

  bool get isPending => status == 'pending';
  bool get isValidated => status == 'validated';

  factory PaymentSubmissionItem.fromJson(Map<String, dynamic> json) {
    return PaymentSubmissionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      memberName: json['member_name'] as String? ?? 'CPF Member',
      courseYearSection: json['course_year_section'] as String?,
      destinationId: (json['destination_id'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String?,
      accountName: json['account_name'] as String?,
      purpose: json['purpose'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      referenceNumber: json['reference_number'] as String? ?? '',
      hasReceipt: json['has_receipt'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      treasurerNotes: json['treasurer_notes'] as String?,
      validatedAt: json['validated_at']?.toString(),
      createdAt: json['created_at'] as String?,
    );
  }
}

class PaymentsOverview {
  const PaymentsOverview({
    this.campusName,
    required this.hasPaidDues,
    this.duesConfirmedAt,
    required this.canValidatePayments,
    required this.canAuditFinances,
    required this.destinations,
    required this.mySubmissions,
    required this.validationQueue,
  });

  final String? campusName;
  final bool hasPaidDues;
  final String? duesConfirmedAt;
  final bool canValidatePayments;
  final bool canAuditFinances;
  final List<PaymentChannelDestination> destinations;
  final List<PaymentSubmissionItem> mySubmissions;
  final List<PaymentSubmissionItem> validationQueue;

  factory PaymentsOverview.fromJson(Map<String, dynamic> json) {
    final campus = json['campus'] as Map<String, dynamic>?;
    final myDues = json['my_dues_status'] as Map<String, dynamic>?;
    final perms = json['permissions'] as Map<String, dynamic>?;
    final rawDest =
        (json['destinations'] as List<dynamic>?) ?? const <dynamic>[];
    final rawMine =
        (json['my_submissions'] as List<dynamic>?) ?? const <dynamic>[];
    final rawQueue =
        (json['validation_queue'] as List<dynamic>?) ?? const <dynamic>[];

    return PaymentsOverview(
      campusName: campus?['name'] as String?,
      hasPaidDues: myDues?['has_paid_dues'] as bool? ?? false,
      duesConfirmedAt: myDues?['dues_confirmed_at'] as String?,
      canValidatePayments: perms?['can_validate_payments'] as bool? ?? false,
      canAuditFinances: perms?['can_audit_finances'] as bool? ?? false,
      destinations: rawDest
          .whereType<Map<String, dynamic>>()
          .map(PaymentChannelDestination.fromJson)
          .toList(),
      mySubmissions: rawMine
          .whereType<Map<String, dynamic>>()
          .map(PaymentSubmissionItem.fromJson)
          .toList(),
      validationQueue: rawQueue
          .whereType<Map<String, dynamic>>()
          .map(PaymentSubmissionItem.fromJson)
          .toList(),
    );
  }
}
