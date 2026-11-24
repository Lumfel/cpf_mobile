import 'package:cpf_mobile/models/campus_event.dart';
import 'package:cpf_mobile/services/api_client.dart';

/// REST API v1 campus events and officer QR attendance endpoints.
class EventsService {
  const EventsService(this._client);

  final ApiClient _client;

  /// `GET /api/v1/events`
  Future<EventsResponse> fetchEvents() async {
    try {
      final response = await _client.dio.get<dynamic>('/events');
      return EventsResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/events/{event}/scan`
  /// [scanType] must be `"login"` (Check-In) or `"logout"` (Check-Out).
  Future<ScanResult> scanAttendance({
    required int eventId,
    required String qrPayload,
    required String scanType,
  }) async {
    try {
      final response = await _client.dio.post<dynamic>(
        '/events/$eventId/scan',
        data: <String, dynamic>{
          'qr_payload': qrPayload.trim(),
          'scan_type': scanType,
        },
      );
      return ScanResult.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }
}
