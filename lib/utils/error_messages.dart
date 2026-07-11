import '../services/api_client.dart';
import '../services/youversion_api_service.dart';

String formatDisplayError(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is YouVersionApiException) {
    return error.message;
  }
  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  if (error is ArgumentError) {
    final message = error.message?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
  }

  final raw = error.toString().trim();
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length).trim();
  }
  return raw;
}
