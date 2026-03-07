// lib/services/card_generator.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CardGenerator {
  static Future<Uint8List> generate({
    required String userId,
    required String displayName,
    required double pending,
    required String date,
  }) async {
    const W = 960.0;
    const H = 480.0;
    const P = 56.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, W, H));

    final isCredit = pending < 0;
    final balColor = isCredit ? const Color(0xFF059669) : const Color(0xFFEF4444);
    final pillBg = isCredit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final pillFg = isCredit ? const Color(0xFF065F46) : const Color(0xFF991B1B);
    final dotColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final label = isCredit ? 'Credit' : 'Pending';
    final balLabel = isCredit ? 'CREDIT BALANCE' : 'PENDING BALANCE';
    final absPend = pending.abs().toStringAsFixed(2);
    final initial = (displayName.isNotEmpty ? displayName : userId)[0].toUpperCase();

    // 1. White background
    final bgPaint = Paint()..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, W, H), const Radius.circular(40));
    canvas.drawRRect(rrect, bgPaint);
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 1, W - 2, H - 2), const Radius.circular(40)),
        borderPaint);

    // 2. Avatar square
    const AV = 96.0;
    const AVR = 22.0;
    final avatarPaint = Paint()..color = const Color(0xFF1D4ED8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(P, P, AV, AV), const Radius.circular(AVR)),
        avatarPaint);

    // Avatar initial — top-left aligned, positioned so it sits visually at the top of the avatar
    _drawText(canvas, initial,
        x: P + 18,
        y: P + 14,
        size: 42,
        weight: FontWeight.w700,
        color: Colors.white);

    // 3. Name — mono font
    _drawText(canvas, displayName,
        x: P + AV + 28, y: P + 8, size: 32, weight: FontWeight.w700, color: const Color(0xFF0F172A));

    // 4. User ID — mono font
    _drawText(canvas, 'ID: $userId',
        x: P + AV + 28, y: P + 54, size: 22, weight: FontWeight.w400, color: const Color(0xFF64748B));

    // 5. PAYTRACK watermark — mono font
    _drawTextRight(canvas, 'PAYTRACK',
        right: P, y: P + AV / 2 - 11, size: 20, weight: FontWeight.w700, color: const Color(0xFFCBD5E1));

    // 6. Divider
    final divY = P + AV + 36;
    final divPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(P, divY), Offset(W - P, divY), divPaint);

    // 7. Balance label — mono font
    final lblY = divY + 30;
    _drawText(canvas, balLabel,
        x: P, y: lblY, size: 20, weight: FontWeight.w600, color: const Color(0xFF94A3B8));

    // 8. Balance amount — mono font
    _drawText(canvas, '৳$absPend',
        x: P, y: lblY + 34, size: 72, weight: FontWeight.w500, color: balColor);

    // 9. Status pill
    const pillH = 46.0;
    final pillY = H - P - pillH;

    final tp = _makeTP('  $label  ', size: 22, weight: FontWeight.w600);
    tp.layout();
    final pillW = tp.width + 50;

    final pillPaint = Paint()..color = pillBg;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(P, pillY, pillW, pillH), const Radius.circular(23)),
        pillPaint);

    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(P + 22, pillY + pillH / 2), 7, dotPaint);

    _drawText(canvas, label,
        x: P + 36, y: pillY + pillH / 2 - 12, size: 22, weight: FontWeight.w600, color: pillFg);

    // 10. Date — mono font
    _drawTextRight(canvas, date,
        right: P, y: pillY + pillH / 2 - 11, size: 20, weight: FontWeight.w400, color: const Color(0xFF94A3B8));

    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static TextPainter _makeTP(String text,
      {required double size,
      required FontWeight weight,
      Color color = Colors.black,
      TextAlign align = TextAlign.left}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace', // Always mono
          fontSize: size,
          fontWeight: weight,
          color: color,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
  }

  static void _drawText(Canvas canvas, String text,
      {required double x,
      required double y,
      required double size,
      required FontWeight weight,
      required Color color,
      TextAlign align = TextAlign.left}) {
    final tp = _makeTP(text, size: size, weight: weight, color: color, align: align);
    tp.layout(maxWidth: 800);
    final dx = align == TextAlign.center ? x - tp.width / 2 : x;
    tp.paint(canvas, Offset(dx, y));
  }

  static void _drawTextRight(Canvas canvas, String text,
      {required double right,
      required double y,
      required double size,
      required FontWeight weight,
      required Color color}) {
    final tp = _makeTP(text, size: size, weight: weight, color: color);
    tp.layout(maxWidth: 600);
    tp.paint(canvas, Offset(960 - right - tp.width, y));
  }
}
