import 'package:dio/dio.dart';

String formatApiError(
  Object error, {
  String fallbackMessage = 'Une erreur est survenue',
}) {
  String message = fallbackMessage;

  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final apiMessage = data['message'] ?? data['error'];
      if (apiMessage is String && apiMessage.trim().isNotEmpty) {
        message = apiMessage.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data.trim();
    } else if (error.response == null &&
        error.message != null &&
        error.message!.trim().isNotEmpty) {
      message = error.message!.trim();
    }
  } else {
    final raw = error.toString().trim();
    if (raw.isNotEmpty) {
      message = raw;
    }
  }

  return message
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^Erreur:\s*'), '')
      .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
      .trim();
}
