// lib/services/telegram_service.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TelegramResult {
  final bool ok;
  final bool blocked;
  final bool retryable;
  final String? error;

  TelegramResult({
    required this.ok,
    this.blocked  = false,
    this.retryable = false,
    this.error,
  });
}

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  // ── Configurable fields (set from AppConfig on app start & on save) ────────

  /// Telegram bot token — loaded from SharedPreferences via StorageService.
  String botToken = '';

  /// Admin username shown in receipt captions (without @).
  String adminUsername = 'turja_un';

  /// Caption template. Supported placeholders:
  ///   {user_id}  — Telegram user ID
  ///   {date}     — payment date string
  ///   {admin}    — adminUsername (without @)
  String captionTemplate =
      '🧾 <b>Payment Receipt</b>\n\n'
      '👤 <b>User ID:</b> <code>{user_id}</code>\n'
      '📅 <b>Date:</b> {date}\n\n'
      '📨 Please <b>forward this message</b> to admin for payment verification.\n'
      '👨‍💼 <b>Admin:</b> @{admin}';

  String get _apiBase => 'https://api.telegram.org/bot$botToken';

  final Set<String> blockedUsers = {};

  // ── HTML escape ───────────────────────────────────────────────────────────

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Build caption from template ───────────────────────────────────────────

  String buildCaption({required String userId, required String date}) {
    return captionTemplate
        .replaceAll('{user_id}', _escapeHtml(userId))
        .replaceAll('{date}',    _escapeHtml(date))
        .replaceAll('{admin}',   _escapeHtml(adminUsername));
  }

  // ── Error classification ──────────────────────────────────────────────────

  bool _isBlockedError(String? msg) {
    if (msg == null) return false;
    final lower = msg.toLowerCase();
    return lower.contains('blocked')      ||
           lower.contains('not found')    ||
           lower.contains('deleted')      ||
           lower.contains('deactivated')  ||
           lower.contains('chat not found') ||
           lower.contains('forbidden');
  }

  // ── Send photo ────────────────────────────────────────────────────────────

  Future<TelegramResult> sendPhoto({
    required String userId,
    required Uint8List photoBytes,
    required String date,
  }) async {
    if (botToken.isEmpty) {
      return TelegramResult(
        ok: false,
        error: 'Bot token not configured — go to Settings → Bot.',
      );
    }

    if (blockedUsers.contains(userId)) {
      return TelegramResult(ok: false, blocked: true, error: 'Previously blocked');
    }

    final caption = buildCaption(userId: userId, date: date);

    if (caption.length > 1024) {
      return TelegramResult(
        ok: false,
        error: 'Caption is ${caption.length} chars (limit 1024). '
               'Shorten the template in Settings → Bot.',
      );
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_apiBase/sendPhoto'))
        ..fields['chat_id']    = userId
        ..fields['caption']    = caption
        ..fields['parse_mode'] = 'HTML'
        ..files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: 'payment.png',
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final body     = await http.Response.fromStream(streamed);
      final json     = body.body;

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

  // ── Send with retry ───────────────────────────────────────────────────────

  Future<TelegramResult> sendPhotoWithRetry({
    required String userId,
    required Uint8List photoBytes,
    required String date,
    int maxRetries = 3,
    void Function(int attempt)? onRetry,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await sendPhoto(
          userId: userId, photoBytes: photoBytes, date: date);
      if (result.ok || result.blocked || !result.retryable) return result;
      if (attempt < maxRetries) {
        onRetry?.call(attempt);
        final delay = 500 + (attempt * 500) + Random().nextInt(200);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    return TelegramResult(ok: false, error: 'Max retries exceeded');
  }
}
