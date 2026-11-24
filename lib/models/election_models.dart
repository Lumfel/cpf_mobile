/// Models for `/api/v1/elections/active` and `/api/v1/elections/{id}/live-chat`.
class ElectionSeat {
  const ElectionSeat({
    required this.key,
    required this.label,
    required this.optional,
    this.requiredYear,
    required this.seatOrder,
    required this.isCurrent,
    this.winnerName,
    this.resultStatus,
  });

  final String key;
  final String label;
  final bool optional;
  final String? requiredYear;
  final int seatOrder;
  final bool isCurrent;
  final String? winnerName;
  final String? resultStatus;

  bool get isElected => resultStatus == 'elected';
  bool get isSkipped => resultStatus == 'skipped';

  factory ElectionSeat.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    return ElectionSeat(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      optional: json['optional'] as bool? ?? false,
      requiredYear: json['required_year']?.toString(),
      seatOrder: (json['seat_order'] as num?)?.toInt() ?? 0,
      isCurrent: json['is_current'] as bool? ?? false,
      winnerName: result?['winner_name'] as String?,
      resultStatus: result?['status'] as String?,
    );
  }
}

class ElectionNominee {
  const ElectionNominee({
    required this.id,
    required this.userId,
    required this.name,
    required this.courseYearSection,
    this.yearLevel,
    this.avatarUrl,
    required this.position,
    this.platform,
    required this.nominationStatus,
    required this.isTieContender,
    required this.votes,
  });

  final int id;
  final int userId;
  final String name;
  final String courseYearSection;
  final String? yearLevel;
  final String? avatarUrl;
  final String position;
  final String? platform;
  final String nominationStatus;
  final bool isTieContender;
  final int votes;

  bool get isAccepted => nominationStatus == 'accepted';

  factory ElectionNominee.fromJson(Map<String, dynamic> json) {
    return ElectionNominee(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'CPF Member',
      courseYearSection: json['course_year_section'] as String? ?? '',
      yearLevel: json['year_level']?.toString(),
      avatarUrl: json['avatar_url'] as String?,
      position: json['position'] as String? ?? '',
      platform: json['platform'] as String?,
      nominationStatus: json['nomination_status'] as String? ?? 'accepted',
      isTieContender: json['is_tie_contender'] as bool? ?? false,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveElectionSession {
  const ActiveElectionSession({
    required this.id,
    required this.title,
    required this.academicYear,
    required this.status,
    this.currentPosition,
    this.currentPositionLabel,
    required this.currentPhase,
    required this.roundNumber,
    required this.nominees,
    required this.currentPositionNominees,
    required this.canNominate,
    required this.canVote,
    required this.hasVotedCurrentRound,
    this.myCurrentVoteCandidateId,
    required this.liveChatEnabled,
  });

  final int id;
  final String title;
  final String academicYear;
  final String status;
  final String? currentPosition;
  final String? currentPositionLabel;
  final String currentPhase;
  final int roundNumber;
  final List<ElectionNominee> nominees;
  final List<ElectionNominee> currentPositionNominees;
  final bool canNominate;
  final bool canVote;
  final bool hasVotedCurrentRound;
  final int? myCurrentVoteCandidateId;
  final bool liveChatEnabled;

  bool get isTieBreaker => currentPhase == 'tie_breaker';
  bool get isNominationPhase => currentPhase == 'nomination';
  bool get isVotingPhase =>
      currentPhase == 'voting' || currentPhase == 'tie_breaker';

  factory ActiveElectionSession.fromJson(Map<String, dynamic> json) {
    final rawNominees =
        (json['nominees'] as List<dynamic>?) ?? const <dynamic>[];
    final rawCurrentNominees =
        (json['current_position_nominees'] as List<dynamic>?) ??
            const <dynamic>[];
    final voting = json['voting_status'] as Map<String, dynamic>?;
    final liveChat = json['live_chat'] as Map<String, dynamic>?;

    return ActiveElectionSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'CPF Campus Election',
      academicYear: json['academic_year'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      currentPosition: json['current_position'] as String?,
      currentPositionLabel: json['current_position_label'] as String?,
      currentPhase: json['current_phase'] as String? ?? 'voting',
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      nominees: rawNominees
          .whereType<Map<String, dynamic>>()
          .map(ElectionNominee.fromJson)
          .toList(),
      currentPositionNominees: rawCurrentNominees
          .whereType<Map<String, dynamic>>()
          .map(ElectionNominee.fromJson)
          .toList(),
      canNominate: voting?['can_nominate'] as bool? ?? false,
      canVote: voting?['can_vote'] as bool? ?? false,
      hasVotedCurrentRound:
          voting?['has_voted_current_round'] as bool? ?? false,
      myCurrentVoteCandidateId:
          (voting?['my_current_vote_candidate_id'] as num?)?.toInt(),
      liveChatEnabled: liveChat?['enabled'] as bool? ?? true,
    );
  }
}

class ActiveElectionOverview {
  const ActiveElectionOverview({
    this.campusName,
    required this.seats,
    this.activeElection,
  });

  final String? campusName;
  final List<ElectionSeat> seats;
  final ActiveElectionSession? activeElection;

  factory ActiveElectionOverview.fromJson(Map<String, dynamic> json) {
    final campus = json['campus'] as Map<String, dynamic>?;
    final rawSeats = (json['seats'] as List<dynamic>?) ?? const <dynamic>[];
    final activeJson = json['active_election'] as Map<String, dynamic>?;

    return ActiveElectionOverview(
      campusName: campus?['name'] as String?,
      seats: rawSeats
          .whereType<Map<String, dynamic>>()
          .map(ElectionSeat.fromJson)
          .toList(),
      activeElection: activeJson == null
          ? null
          : ActiveElectionSession.fromJson(activeJson),
    );
  }
}

class ElectionLiveChatMessage {
  const ElectionLiveChatMessage({
    required this.id,
    required this.electionId,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.senderRoleLabel,
    required this.messageBody,
    required this.sentAt,
  });

  final String id;
  final int electionId;
  final int senderUserId;
  final String senderName;
  final String senderRole;
  final String senderRoleLabel;
  final String messageBody;
  final String sentAt;

  factory ElectionLiveChatMessage.fromJson(Map<String, dynamic> json) {
    return ElectionLiveChatMessage(
      id: json['id']?.toString() ?? '',
      electionId: (json['election_id'] as num?)?.toInt() ?? 0,
      senderUserId: (json['sender_user_id'] as num?)?.toInt() ?? 0,
      senderName: json['sender_name'] as String? ?? 'Peer Member',
      senderRole: json['sender_role'] as String? ?? 'member',
      senderRoleLabel: json['sender_role_label'] as String? ?? 'Member',
      messageBody: json['message_body'] as String? ?? '',
      sentAt: json['sent_at'] as String? ?? '',
    );
  }
}
