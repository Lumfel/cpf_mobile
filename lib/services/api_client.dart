import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// Structured error returned by the CPF REST API or network layer.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const <String, List<String>>{},
    this.twoFactorRequired = false,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;
  final bool twoFactorRequired;

  @override
  String toString() => message;
}

/// Configured [Dio] client with Bearer token injection and 401 handling.
class ApiClient {
  ApiClient({
    required this.apiConfig,
    required this.storage,
    this.onUnauthorized,
    this.onMustChangePasswordRequired,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 15),
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = apiConfig.apiBaseUrl;
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';

          final path = options.path;
          final isPublicAuth = path.endsWith('/auth/login') ||
              path.endsWith('/auth/passkey-code');

          if (!isPublicAuth) {
            final token = _cachedToken ?? await storage.readToken();
            _cachedToken = token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }
          } else {
            options.headers.remove('Authorization');
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isPublicAuth = path.endsWith('/auth/login') ||
              path.endsWith('/auth/passkey-code');

          if (statusCode == 401 && !isPublicAuth) {
            setCachedToken(null);
            await storage.deleteToken();
            onUnauthorized?.call();
          } else if (statusCode == 403 && !isPublicAuth) {
            final data = error.response?.data;
            final code = data is Map
                ? (data['code'] ?? data['error'] ?? data['status'])?.toString()
                : null;
            final message = data is Map ? data['message']?.toString() : null;
            if (code == 'must_change_password_required' ||
                (message != null &&
                    message
                        .toLowerCase()
                        .contains('must_change_password_required'))) {
              onMustChangePasswordRequired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final ApiConfig apiConfig;
  final SecureStorageService storage;
  final VoidCallback? onUnauthorized;
  final VoidCallback? onMustChangePasswordRequired;
  final Dio _dio;

  String? _cachedToken;

  Dio get dio => _dio;

  void setCachedToken(String? token) {
    _cachedToken = (token != null && token.isNotEmpty) ? token : null;
  }

  /// Safely validates and normalizes a JSON object response body.
  Map<String, dynamic> expectJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw ApiException(
      message:
          'Unexpected response format from ${apiConfig.baseUrl}. Check your Server URL.',
    );
  }

  /// Parses [error] into a user-friendly [ApiException].
  ApiException toApiException(Object error) {
    if (error is ApiException) {
      return error;
    }

    if (error is DioException) {
      final response = error.response;
      final statusCode = response?.statusCode;
      final data = response?.data;

      if (data is Map<String, dynamic>) {
        final fieldErrors = <String, List<String>>{};
        final rawErrors = data['errors'];
        if (rawErrors is Map) {
          for (final entry in rawErrors.entries) {
            final key = entry.key.toString();
            final val = entry.value;
            if (val is List) {
              fieldErrors[key] = val.map((e) => e.toString()).toList();
            } else if (val != null) {
              fieldErrors[key] = <String>[val.toString()];
            }
          }
        }

        String? firstFieldError;
        if (fieldErrors.isNotEmpty) {
          final firstList = fieldErrors.values.first;
          if (firstList.isNotEmpty) {
            firstFieldError = firstList.first;
          }
        }

        final serverMessage = data['message'] as String?;
        final twoFactorRequired = statusCode == 422 &&
            (data['two_factor_required'] == true ||
                data['two_factor_required']?.toString().toLowerCase() ==
                    'true');
        final resolvedMessage = (firstFieldError != null &&
                firstFieldError.isNotEmpty)
            ? firstFieldError
            : (serverMessage != null && serverMessage.trim().isNotEmpty)
                ? serverMessage.trim()
                : _fallbackStatusMessage(statusCode);

        return ApiException(
          message: resolvedMessage,
          statusCode: statusCode,
          fieldErrors: fieldErrors,
          twoFactorRequired: twoFactorRequired,
        );
      }

      if (statusCode != null) {
        return ApiException(
          message: _fallbackStatusMessage(statusCode),
          statusCode: statusCode,
        );
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return ApiException(
            message:
                'Request timed out reaching ${apiConfig.baseUrl}. Check your connection or Server URL.',
          );
        case DioExceptionType.connectionError:
          return ApiException(
            message:
                'Unable to reach ${apiConfig.baseUrl}. Verify the server is running or update Server URL.',
          );
        case DioExceptionType.badCertificate:
          return ApiException(
            message:
                'SSL certificate check failed for ${apiConfig.baseUrl}.',
          );
        case DioExceptionType.cancel:
          return const ApiException(message: 'Request was cancelled.');
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          return ApiException(
            message:
                'Network error communicating with ${apiConfig.baseUrl}.',
          );
      }
    }

    return ApiException(message: error.toString());
  }

  String _fallbackStatusMessage(int? statusCode) {
    return switch (statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'Requested endpoint was not found on this server.',
      422 => 'Please check your input and try again.',
      429 => 'Too many attempts. Please wait a minute and try again.',
      500 || 502 || 503 => 'Server error occurred. Please try again shortly.',
      _ => 'Unexpected server error (${statusCode ?? 'unknown'}).',
    };
  }
}

/// Extracts a concise display message from any thrown error.
String extractErrorMessage(Object error, {required String currentBaseUrl}) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    return 'Unable to reach $currentBaseUrl. Check your connection.';
  }
  return error.toString();
}
