// lib/theme.dart

import 'package:flutter/material.dart';

// ── Dark palette ──────────────────────────────────────────────────────────────
// kSlate* names are kept so all screens compile without changes.
// Values are remapped to dark equivalents.

const kBlue     = Color(0xFF60A5FA); // blue-400  — bright enough on dark bg
const kSlate900 = Color(0xFFF1F5F9); // was darkest text → now lightest (primary text)
const kSlate700 = Color(0xFFCBD5E1); // medium-light text
const kSlate500 = Color(0xFF94A3B8); // secondary text (same as before — works in dark)
const kSlate400 = Color(0xFF64748B); // muted / icon
const kSlate200 = Color(0xFF2D3F55); // borders / dividers
const kSlate100 = Color(0xFF1E293B); // elevated surface (cards, dialogs)
const kSlate50  = Color(0xFF0F172A); // main scaffold background
const kRed      = Color(0xFFF87171); // red-400 — lighter for dark bg legibility
const kGreen    = Color(0xFF34D399); // emerald-400
const kTelegram = Color(0xFF229ED9);

// Extra dark-specific surface
const kSurface2 = Color(0xFF263347);

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBlue,
        brightness: Brightness.dark,
        surface: kSlate100,
      ),
      scaffoldBackgroundColor: kSlate50,
      appBarTheme: const AppBarTheme(
        backgroundColor: kSlate100,
        foregroundColor: kSlate900,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: kSlate200,
        titleTextStyle: TextStyle(
          color: kSlate900,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      cardTheme: CardThemeData(
        color: kSlate100,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kSlate200),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: kSlate100,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSlate50,
        hintStyle: const TextStyle(color: kSlate400),
        labelStyle: const TextStyle(color: kSlate500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kSlate200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kSlate200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBlue, width: 2)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kSlate700,
          side: const BorderSide(color: kSlate200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kBlue),
      ),
      dividerTheme: const DividerThemeData(color: kSlate200),
      iconTheme: const IconThemeData(color: kSlate500),
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: kSlate900),
        bodyMedium:  TextStyle(color: kSlate700),
        bodySmall:   TextStyle(color: kSlate500),
        titleLarge:  TextStyle(color: kSlate900, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: kSlate900, fontWeight: FontWeight.w600),
        labelSmall:  TextStyle(color: kSlate500),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kSlate500,
          letterSpacing: 0.5,
        ),
        dataTextStyle: TextStyle(color: kSlate900, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kSurface2,
        contentTextStyle: TextStyle(color: kSlate900),
      ),
    );
