/// Models for `/api/v1/elections/active` and `/api/v1/elections/{id}/live-chat`.
class ElectionSeat {
  const ElectionSeat({
    required this.key,
    required this.label,
    required this.optional,
    this.requiredYear,
    required this.seatOrder,
    required this.isCurrent,
    this.winnerUserId,
    this.winnerCandidateId,
    this.winnerName,
    this.winnerVotes,
    this.resultStatus,
  });

  final String key;
  final String label;
  final bool optional;
  final String? requiredYear;
  final int seatOrder;
  final bool isCurrent;
  final int? winnerUserId;
  final int? winnerCandidateId;
  final String? winnerName;
  final int? winnerVotes;
  final String? resultStatus;

  bool get isElected => resultStatus == 'elected';
  bool get isVacant => resultStatus == 'vacant';
  bool get isSkipped => resultStatus == 'skipped';
  bool get isResolved => isElected || isVacant || isSkipped;

  ElectionSeat withFallbackResult(Map<String, dynamic>? fallback) {
    if (resultStatus != null || fallback == null) {
      return this;
    }
    final parsedStatus = (fallback['status'] as String?)?.trim().toLowerCase();
    final parsedWinnerUserId = (fallback['winner_user_id'] as num?)?.toInt() ??
        (fallback['user_id'] as num?)?.toInt();
    final parsedWinnerName =
        fallback['winner_name'] as String? ?? fallback['name'] as String?;

    return ElectionSeat(
      key: key,
      label: label,
      optional: optional,
      requiredYear: requiredYear,
      seatOrder: seatOrder,
      isCurrent: isCurrent,
      winnerUserId: winnerUserId ?? parsedWinnerUserId,
      winnerCandidateId: winnerCandidateId ??
          (fallback['winner_candidate_id'] as num?)?.toInt() ??
          (fallback['candidate_id'] as num?)?.toInt(),
      winnerName: winnerName ?? parsedWinnerName,
      winnerVotes: winnerVotes ?? (fallback['votes'] as num?)?.toInt(),
      resultStatus: parsedStatus ??
          ((parsedWinnerUserId != null ||
                  (parsedWinnerName != null && parsedWinnerName.isNotEmpty))
              ? 'elected'
              : null),
    );
  }

  factory ElectionSeat.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    final rawStatus = (result?['status'] as String?)?.trim().toLowerCase();
    final parsedWinnerUserId = (result?['winner_user_id'] as num?)?.toInt() ??
        (result?['user_id'] as num?)?.toInt();
    final parsedWinnerName =
        result?['winner_name'] as String? ?? result?['name'] as String?;

    return ElectionSeat(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      optional: json['optional'] as bool? ?? false,
      requiredYear: json['required_year']?.toString(),
      seatOrder: (json['seat_order'] as num?)?.toInt() ?? 0,
      isCurrent: json['is_current'] as bool? ?? false,
      winnerUserId: parsedWinnerUserId,
      winnerCandidateId: (result?['winner_candidate_id'] as num?)?.toInt() ??
          (result?['candidate_id'] as num?)?.toInt(),
      winnerName: parsedWinnerName,
      winnerVotes: (result?['votes'] as num?)?.toInt(),
      resultStatus: rawStatus ??
          ((parsedWinnerUserId != null ||
                  (parsedWinnerName != null && parsedWinnerName.isNotEmpty))
              ? 'elected'
              : null),
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
    this.nominatedByUserId,
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
  final int? nominatedByUserId;
  final String nominationStatus;
  final bool isTieContender;
  final int votes;

  bool get isAccepted => nominationStatus == 'accepted';
  bool get isDeclined =>
      nominationStatus == 'declined' || nominationStatus == 'rejected';

  factory ElectionNominee.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        (json['nomination_status'] as String?)?.trim().toLowerCase();
    return ElectionNominee(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'CPF Member',
      courseYearSection: json['course_year_section'] as String? ?? '',
      yearLevel: json['year_level']?.toString(),
      avatarUrl: json['avatar_url'] as String?,
      position: json['position'] as String? ?? '',
      platform: json['platform'] as String?,
      nominatedByUserId: (json['nominated_by_user_id'] as num?)?.toInt(),
      nominationStatus:
          (rawStatus != null && rawStatus.isNotEmpty) ? rawStatus : 'accepted',
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
    this.positionResults = const <String, Map<String, dynamic>>{},
    this.electedUserIds = const <int>{},
    required this.canNominate,
    required this.canVote,
    required this.hasVotedCurrentRound,
    this.myCurrentVoteCandidateId,
    this.hasOptedOut = false,
    this.isAlreadyElected = false,
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
  final Map<String, Map<String, dynamic>> positionResults;
  final Set<int> electedUserIds;
  final bool canNominate;
  final bool canVote;
  final bool hasVotedCurrentRound;
  final int? myCurrentVoteCandidateId;
  final bool hasOptedOut;
  final bool isAlreadyElected;
  final bool liveChatEnabled;

  bool get isPaused => status == 'paused' || currentPhase == 'paused';
  bool get isCompleted =>
      status == 'completed' ||
      status == 'closed' ||
      currentPhase == 'completed';
  bool get isActivelyOpen => status == 'open' && !isPaused && !isCompleted;

  bool get isTieBreaker =>
      currentPhase == 'tie_breaker' || currentPhase == 'adviser_tie_breaker';
  bool get isNominationPhase => currentPhase == 'nomination';
  bool get isVotingPhase =>
      currentPhase == 'voting' || currentPhase == 'runoff' || isTieBreaker;

  /// Nominees on the floor for the current seat.
  List<ElectionNominee> get candidatesForCurrentSeat {
    if (currentPositionNominees.isNotEmpty) {
      return currentPositionNominees;
    }
    if (currentPosition == null || currentPosition!.isEmpty) {
      return const <ElectionNominee>[];
    }
    return nominees.where((n) => n.position == currentPosition).toList();
  }

  /// True when any candidate on the current seat is marked as a runoff/tie
  /// contender (`is_tie_contender: true`).
  bool get hasRunoffContenders =>
      candidatesForCurrentSeat.any((n) => n.isTieContender);

  /// Whether [nominee] is eligible to receive a vote in the active round
  /// (accepted nomination, not already locked into an earlier seat, and inside
  /// the runoff contender pool whenever tie-breaker/runoff filtering applies).
  bool isCandidateEligibleForCurrentRound(
    ElectionNominee nominee, {
    Set<int> lockedWinnerUserIds = const <int>{},
  }) {
    if (!nominee.isAccepted) return false;
    if (nominee.userId > 0 &&
        (electedUserIds.contains(nominee.userId) ||
            lockedWinnerUserIds.contains(nominee.userId))) {
      return false;
    }
    if (isTieBreaker || hasRunoffContenders) {
      return nominee.isTieContender;
    }
    return true;
  }

  factory ActiveElectionSession.fromJson(Map<String, dynamic> json) {
    final rawNominees =
        (json['nominees'] as List<dynamic>?) ?? const <dynamic>[];
    final rawCurrentNominees =
        (json['current_position_nominees'] as List<dynamic>?) ??
            const <dynamic>[];
    final voting = json['voting_status'] as Map<String, dynamic>?;
    final liveChat = json['live_chat'] as Map<String, dynamic>?;

    final normalizedStatus =
        (json['status'] as String? ?? 'open').trim().toLowerCase();
    final normalizedPhase =
        (json['current_phase'] as String? ?? 'voting').trim().toLowerCase();

    final parsedResults = <String, Map<String, dynamic>>{};
    final parsedElectedUserIds = <int>{};
    final rawPositionResults = json['position_results'];
    if (rawPositionResults is Map) {
      for (final entry in rawPositionResults.entries) {
        final val = entry.value;
        if (val is Map) {
          final mapVal = Map<String, dynamic>.from(val);
          parsedResults[entry.key.toString()] = mapVal;
          final resStatus = (mapVal['status'] as String?)?.trim().toLowerCase();
          final winnerUid = (mapVal['winner_user_id'] as num?)?.toInt() ??
              (mapVal['user_id'] as num?)?.toInt();
          if (winnerUid != null &&
              winnerUid > 0 &&
              (resStatus == null || resStatus == 'elected')) {
            parsedElectedUserIds.add(winnerUid);
          }
        }
      }
    }

    final isSessionOpen = normalizedStatus == 'open' &&
        normalizedPhase != 'paused' &&
        normalizedPhase != 'completed';
    final rawChatEnabled = liveChat?['enabled'] as bool? ?? isSessionOpen;

    return ActiveElectionSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'CPF Campus Election',
      academicYear: json['academic_year'] as String? ?? '',
      status: normalizedStatus,
      currentPosition: json['current_position'] as String?,
      currentPositionLabel: json['current_position_label'] as String?,
      currentPhase: normalizedPhase,
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      nominees: rawNominees
          .whereType<Map<String, dynamic>>()
          .map(ElectionNominee.fromJson)
          .toList(),
      currentPositionNominees: rawCurrentNominees
          .whereType<Map<String, dynamic>>()
          .map(ElectionNominee.fromJson)
          .toList(),
      positionResults: parsedResults,
      electedUserIds: parsedElectedUserIds,
      canNominate:
          isSessionOpen && (voting?['can_nominate'] as bool? ?? false),
      canVote: isSessionOpen && (voting?['can_vote'] as bool? ?? false),
      hasVotedCurrentRound:
          voting?['has_voted_current_round'] as bool? ?? false,
      myCurrentVoteCandidateId:
          (voting?['my_current_vote_candidate_id'] as num?)?.toInt(),
      hasOptedOut: voting?['has_opted_out'] as bool? ?? false,
      isAlreadyElected: voting?['is_already_elected'] as bool? ?? false,
      liveChatEnabled: isSessionOpen && rawChatEnabled,
    );
  }
}

class ActiveElectionOverview {
  const ActiveElectionOverview({
    this.campusName,
    required this.seats,
    this.activeElection,
    this.completedElection,
  });

  final String? campusName;
  final List<ElectionSeat> seats;
  final ActiveElectionSession? activeElection;
  final ActiveElectionSession? completedElection;

  /// User IDs already elected to a seat in this election session.
  Set<int> get electedUserIds => <int>{
        for (final seat in seats)
          if (seat.isElected && seat.winnerUserId != null && seat.winnerUserId! > 0)
            seat.winnerUserId!,
        ...?activeElection?.electedUserIds,
      };

  /// True when [userId] holds an already-elected seat lock in this session.
  bool isUserAlreadyElected(int? userId) {
    if (activeElection?.isAlreadyElected == true) {
      return true;
    }
    if (userId == null || userId <= 0) {
      return false;
    }
    return electedUserIds.contains(userId);
  }

  factory ActiveElectionOverview.fromJson(Map<String, dynamic> json) {
    final campus = json['campus'] as Map<String, dynamic>?;
    final rawSeats = (json['seats'] as List<dynamic>?) ?? const <dynamic>[];
    final activeJson = json['active_election'] as Map<String, dynamic>?;
    final completedJson = (json['completed_election'] as Map<String, dynamic>?) ??
        (json['recent_election'] as Map<String, dynamic>?);

    final parsedActive = activeJson == null
        ? null
        : ActiveElectionSession.fromJson(activeJson);
    final parsedCompleted = completedJson != null
        ? ActiveElectionSession.fromJson(completedJson)
        : (parsedActive != null && parsedActive.isCompleted
            ? parsedActive
            : null);

    final fallbackResults = parsedActive?.positionResults ??
        parsedCompleted?.positionResults ??
        const <String, Map<String, dynamic>>{};

    return ActiveElectionOverview(
      campusName: campus?['name'] as String?,
      seats: rawSeats
          .whereType<Map<String, dynamic>>()
          .map(ElectionSeat.fromJson)
          .map((seat) => seat.withFallbackResult(fallbackResults[seat.key]))
          .toList(),
      activeElection: parsedActive,
      completedElection: parsedCompleted,
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
