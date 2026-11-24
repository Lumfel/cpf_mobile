import 'package:dio/dio.dart';
import 'package:cpf_mobile/models/membership_payment.dart';
import 'package:cpf_mobile/services/api_client.dart';

/// REST API v1 endpoints for Officer A–Z Roster, Messenger GC checklist,
/// and Member Dues / Treasurer Payment Validation.
class MembershipPaymentService {
  const MembershipPaymentService(this._client);

  final ApiClient _client;

  /// `GET /api/v1/membership/roster`
  Future<RosterResponse> fetchRoster() async {
    try {
      final response =
          await _client.dio.get<dynamic>('/membership/roster');
      return RosterResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `PATCH /api/v1/membership/{membership}/toggle-gc`
  Future<bool> toggleMessengerGc(int membershipId) async {
    try {
      final response = await _client.dio
          .patch<dynamic>('/membership/$membershipId/toggle-gc');
      final map = _client.expectJsonMap(response.data);
      return map['is_in_messenger_gc'] as bool? ?? false;
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `PATCH /api/v1/membership/{membership}/toggle-dues`
  Future<bool> toggleDues(int membershipId) async {
    try {
      final response = await _client.dio
          .patch<dynamic>('/membership/$membershipId/toggle-dues');
      final map = _client.expectJsonMap(response.data);
      return map['has_paid_dues'] as bool? ?? false;
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `GET /api/v1/payments`
  Future<PaymentsOverview> fetchPayments() async {
    try {
      final response = await _client.dio.get<dynamic>('/payments');
      return PaymentsOverview.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/payments/submit`
  Future<void> submitPayment({
    required int destinationId,
    required String purpose,
    required double amount,
    required String referenceNumber,
    List<int>? receiptBytes,
    String? receiptFileName,
  }) async {
    try {
      if (receiptBytes != null &&
          receiptBytes.isNotEmpty &&
          receiptFileName != null &&
          receiptFileName.isNotEmpty) {
        final formData = FormData.fromMap(<String, dynamic>{
          'destination_id': destinationId,
          'purpose': purpose.trim(),
          'amount': amount,
          'reference_number': referenceNumber.trim(),
          'receipt': MultipartFile.fromBytes(
            receiptBytes,
            filename: receiptFileName,
          ),
        });
        await _client.dio.post<dynamic>(
          '/payments/submit',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
      } else {
        await _client.dio.post<dynamic>(
          '/payments/submit',
          data: <String, dynamic>{
            'destination_id': destinationId,
            'purpose': purpose.trim(),
            'amount': amount,
            'reference_number': referenceNumber.trim(),
          },
        );
      }
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `PATCH /api/v1/payments/{payment}/validate`
  Future<void> validatePayment({
    required int paymentId,
    required String status, // 'validated' or 'rejected'
    String? treasurerNotes,
  }) async {
    try {
      await _client.dio.patch<dynamic>(
        '/payments/$paymentId/validate',
        data: <String, dynamic>{
          'status': status,
          if (treasurerNotes != null && treasurerNotes.trim().isNotEmpty)
            'treasurer_notes': treasurerNotes.trim(),
        },
      );
    } catch (error) {
      throw _client.toApiException(error);
    }
  }
}
