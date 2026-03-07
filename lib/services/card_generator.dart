// lib/services/card_generator.dart

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class CardGenerator {
  static final Map<String, Uint8List> _cache = {};

  // Card dimensions — 2:1 golden ratio landscape
  static const double W = 960.0;
  static const double H = 480.0;

  static Future<Uint8List> generate({
    required String userId,
    required String displayName,
    required double pending,
    required String date,
  }) async {
    final cacheKey = '$userId-$pending-$date';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, W, H));

    final isCredit = pending < 0;
    final absPend = pending.abs().toStringAsFixed(2);
    final initial = (displayName.isNotEmpty ? displayName : userId)[0].toUpperCase();

    // ── Palette ──────────────────────────────────────────────────────────────
    const bgDark       = Color(0xFF0A0F1E); // deep navy
    const bgCard       = Color(0xFF111827); // card surface
    const accentCredit = Color(0xFF00F5A0); // neon mint
    const accentDebit  = Color(0xFFFF4D6D); // coral red
    const surfaceLight = Color(0xFF1E2A3A); // raised panel
    const textPrimary  = Color(0xFFF1F5F9);
    const textMuted    = Color(0xFF64748B);
    const divider      = Color(0xFF1E293B);

    final accent     = isCredit ? accentCredit : accentDebit;
    final accentDim  = isCredit
        ? const Color(0xFF00F5A0).withOpacity(0.12)
        : const Color(0xFFFF4D6D).withOpacity(0.12);
    final accentMid  = isCredit
        ? const Color(0xFF00F5A0).withOpacity(0.6)
        : const Color(0xFFFF4D6D).withOpacity(0.6);
    final statusLabel = isCredit ? 'CREDIT' : 'DEBIT';

    // ── 1. Base card (rounded rect, dark) ────────────────────────────────────
    final cardRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, W, H), const Radius.circular(32));
    canvas.drawRRect(cardRRect, Paint()..color = bgCard);

    // Subtle inner background gradient via two overlapping rects
    final gradPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(W, H),
        [bgDark, const Color(0xFF0D1B2A)],
      );
    canvas.drawRRect(cardRRect, gradPaint);

    // ── 2. Glowing orb — top-left accent ─────────────────────────────────────
    final orbPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(120, 100),
        220,
        [accent.withOpacity(0.18), Colors.transparent],
      );
    canvas.drawRRect(cardRRect, orbPaint);

    // ── 3. Geometric grid lines (subtle) ─────────────────────────────────────
    _drawGrid(canvas, W, H);

    // ── 4. Thin accent border ─────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0.75, 0.75, W - 1.5, H - 1.5),
          const Radius.circular(31.5)),
      Paint()
        ..color = accent.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 5. Top accent stripe ──────────────────────────────────────────────────
    final stripePath = Path()
      ..moveTo(0, 0)
      ..lineTo(W * 0.55, 0)
      ..lineTo(W * 0.45, 4)
      ..lineTo(0, 4)
      ..close();
    canvas.drawPath(stripePath, Paint()..color = accent);

    // ── 6. Avatar ─────────────────────────────────────────────────────────────
    const double avX = 48.0;
    const double avY = 48.0;
    const double avS = 80.0;
    const double avR = 16.0;

    // Avatar glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(avX - 4, avY - 4, avS + 8, avS + 8),
          const Radius.circular(avR + 4)),
      Paint()
        ..color = accent.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Avatar background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(avX, avY, avS, avS), const Radius.circular(avR)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(avX, avY),
          Offset(avX + avS, avY + avS),
          [accent.withOpacity(0.9), accent.withOpacity(0.4)],
        ),
    );
    // Initial
    _drawText(canvas, initial,
        x: avX + avS / 2,
        y: avY + avS / 2 - 23,
        size: 36,
        weight: FontWeight.w800,
        color: bgDark,
        align: TextAlign.center);

    // ── 7. Name & ID ──────────────────────────────────────────────────────────
    const double nameX = avX + avS + 24.0;
    _drawText(canvas, displayName,
        x: nameX, y: avY + 4, size: 26, weight: FontWeight.w700, color: textPrimary);
    _drawText(canvas, userId.toUpperCase(),
        x: nameX,
        y: avY + 40,
        size: 13,
        weight: FontWeight.w500,
        color: textMuted,
        letterSpacing: 2.2);

    // ── 8. PAYTRACK logo (top-right) ──────────────────────────────────────────
    _drawTextRight(canvas, 'PAYTRACK',
        right: 48, y: avY + 28, size: 13, weight: FontWeight.w700, color: accent.withOpacity(0.55), letterSpacing: 3.5);

    // ── 9. Horizontal divider ─────────────────────────────────────────────────
    const double divY = 168.0;
    canvas.drawLine(
      const Offset(48, divY),
      const Offset(W - 48, divY),
      Paint()
        ..color = divider
        ..strokeWidth = 1,
    );

    // ── 10. Balance section ───────────────────────────────────────────────────
    const double balLabelY = divY + 28.0;
    const double balAmtY   = balLabelY + 24.0;

    _drawText(canvas, isCredit ? 'CREDIT BALANCE' : 'PENDING BALANCE',
        x: 48,
        y: balLabelY,
        size: 11,
        weight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 2.8);

    // Large amount — split currency symbol from number for styling
    _drawText(canvas, '৳',
        x: 48, y: balAmtY + 8, size: 32, weight: FontWeight.w400, color: accent.withOpacity(0.7));
    _drawText(canvas, absPend,
        x: 88, y: balAmtY, size: 72, weight: FontWeight.w700, color: accent);

    // ── 11. Pill: status ──────────────────────────────────────────────────────
    const double pillH   = 40.0;
    const double pillY   = H - 52.0;
    const double dotR    = 5.0;
    const double dotPadL = 16.0;
    const double textPadL = dotPadL + dotR * 2 + 10.0;
    const double pillPadR = 20.0;

    final pillLabelTP = _makeTP(statusLabel,
        size: 12, weight: FontWeight.w700, color: accent, letterSpacing: 2.0);
    pillLabelTP.layout();
    final pillW = textPadL + pillLabelTP.width + pillPadR;

    // Pill bg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(48, pillY, pillW, pillH), const Radius.circular(20)),
      Paint()..color = accentDim,
    );
    // Pill border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(48, pillY, pillW, pillH), const Radius.circular(20)),
      Paint()
        ..color = accent.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Dot
    canvas.drawCircle(
      Offset(48 + dotPadL + dotR, pillY + pillH / 2),
      dotR,
      Paint()..color = accent,
    );
    // Dot glow
    canvas.drawCircle(
      Offset(48 + dotPadL + dotR, pillY + pillH / 2),
      dotR + 3,
      Paint()
        ..color = accent.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Label
    _drawText(canvas, statusLabel,
        x: 48 + textPadL,
        y: pillY + (pillH / 2) - 9,
        size: 12,
        weight: FontWeight.w700,
        color: accent,
        letterSpacing: 2.0);

    // ── 12. Date (bottom-right) ───────────────────────────────────────────────
    _drawTextRight(canvas, date,
        right: 48, y: pillY + pillH / 2 - 8, size: 13, weight: FontWeight.w400, color: textMuted, letterSpacing: 0.5);

    // ── 13. Right-side decorative panel ──────────────────────────────────────
    _drawRightPanel(canvas, W, H, accent, accentDim, surfaceLight, isCredit, absPend, date);

    // ── Clip everything to card bounds ────────────────────────────────────────
    // (already constrained by recorder rect)

    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _cache[cacheKey] = bytes;
    return bytes;
  }

  // ── Decorative right panel with stat boxes ──────────────────────────────────
  static void _drawRightPanel(
    Canvas canvas,
    double W,
    double H,
    Color accent,
    Color accentDim,
    Color surfaceLight,
    bool isCredit,
    String absPend,
    String date,
  ) {
    final double panelX = W * 0.62;
    final double panelW = W - panelX - 32;
    const double panelY = 48.0;
    final double panelH = H - 96.0;

    // Panel surface
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(panelX, panelY, panelW, panelH),
          const Radius.circular(20)),
      Paint()..color = surfaceLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(panelX, panelY, panelW, panelH),
          const Radius.circular(20)),
      Paint()
        ..color = accent.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Mini bar chart decoration
    _drawMiniChart(canvas, panelX + 16, panelY + 16, panelW - 32, 80, accent, isCredit);

    // Stat rows
    final rows = [
      ('DATE', date),
      ('TYPE', isCredit ? 'Credit' : 'Debit'),
      ('AMOUNT', '৳$absPend'),
    ];

    double rowY = panelY + 112;
    for (final row in rows) {
      _drawText(canvas, row.$1,
          x: panelX + 16,
          y: rowY,
          size: 10,
          weight: FontWeight.w600,
          color: const Color(0xFF475569),
          letterSpacing: 1.8);
      _drawText(canvas, row.$2,
          x: panelX + 16,
          y: rowY + 16,
          size: 15,
          weight: FontWeight.w600,
          color: const Color(0xFFCBD5E1));
      rowY += 58;

      if (rowY < panelY + panelH - 30) {
        canvas.drawLine(
          Offset(panelX + 16, rowY - 12),
          Offset(panelX + panelW - 16, rowY - 12),
          Paint()
            ..color = const Color(0xFF1E293B)
            ..strokeWidth = 1,
        );
      }
    }
  }

  // ── Mini decorative bar chart ─────────────────────────────────────────────
  static void _drawMiniChart(Canvas canvas, double x, double y, double w, double h,
      Color accent, bool isCredit) {
    final bars = [0.4, 0.65, 0.5, 0.8, 0.55, 0.9, 0.7, 0.85];
    final barW = (w - (bars.length - 1) * 4) / bars.length;

    for (int i = 0; i < bars.length; i++) {
      final bx = x + i * (barW + 4);
      final bh = bars[i] * h;
      final by = y + h - bh;
      final isLast = i == bars.length - 1;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, barW, bh), const Radius.circular(4)),
        Paint()
          ..color = isLast ? accent : accent.withOpacity(0.25),
      );
    }
  }

  // ── Subtle background grid ────────────────────────────────────────────────
  static void _drawGrid(Canvas canvas, double W, double H) {
    final p = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.5)
      ..strokeWidth = 0.5;
    const spacing = 48.0;
    for (double gx = spacing; gx < W; gx += spacing) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, H), p);
    }
    for (double gy = spacing; gy < H; gy += spacing) {
      canvas.drawLine(Offset(0, gy), Offset(W, gy), p);
    }
  }

  // ── Text helpers ──────────────────────────────────────────────────────────
  static TextPainter _makeTP(
    String text, {
    required double size,
    required FontWeight weight,
    Color color = Colors.white,
    TextAlign align = TextAlign.left,
    double letterSpacing = 0,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
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
    final tp = _makeTP(text,
        size: size, weight: weight, color: color, align: align, letterSpacing: letterSpacing);
    tp.layout(maxWidth: 560);
    final dx = align == TextAlign.center ? x - tp.width / 2 : x;
    tp.paint(canvas, Offset(dx, y));
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
    final tp = _makeTP(text,
        size: size, weight: weight, color: color, letterSpacing: letterSpacing);
    tp.layout(maxWidth: 400);
    tp.paint(canvas, Offset(W - right - tp.width, y));
  }

  static void clearCache() => _cache.clear();
}
