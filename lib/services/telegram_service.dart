// lib/services/telegram_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const _botToken = '8420317823:AAEzXkGqo7zWJ6tMclS1expTf6lZ4Jd25Hw';
const _telegramApi = 'https://api.telegram.org/bot$_botToken';

class TelegramResult {
  final bool ok;
  final bool blocked;
  final bool retryable;
  final String? error;

  TelegramResult({
    required this.ok,
    this.blocked = false,
    this.retryable = false,
    this.error,
  });
}

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  final Set<String> blockedUsers = {};

  bool _isBlockedError(String? msg) {
    if (msg == null) return false;
    final lower = msg.toLowerCase();
    return lower.contains('blocked') ||
        lower.contains('not found') ||
        lower.contains('deleted') ||
        lower.contains('deactivated') ||
        lower.contains('chat not found') ||
        lower.contains('forbidden');
  }

  Future<TelegramResult> sendPhoto({
    required String userId,
    required Uint8List photoBytes,
    required String date,
  }) async {
    if (blockedUsers.contains(userId)) {
      return TelegramResult(ok: false, blocked: true, error: 'Previously blocked');
    }

    final caption =
        '<b>User ID :</b> <code>$userId</code>\n\nDate : <b>$date</b>\n<i>For payment contact admin</i> @turja_un';

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_telegramApi/sendPhoto'),
      )
        ..fields['chat_id'] = userId
        ..fields['caption'] = caption
        ..fields['parse_mode'] = 'HTML'
        ..files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: 'payment.png',
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final body = await http.Response.fromStream(streamed);
      final json = body.body;

      if (streamed.statusCode == 200 && json.contains('"ok":true')) {
        return TelegramResult(ok: true);
      }

      if (_isBlockedError(json)) {
        blockedUsers.add(userId);
        return TelegramResult(ok: false, blocked: true, error: 'User blocked bot');
      }

      final retryable = !json.contains('Bad Request') && !json.contains('Forbidden');
      return TelegramResult(ok: false, retryable: retryable, error: json);
    } on SocketException {
      return TelegramResult(ok: false, retryable: true, error: 'Network error');
    } catch (e) {
      return TelegramResult(ok: false, retryable: true, error: e.toString());
    }
  }

  Future<TelegramResult> sendPhotoWithRetry({
    required String userId,
    required Uint8List photoBytes,
    required String date,
    int maxRetries = 3,
    void Function(int attempt)? onRetry,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await sendPhoto(
        userId: userId,
        photoBytes: photoBytes,
        date: date,
      );
      if (result.ok || result.blocked || !result.retryable) return result;
      if (attempt < maxRetries) {
        onRetry?.call(attempt);
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return TelegramResult(ok: false, error: 'Max retries exceeded');
  }
}
