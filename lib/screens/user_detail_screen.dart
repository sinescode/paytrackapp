// lib/screens/user_detail_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/data_service.dart';
import '../services/storage_service.dart';
import '../services/card_generator.dart';
import '../services/telegram_service.dart';
import '../theme.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final StorageService _storage = StorageService();
  final TelegramService _telegram = TelegramService();
  late DataService _data;
  late List<Map<String, dynamic>> _entries;
  double _pending = 0;
  String _displayName = '';
  final _amountCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _data = DataService(_storage);
    _load();
  }

  void _load() {
    final all = _data.loadAllData();
    final config = _storage.loadConfig();
    final balances = _storage.loadBalances();
    final name = config.customNames[widget.userId];
    setState(() {
      _displayName = (name != null && name.isNotEmpty) ? name : widget.userId;
      _entries = _data.getUserEntries(all, widget.userId);
      _pending = _data.getNetPending(all, widget.userId, balances);
    });
  }

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _applyTransaction() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;
    await _storage.updateBalance(widget.userId, -amount);
    _amountCtrl.clear();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction applied: ৳${amount.toStringAsFixed(2)}')),
      );
    }
  }

  Future<void> _downloadCard() async {
    try {
      final bytes = await CardGenerator.generate(
        userId: widget.userId,
        displayName: _displayName,
        pending: _pending,
        date: _today,
      );
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/payment_${widget.userId}_$_today.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Payment card for $_displayName');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _sendTelegram() async {
    setState(() => _sending = true);
    try {
      final bytes = await CardGenerator.generate(
        userId: widget.userId,
        displayName: _displayName,
        pending: _pending,
        date: _today,
      );
      final result = await _telegram.sendPhotoWithRetry(
        userId: widget.userId,
        photoBytes: bytes,
        date: _today,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.ok ? 'Sent successfully!' : 'Failed: ${result.error}'),
          backgroundColor: result.ok ? kGreen : kRed,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copyUserId() {
    Clipboard.setData(ClipboardData(text: widget.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User ID copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayName[0].toUpperCase();
    final isCredit = _pending < 0;
    final balColor = isCredit ? kGreen : kRed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                            color: kBlue, borderRadius: BorderRadius.circular(14)),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, top: 8),
                            child: Text(initial,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    fontFamily: 'monospace')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    fontFamily: 'monospace')),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('ID: ${widget.userId}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: kSlate500,
                                          fontFamily: 'monospace')),
                                ),
                                GestureDetector(
                                  onTap: _copyUserId,
                                  child: const Icon(Icons.copy, size: 14, color: kSlate400),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Text('PAYTRACK',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kSlate400,
                              letterSpacing: 1,
                              fontFamily: 'monospace')),
                    ],
                  ),
                  const Divider(height: 28, color: kSlate100),
                  Text('PENDING BALANCE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kSlate400,
                          letterSpacing: 1,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 6),
                  Text('৳${_pending.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: balColor,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: isCredit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          children: [
                            Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(color: balColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(isCredit ? 'Credit' : 'Pending',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isCredit ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      Text(_today,
                          style: const TextStyle(
                              fontSize: 12, color: kSlate400, fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kTelegram,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _sending ? null : _sendTelegram,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: Text(_sending ? 'Sending...' : 'Send via Bot'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _downloadCard,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Record transaction
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Transaction',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: '৳ ',
                            prefixStyle: TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _applyTransaction,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Positive = payment (reduces balance). Negative = charge (adds to balance).',
                    style: TextStyle(fontSize: 11, color: kSlate500),
                  ),
                ],
              ),
            ),
          ),

          // Entry history
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Entry History',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${_entries.length} records',
                          style: const TextStyle(fontSize: 12, color: kSlate400)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kSlate100),
                if (_entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('No entries found', style: TextStyle(color: kSlate400))),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 38,
                      dataRowMinHeight: 44,
                      headingTextStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kSlate500,
                          letterSpacing: 0.5),
                      columns: const [
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('OK'), numeric: true),
                        DataColumn(label: Text('RATE'), numeric: true),
                        DataColumn(label: Text('TOTAL'), numeric: true),
                        DataColumn(label: Text('BKASH')),
                        DataColumn(label: Text('ROCKET')),
                      ],
                      rows: _entries.map((e) {
                        return DataRow(cells: [
                          DataCell(Text(e['date'] as String,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                          DataCell(Text('${e['ok_count']}',
                              style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text(
                              '৳${(e['price_per_ok'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'monospace', color: kSlate500))),
                          DataCell(Text('৳${(e['total'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                          DataCell(_pill(e['bkash'] as String, Colors.blue)),
                          DataCell(_pill(e['rocket'] as String, Colors.purple)),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String value, Color color) {
    if (value == 'Not Provided' || value.isEmpty) {
      return const Text('—', style: TextStyle(color: kSlate200));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(999)),
      child: Text(value,
          style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace')),
    );
  }
}
