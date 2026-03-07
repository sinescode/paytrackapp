// lib/services/card_generator.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class CardGenerator {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List> generate({
    required String userId,
    required String displayName,
    required double pending,
    required String date,
  }) async {
    final cacheKey = '$userId-$pending-$date';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Card dimensions (16:9 ratio, 2x for retina)
    const double W = 960.0;
    const double H = 540.0;
    const double P = 48.0; // Base padding unit

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, W, H));

    final isCredit = pending < 0;
    final absPending = pending.abs();

    // Modern color palette
    final Color primaryBg = const Color(0xFF0F172A); // Slate 900
    final Color accentColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final Color accentGlow = isCredit ? const Color(0xFF059669) : const Color(0xFFE11D48);
    final Color textPrimary = Colors.white;
    final Color textSecondary = const Color(0xFF94A3B8);
    final Color surfaceLight = const Color(0xFF1E293B);
    
    // 1. Background with subtle gradient
    final bgRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, W, H),
      const Radius.circular(24),
    );
    
    // Base dark background
    final bgPaint = Paint()..color = primaryBg;
    canvas.drawRRect(bgRect, bgPaint);

    // Subtle radial gradient overlay
    final gradientPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(W * 0.8, H * 0.2),
        W * 0.6,
        [
          accentColor.withOpacity(0.08),
          accentColor.withOpacity(0.0),
        ],
      );
    canvas.drawRRect(bgRect, gradientPaint);

    // 2. Top accent line
    final linePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(W, 0),
        [accentColor.withOpacity(0.0), accentColor, accentColor.withOpacity(0.0)],
      )
      ..strokeWidth = 2;
    canvas.drawLine(
      const Offset(P, 2),
      Offset(W - P, 2),
      linePaint,
    );

    // 3. Avatar with glow effect
    const double avatarSize = 72.0;
    const double avatarX = P;
    const double avatarY = P;

    // Glow behind avatar
    final glowPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(
      Offset(avatarX + avatarSize / 2, avatarY + avatarSize / 2),
      avatarSize / 2 + 8,
      glowPaint,
    );

    // Avatar circle
    final avatarPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(avatarX, avatarY),
        Offset(avatarX + avatarSize, avatarY + avatarSize),
        [surfaceLight, primaryBg],
      );
    canvas.drawCircle(
      Offset(avatarX + avatarSize / 2, avatarY + avatarSize / 2),
      avatarSize / 2,
      avatarPaint,
    );

    // Avatar border
    final avatarBorderPaint = Paint()
      ..color = accentColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(avatarX + avatarSize / 2, avatarY + avatarSize / 2),
      avatarSize / 2,
      avatarBorderPaint,
    );

    // Initial
    final initial = (displayName.isNotEmpty ? displayName : userId)[0].toUpperCase();
    _drawText(
      canvas,
      initial,
      x: avatarX + avatarSize / 2,
      y: avatarY + avatarSize / 2 - 24,
      size: 32,
      weight: FontWeight.w700,
      color: textPrimary,
      align: TextAlign.center,
    );

    // 4. User info column
    const double infoX = avatarX + avatarSize + 20;
    const double infoY = avatarY + 8;

    // Name
    _drawText(
      canvas,
      displayName,
      x: infoX,
      y: infoY,
      size: 28,
      weight: FontWeight.w600,
      color: textPrimary,
    );

    // User ID with subtle background pill
    final idText = 'ID: ${userId.length > 12 ? '${userId.substring(0, 12)}...' : userId}';
    final idPainter = _makeTP(idText, size: 14, weight: FontWeight.w500, color: textSecondary);
    idPainter.layout();
    
    final idPillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(infoX - 8, infoY + 36, idPainter.width + 16, 28),
      const Radius.circular(6),
    );
    final idPillPaint = Paint()..color = surfaceLight.withOpacity(0.5);
    canvas.drawRRect(idPillRect, idPillPaint);
    
    _drawText(
      canvas,
      idText,
      x: infoX,
      y: infoY + 40,
      size: 14,
      weight: FontWeight.w500,
      color: textSecondary,
    );

    // 5. Brand mark (top right)
    _drawTextRight(
      canvas,
      'PAYTRACK',
      right: P,
      y: P + 20,
      size: 14,
      weight: FontWeight.w800,
      color: textSecondary.withOpacity(0.6),
      letterSpacing: 2,
    );

    // 6. Decorative geometric elements
    final geoPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Concentric circles in background
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(W - P - 60, H - P - 100),
        40.0 * i,
        geoPaint,
      );
    }

    // 7. Main balance section
    const double balanceY = H * 0.55;
    
    // Balance label
    _drawText(
      canvas,
      isCredit ? 'CREDIT BALANCE' : 'PENDING BALANCE',
      x: P,
      y: balanceY,
      size: 12,
      weight: FontWeight.w600,
      color: textSecondary,
      letterSpacing: 1.5,
    );

    // Balance amount with large typography
    final balanceText = '৳${absPending.toStringAsFixed(2)}';
    _drawText(
      canvas,
      balanceText,
      x: P,
      y: balanceY + 28,
      size: 64,
      weight: FontWeight.w300,
      color: textPrimary,
    );

    // Accent underline for balance
    final underlinePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(P, 0),
        Offset(P + 200, 0),
        [accentColor, accentColor.withOpacity(0.0)],
      )
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(P, balanceY + 100),
      Offset(P + 180, balanceY + 100),
      underlinePaint,
    );

    // 8. Status indicator (bottom left)
    const double statusY = H - P - 32;
    const double dotSize = 8.0;
    
    // Pulsing dot effect (static representation)
    final dotPaint = Paint()..color = accentColor;
    canvas.drawCircle(
      Offset(P + dotSize / 2, statusY + 10),
      dotSize / 2,
      dotPaint,
    );
    
    // Status ring
    final ringPaint = Paint()
      ..color = accentColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(P + dotSize / 2, statusY + 10),
      dotSize,
      ringPaint,
    );

    // Status text
    _drawText(
      canvas,
      isCredit ? 'Credit Available' : 'Payment Due',
      x: P + 24,
      y: statusY,
      size: 16,
      weight: FontWeight.w600,
      color: accentColor,
    );

    // 9. Date (bottom right)
    _drawTextRight(
      canvas,
      date,
      right: P,
      y: statusY,
      size: 14,
      weight: FontWeight.w400,
      color: textSecondary,
    );

    // 10. Subtle noise texture overlay (optional visual depth)
    final noisePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..blendMode = BlendMode.overlay;
    // Simulated noise with random dots would go here, skipped for performance

    // 11. Corner accents
    final cornerPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..strokeWidth = 2;
    
    // Top-left corner detail
    canvas.drawLine(const Offset(P, P + 20), const Offset(P, P), cornerPaint);
    canvas.drawLine(const Offset(P, P), const Offset(P + 20, P), cornerPaint);
    
    // Bottom-right corner detail
    canvas.drawLine(Offset(W - P, H - P - 20), Offset(W - P, H - P), cornerPaint);
    canvas.drawLine(Offset(W - P, H - P), Offset(W - P - 20, H - P), cornerPaint);

    // Finalize
    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    _cache[cacheKey] = bytes;
    return bytes;
  }

  static TextPainter _makeTP(
    String text, {
    required double size,
    required FontWeight weight,
    Color color = Colors.black,
    TextAlign align = TextAlign.left,
    double letterSpacing = 0,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
          height: 1.2,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
  }

  static void _drawText(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double size,
    required FontWeight weight,
    required Color color,
    TextAlign align = TextAlign.left,
    double letterSpacing = 0,
  }) {
    final tp = _makeTP(
      text,
      size: size,
      weight: weight,
      color: color,
      align: align,
      letterSpacing: letterSpacing,
    );
    tp.layout(maxWidth: 800);
    
    final double dx = align == TextAlign.center 
        ? x - tp.width / 2 
        : align == TextAlign.right 
            ? x - tp.width 
            : x;
    final double dy = y;
    
    tp.paint(canvas, Offset(dx, dy));
  }

  static void _drawTextRight(
    Canvas canvas,
    String text, {
    required double right,
    required double y,
    required double size,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    final tp = _makeTP(
      text,
      size: size,
      weight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
    tp.layout(maxWidth: 600);
    tp.paint(canvas, Offset(960 - right - tp.width, y));
  }

  static void clearCache() => _cache.clear();
}
