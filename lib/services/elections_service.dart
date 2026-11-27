import 'package:cpf_mobile/models/election_models.dart';
import 'package:cpf_mobile/services/api_client.dart';

/// REST API v1 endpoints for Campus Elections & Ephemeral Session Live Chat.
class ElectionsService {
  const ElectionsService(this._client);

  final ApiClient _client;

  /// `GET /api/v1/elections/active`
  Future<ActiveElectionOverview> fetchActiveElection() async {
    try {
      final response = await _client.dio.get<dynamic>('/elections/active');
      return ActiveElectionOverview.fromJson(
        _client.expectJsonMap(response.data),
      );
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/elections/{election}/nominate`
  Future<void> nominate({
    required int electionId,
    required int nomineeUserId,
    String? platform,
  }) async {
    try {
      await _client.dio.post<dynamic>(
        '/elections/$electionId/nominate',
        data: <String, dynamic>{
          'nominee_user_id': nomineeUserId,
          if (platform != null && platform.trim().isNotEmpty)
            'platform': platform.trim(),
        },
      );
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `PATCH /api/v1/elections/{election}/candidates/{candidate}/respond`
  /// Allows a pending nominee to accept (`accept: true`) or decline
  /// (`accept: false`) their nomination.
  Future<String> respondToNomination({
    required int electionId,
    required int candidateId,
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'decline';
    final status = accept ? 'accepted' : 'declined';
    try {
      final response = await _client.dio.patch<dynamic>(
        '/elections/$electionId/candidates/$candidateId/respond',
        data: <String, dynamic>{
          'action': action,
          'decision': status,
          'status': status,
        },
      );
      final map = _client.expectJsonMap(response.data);
      return map['nomination_status'] as String? ??
          map['status'] as String? ??
          status;
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/elections/{election}/vote`
  Future<String> castVote({
    required int electionId,
    required int candidateId,
    String? position,
  }) async {
    try {
      final response = await _client.dio.post<dynamic>(
        '/elections/$electionId/vote',
        data: <String, dynamic>{
          'candidate_id': candidateId,
          if (position != null && position.isNotEmpty) 'position': position,
        },
      );
      final map = _client.expectJsonMap(response.data);
      return map['status'] as String? ?? 'voted';
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `GET /api/v1/elections/{election}/live-chat`
  Future<List<ElectionLiveChatMessage>> fetchLiveChat(int electionId) async {
    try {
      final response =
          await _client.dio.get<dynamic>('/elections/$electionId/live-chat');
      final map = _client.expectJsonMap(response.data);
      final raw = (map['messages'] as List<dynamic>?) ?? const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ElectionLiveChatMessage.fromJson)
          .toList();
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/elections/{election}/live-chat`
  Future<ElectionLiveChatMessage> sendLiveChat({
    required int electionId,
    required String messageBody,
  }) async {
    final trimmed = messageBody.trim();
    if (trimmed.isEmpty) {
      throw const ApiException(
        message: 'Enter a message before sending to session chat.',
        statusCode: 422,
      );
    }
    try {
      final response = await _client.dio.post<dynamic>(
        '/elections/$electionId/live-chat',
        data: <String, dynamic>{
          'message_body': trimmed,
        },
      );
      final map = _client.expectJsonMap(response.data);
      final msgJson = map['message'] as Map<String, dynamic>? ?? map;
      return ElectionLiveChatMessage.fromJson(msgJson);
    } catch (error) {
      throw _client.toApiException(error);
    }
  }
}
