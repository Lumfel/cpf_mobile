/// Lightweight campus summary returned inside `/api/v1/events`.
class EventCampus {
  const EventCampus({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  factory EventCampus.fromJson(Map<String, dynamic> json) {
    return EventCampus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// Personal attendance state for a campus event.
class MyEventAttendance {
  const MyEventAttendance({
    required this.status,
    this.loggedInAt,
    this.loggedOutAt,
  });

  /// One of `not_checked_in`, `logged_in`, or `completed`.
  final String status;
  final String? loggedInAt;
  final String? loggedOutAt;

  String get label => switch (status) {
        'logged_in' => 'Checked In',
        'completed' => 'Completed',
        _ => 'Not Checked In',
      };

  factory MyEventAttendance.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MyEventAttendance(status: 'not_checked_in');
    }
    return MyEventAttendance(
      status: json['status'] as String? ?? 'not_checked_in',
      loggedInAt: json['logged_in_at'] as String?,
      loggedOutAt: json['logged_out_at'] as String?,
    );
  }
}

/// Same-campus event or activity returned by `GET /api/v1/events`.
class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    required this.eventDate,
    required this.eventDateLabel,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.effectiveStatus,
    required this.reflectionEnabled,
    this.cancellationReason,
    required this.loggedInCount,
    required this.loggedOutCount,
    required this.canScan,
    required this.myAttendance,
  });

  final int id;
  final String title;
  final String? description;
  final String location;
  final String eventDate;
  final String eventDateLabel;
  final String startTime;
  final String endTime;
  final String status;
  final String effectiveStatus;
  final bool reflectionEnabled;
  final String? cancellationReason;
  final int loggedInCount;
  final int loggedOutCount;
  final bool canScan;
  final MyEventAttendance myAttendance;

  bool get isActive => effectiveStatus.toLowerCase() == 'active';
  bool get isUpcoming {
    final normalized = effectiveStatus.toLowerCase();
    return normalized == 'upcoming' || normalized == 'scheduled';
  }
  bool get isCancelled =>
      effectiveStatus.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'cancelled';
  bool get isPendingApproval => status.toLowerCase() == 'pending_approval';

  CampusEvent copyWith({
    int? loggedInCount,
    int? loggedOutCount,
    MyEventAttendance? myAttendance,
  }) {
    return CampusEvent(
      id: id,
      title: title,
      description: description,
      location: location,
      eventDate: eventDate,
      eventDateLabel: eventDateLabel,
      startTime: startTime,
      endTime: endTime,
      status: status,
      effectiveStatus: effectiveStatus,
      reflectionEnabled: reflectionEnabled,
      cancellationReason: cancellationReason,
      loggedInCount: loggedInCount ?? this.loggedInCount,
      loggedOutCount: loggedOutCount ?? this.loggedOutCount,
      canScan: canScan,
      myAttendance: myAttendance ?? this.myAttendance,
    );
  }

  factory CampusEvent.fromJson(Map<String, dynamic> json) {
    return CampusEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled Event',
      description: json['description'] as String?,
      location: json['location'] as String? ?? 'TBA',
      eventDate: json['event_date'] as String? ?? '',
      eventDateLabel: json['event_date_label'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: json['status'] as String? ?? 'approved',
      effectiveStatus: json['effective_status'] as String? ?? 'upcoming',
      reflectionEnabled: json['reflection_enabled'] as bool? ?? false,
      cancellationReason: json['cancellation_reason'] as String?,
      loggedInCount: (json['logged_in_count'] as num?)?.toInt() ?? 0,
      loggedOutCount: (json['logged_out_count'] as num?)?.toInt() ?? 0,
      canScan: json['can_scan'] as bool? ?? false,
      myAttendance: MyEventAttendance.fromJson(
        json['my_attendance'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// Envelope response for `GET /api/v1/events`.
class EventsResponse {
  const EventsResponse({
    this.campus,
    required this.canScanEvents,
    required this.events,
  });

  final EventCampus? campus;
  final bool canScanEvents;
  final List<CampusEvent> events;

  factory EventsResponse.fromJson(Map<String, dynamic> json) {
    final campusJson = json['campus'] as Map<String, dynamic>?;
    final rawEvents = (json['events'] as List<dynamic>?) ?? const <dynamic>[];
    return EventsResponse(
      campus: campusJson == null ? null : EventCampus.fromJson(campusJson),
      canScanEvents: json['can_scan_events'] as bool? ?? false,
      events: rawEvents
          .whereType<Map<String, dynamic>>()
          .map(CampusEvent.fromJson)
          .toList(),
    );
  }
}

/// Server attendance row returned by `POST /api/v1/events/{event}/scan`.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.campusEventId,
    required this.userId,
    this.loggedInAt,
    this.loggedInByUserId,
    this.loggedOutAt,
    this.loggedOutByUserId,
  });

  final int id;
  final int campusEventId;
  final int userId;
  final String? loggedInAt;
  final int? loggedInByUserId;
  final String? loggedOutAt;
  final int? loggedOutByUserId;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      campusEventId: (json['campus_event_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      loggedInAt: json['logged_in_at'] as String?,
      loggedInByUserId: (json['logged_in_by_user_id'] as num?)?.toInt(),
      loggedOutAt: json['logged_out_at'] as String?,
      loggedOutByUserId: (json['logged_out_by_user_id'] as num?)?.toInt(),
    );
  }
}

/// Response from `POST /api/v1/events/{event}/scan`.
class ScanResult {
  const ScanResult({
    required this.status,
    required this.memberName,
    this.courseYearSection,
    this.attendance,
  });

  /// One of `logged_in`, `already_logged_in`, `logged_out`,
  /// or `already_logged_out`.
  final String status;
  final String memberName;
  final String? courseYearSection;
  final AttendanceRecord? attendance;

  bool get isFreshCheckIn => status == 'logged_in';
  bool get isFreshCheckOut => status == 'logged_out';
  bool get isDuplicate =>
      status == 'already_logged_in' || status == 'already_logged_out';

  String get statusLabel => switch (status) {
        'logged_in' => 'Checked In',
        'already_logged_in' => 'Already Checked In',
        'logged_out' => 'Checked Out',
        'already_logged_out' => 'Already Checked Out',
        _ => status,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final attendanceJson = json['attendance'] as Map<String, dynamic>?;
    return ScanResult(
      status: json['status'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Verified Peer',
      courseYearSection: json['course_year_section'] as String?,
      attendance: attendanceJson == null
          ? null
          : AttendanceRecord.fromJson(attendanceJson),
    );
  }
}

/// Per-event A–Z attendance checklist row populated from
/// `GET /api/v1/events/{event}/checklist` (with local fallback storage).
class ManualChecklistEntry {
  const ManualChecklistEntry({
    this.userId,
    required this.identifier,
    required this.memberName,
    this.courseYearSection,
    this.roleLabel,
    this.loggedInAt,
    this.loggedOutAt,
    required this.lastStatus,
  });

  final int? userId;
  final String identifier;
  final String memberName;
  final String? courseYearSection;
  final String? roleLabel;
  final String? loggedInAt;
  final String? loggedOutAt;
  final String lastStatus;

  bool get isCheckedIn =>
      (loggedInAt != null && loggedInAt!.isNotEmpty) ||
      lastStatus == 'logged_in' ||
      lastStatus == 'already_logged_in' ||
      lastStatus == 'completed';

  bool get isCheckedOut =>
      (loggedOutAt != null && loggedOutAt!.isNotEmpty) ||
      lastStatus == 'logged_out' ||
      lastStatus == 'already_logged_out' ||
      lastStatus == 'completed';

  ManualChecklistEntry copyWith({
    int? userId,
    String? identifier,
    String? memberName,
    String? courseYearSection,
    String? roleLabel,
    String? loggedInAt,
    String? loggedOutAt,
    String? lastStatus,
  }) {
    return ManualChecklistEntry(
      userId: userId ?? this.userId,
      identifier: identifier ?? this.identifier,
      memberName: memberName ?? this.memberName,
      courseYearSection: courseYearSection ?? this.courseYearSection,
      roleLabel: roleLabel ?? this.roleLabel,
      loggedInAt: loggedInAt ?? this.loggedInAt,
      loggedOutAt: loggedOutAt ?? this.loggedOutAt,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        if (userId != null) 'user_id': userId,
        'identifier': identifier,
        'member_name': memberName,
        'course_year_section': courseYearSection,
        if (roleLabel != null) 'role_label': roleLabel,
        'logged_in_at': loggedInAt,
        'logged_out_at': loggedOutAt,
        'last_status': lastStatus,
      };

  factory ManualChecklistEntry.fromJson(Map<String, dynamic> json) {
    final attendance = json['attendance'] as Map<String, dynamic>?;
    final parsedUserId =
        (json['user_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt();
    final rawIdentifier = (json['identifier'] as String?) ??
        (json['member_id_code'] as String?) ??
        (parsedUserId != null ? 'user:$parsedUserId' : '');
    final rawName = (json['full_name_last_first_mi'] as String?) ??
        (json['member_name'] as String?) ??
        (json['name'] as String?) ??
        'Peer Member';
    final rawLoggedInAt = (json['logged_in_at'] as String?) ??
        (attendance?['logged_in_at'] as String?);
    final rawLoggedOutAt = (json['logged_out_at'] as String?) ??
        (attendance?['logged_out_at'] as String?);
    final rawStatus = (json['last_status'] as String?) ??
        (json['attendance_status'] as String?) ??
        (json['status'] as String?) ??
        (attendance?['status'] as String?) ??
        ((rawLoggedOutAt != null && rawLoggedOutAt.isNotEmpty)
            ? 'completed'
            : (rawLoggedInAt != null && rawLoggedInAt.isNotEmpty)
                ? 'logged_in'
                : 'not_checked_in');

    return ManualChecklistEntry(
      userId: parsedUserId,
      identifier: rawIdentifier,
      memberName: rawName,
      courseYearSection: json['course_year_section'] as String?,
      roleLabel: json['role_label'] as String?,
      loggedInAt: rawLoggedInAt,
      loggedOutAt: rawLoggedOutAt,
      lastStatus: rawStatus,
    );
  }
}

/// Response envelope from `GET /api/v1/events/{event}/checklist`.
class EventChecklistResponse {
  const EventChecklistResponse({
    required this.entries,
    this.loggedInCount,
    this.loggedOutCount,
  });

  final List<ManualChecklistEntry> entries;
  final int? loggedInCount;
  final int? loggedOutCount;

  factory EventChecklistResponse.fromJson(Map<String, dynamic> json) {
    final rawList = (json['checklist'] as List<dynamic>?) ??
        (json['roster'] as List<dynamic>?) ??
        (json['members'] as List<dynamic>?) ??
        (json['attendees'] as List<dynamic>?) ??
        const <dynamic>[];
    final eventJson = json['event'] as Map<String, dynamic>?;

    final parsed = rawList
        .whereType<Map<String, dynamic>>()
        .map(ManualChecklistEntry.fromJson)
        .toList()
      ..sort(
        (a, b) => a.memberName
            .toLowerCase()
            .compareTo(b.memberName.toLowerCase()),
      );

    return EventChecklistResponse(
      entries: parsed,
      loggedInCount: (json['logged_in_count'] as num?)?.toInt() ??
          (eventJson?['logged_in_count'] as num?)?.toInt(),
      loggedOutCount: (json['logged_out_count'] as num?)?.toInt() ??
          (eventJson?['logged_out_count'] as num?)?.toInt(),
    );
  }
}
