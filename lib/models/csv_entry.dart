// lib/models/csv_entry.dart

class CsvEntry {
  final String filename;
  final String userId;
  final String username;
  final int okCount;
  final double pricePerOk;
  final double total;
  final String bkash;
  final String rocket;
  final String paidStatus;

  CsvEntry({
    required this.filename,
    required this.userId,
    required this.username,
    required this.okCount,
    required this.pricePerOk,
    required this.total,
    required this.bkash,
    required this.rocket,
    required this.paidStatus,
  });

  String get date => filename.replaceAll('.csv', '');
}

class UserSummary {
  final String userId;
  final String displayName;
  final double pending;

  UserSummary({
    required this.userId,
    required this.displayName,
    required this.pending,
  });
}
