import 'dart:convert';

import 'exceptions.dart';

Map<String, dynamic> decodeJsonObject(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Converted below.
  }
  throw const InvalidResponseException(
    'The inference server returned invalid JSON.',
  );
}

String serverErrorDetail(String body) {
  if (body.trim().isEmpty) return '';
  try {
    final decoded = jsonDecode(body);
    final error = decoded is Map ? decoded['error'] : null;
    final message = error is Map ? error['message'] : null;
    if (message is String && message.trim().isNotEmpty) {
      return ': ${message.trim()}';
    }
  } catch (_) {
    return '';
  }
  return '';
}

Never throwHttpFailure(int statusCode, String body, String prefix) {
  final detail = serverErrorDetail(body);
  final message = '$prefix: HTTP $statusCode$detail';
  if (statusCode >= 200 && statusCode < 300) {
    throw StateError('Successful responses should not be converted.');
  }
  if (statusCode == 400) throw BadRequestException(message);
  if (statusCode == 401 || statusCode == 403) {
    throw AuthenticationException(message);
  }
  if (statusCode == 429) throw RateLimitException(message);
  if (statusCode >= 500) throw ServerException(message);
  throw BadRequestException(message);
}
