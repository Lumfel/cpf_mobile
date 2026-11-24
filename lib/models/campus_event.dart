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

/// Local per-event checklist row capturing members scanned via QR or entered
/// manually so officers can verify Check-In and trigger one-tap Check-Out.
class ManualChecklistEntry {
  const ManualChecklistEntry({
    required this.identifier,
    required this.memberName,
    this.courseYearSection,
    this.loggedInAt,
    this.loggedOutAt,
    required this.lastStatus,
  });

  final String identifier;
  final String memberName;
  final String? courseYearSection;
  final String? loggedInAt;
  final String? loggedOutAt;
  final String lastStatus;

  bool get isCheckedIn => loggedInAt != null && loggedInAt!.isNotEmpty;
  bool get isCheckedOut => loggedOutAt != null && loggedOutAt!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'member_name': memberName,
        'course_year_section': courseYearSection,
        'logged_in_at': loggedInAt,
        'logged_out_at': loggedOutAt,
        'last_status': lastStatus,
      };

  factory ManualChecklistEntry.fromJson(Map<String, dynamic> json) {
    return ManualChecklistEntry(
      identifier: json['identifier'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Peer Member',
      courseYearSection: json['course_year_section'] as String?,
      loggedInAt: json['logged_in_at'] as String?,
      loggedOutAt: json['logged_out_at'] as String?,
      lastStatus: json['last_status'] as String? ?? '',
    );
  }
}
