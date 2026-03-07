// lib/theme.dart

import 'package:flutter/material.dart';

const kBlue = Color(0xFF1D4ED8);
const kSlate900 = Color(0xFF0F172A);
const kSlate700 = Color(0xFF334155);
const kSlate500 = Color(0xFF64748B);
const kSlate400 = Color(0xFF94A3B8);
const kSlate200 = Color(0xFFE2E8F0);
const kSlate100 = Color(0xFFF1F5F9);
const kSlate50  = Color(0xFFF8FAFC);
const kRed      = Color(0xFFEF4444);
const kGreen    = Color(0xFF10B981);
const kTelegram = Color(0xFF229ED9);

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
      scaffoldBackgroundColor: kSlate50,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
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
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kSlate200),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSlate50,
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
    );
