// lib/screens/overview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/csv_entry.dart';
import '../services/data_service.dart';
import '../services/storage_service.dart';
import '../services/card_generator.dart';
import '../services/telegram_service.dart';
import '../theme.dart';
import 'user_detail_screen.dart';
import 'settings_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late DataService _data;
  final StorageService _storage = StorageService();
  final TelegramService _telegram = TelegramService();
  List<UserSummary> _users = [];
  List<UserSummary> _filtered = [];
  double _totalPending = 0;
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _data = DataService(_storage);
    _load();
  }

  void _load() {
    setState(() => _loading = true);
    final users = _data.buildUserSummaries();
    final total = users.fold(0.0, (s, u) => s + u.pending);
    setState(() {
      _users = users;
      _filtered = users;
      _totalPending = total;
      _loading = false;
    });
  }

  void _filter(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users
              .where((u) =>
                  u.userId.toLowerCase().contains(lower) ||
                  u.displayName.toLowerCase().contains(lower))
              .toList();
    });
  }

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _sendAll() async {
    if (_users.isEmpty) return;
    final date = _today;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SendAllDialog(
        users: _users,
        date: date,
        telegram: _telegram,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration:
                  BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('PayTrack'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Summary card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('TOTAL PENDING',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: kSlate500,
                                                letterSpacing: 1)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '৳${_totalPending.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: kRed,
                                              fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('USERS',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: kSlate500,
                                              letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text('${_filtered.length}',
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: kSlate900)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Send all button
                          if (_users.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kTelegram,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12))),
                                onPressed: _sendAll,
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Send All via Telegram Bot'),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Search
                          TextField(
                            controller: _search,
                            onChanged: _filter,
                            decoration: InputDecoration(
                              hintText: 'Search by user ID or name…',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _search.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _search.clear();
                                        _filter('');
                                      })
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: kGreen),
                            SizedBox(height: 12),
                            Text('All clear',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, color: kSlate700)),
                            Text('No users found',
                                style: TextStyle(color: kSlate400, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _UserTile(
                            user: _filtered[i],
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        UserDetailScreen(userId: _filtered[i].userId)),
                              );
                              _load();
                            },
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  void _copyUserId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: user.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('User ID copied to clipboard'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        (user.displayName.isNotEmpty ? user.displayName : user.userId)[0].toUpperCase();
    final isCredit = user.pending < 0;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: kBlue.withOpacity(0.1),
          child: Text(initial,
              style: const TextStyle(
                  color: kBlue,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        title: Text(user.displayName,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'monospace')),
        subtitle: Row(
          children: [
            Expanded(
              child: Text('ID: ${user.userId}',
                  style: const TextStyle(
                      fontSize: 12, color: kSlate500, fontFamily: 'monospace')),
            ),
            GestureDetector(
              onTap: () => _copyUserId(context),
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.copy, size: 13, color: kSlate400),
              ),
            ),
          ],
        ),
        trailing: Text(
          '৳${user.pending.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isCredit ? kGreen : kRed,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

// ── OPTIMIZED Send All Dialog ───────────────────────────────────────────────

class _SendAllDialog extends StatefulWidget {
  final List<UserSummary> users;
  final String date;
  final TelegramService telegram;
  const _SendAllDialog({
    required this.users,
    required this.date,
    required this.telegram,
  });

  @override
  State<_SendAllDialog> createState() => _SendAllDialogState();
}

class _SendAllDialogState extends State<_SendAllDialog> {
  final List<_LogEntry> _logs = [];
  int _sent = 0;
  int _failed = 0;
  int _blocked = 0;
  int _done = 0;
  bool _finished = false;
  bool _cancelled = false;
  bool _preparing = true;
  String _status = 'Preparing cards...';

  // Process 5 concurrent sends (respects Telegram rate limits)
  static const int _concurrency = 5;

  @override
  void initState() {
    super.initState();
    _runOptimized();
  }

  Future<void> _runOptimized() async {
    try {
      // PHASE 1: Pre-generate ALL cards in parallel (CPU-bound)
      setState(() {
        _preparing = true;
        _status = 'Generating ${widget.users.length} cards...';
      });

      final cardFutures = widget.users.map((user) => _generateCard(user)).toList();
      final cards = await Future.wait(cardFutures);

      final userCards = <String, Uint8List>{};
      for (int i = 0; i < widget.users.length; i++) {
        if (cards[i] != null) {
          userCards[widget.users[i].userId] = cards[i]!;
        }
      }

      if (_cancelled) return;

      setState(() {
        _preparing = false;
        _status = 'Sending...';
      });

      // PHASE 2: Send in parallel batches (I/O-bound)
      final queue = widget.users.where((u) => userCards.containsKey(u.userId)).toList();
      
      while (queue.isNotEmpty && !_cancelled) {
        final batch = queue.take(_concurrency).toList();
        queue.removeRange(0, batch.length);

        // Process batch concurrently
        await Future.wait(
          batch.map((user) => _sendToUser(user, userCards[user.userId]!)),
          eagerError: false,
        );
      }

      setState(() => _finished = true);
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _finished = true;
      });
    }
  }

  Future<Uint8List?> _generateCard(UserSummary user) async {
    try {
      return await CardGenerator.generate(
        userId: user.userId,
        displayName: user.displayName,
        pending: user.pending,
        date: widget.date,
      );
    } catch (e) {
      _addLog(user.userId, user.displayName, 'err', 'Card generation failed');
      _failed++;
      _done++;
      return null;
    }
  }

  Future<void> _sendToUser(UserSummary user, Uint8List bytes) async {
    if (_cancelled) return;

    _addLog(user.userId, user.displayName, 'pending', 'sending...');

    try {
      final result = await widget.telegram.sendPhotoWithRetry(
        userId: user.userId,
        photoBytes: bytes,
        date: widget.date,
        onRetry: (a) => _updateLog(user.userId, 'retry', 'retry $a...'),
      );

      if (result.ok) {
        _sent++;
        _updateLog(user.userId, 'ok', 'sent ✓');
      } else if (result.blocked) {
        _blocked++;
        _updateLog(user.userId, 'blocked', 'blocked by user');
      } else {
        _failed++;
        _updateLog(user.userId, 'err', result.error ?? 'failed');
      }
    } catch (e) {
      _failed++;
      _updateLog(user.userId, 'err', e.toString());
    }

    setState(() => _done++);
  }

  void _addLog(String id, String name, String status, String msg) {
    setState(() => _logs.add(_LogEntry(id: id, name: name, status: status, msg: msg)));
  }

  void _updateLog(String id, String status, String msg) {
    setState(() {
      for (int i = _logs.length - 1; i >= 0; i--) {
        if (_logs[i].id == id) {
          _logs[i] = _LogEntry(id: id, name: _logs[i].name, status: status, msg: msg);
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.users.length;
    final pct = total > 0 ? _done / total : 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Expanded(
            child: Text('Send to All Users',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (!_finished)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                setState(() => _cancelled = true);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_preparing) ...[
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 12),
              Text(_status, style: TextStyle(color: kSlate500, fontSize: 13)),
            ] else ...[
              LinearProgressIndicator(
                value: pct,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: kSlate200,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_done / $total',
                      style: const TextStyle(fontSize: 12, color: kSlate500)),
                  Text('${(pct * 100).round()}%',
                      style: const TextStyle(fontSize: 12, color: kSlate500)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Stats badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatBadge(count: _sent, color: kGreen, label: 'sent'),
                const SizedBox(width: 8),
                _StatBadge(count: _failed, color: kRed, label: 'failed'),
                const SizedBox(width: 8),
                _StatBadge(count: _blocked, color: Colors.amber, label: 'blocked'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: kSlate200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                reverse: true,
                itemBuilder: (_, i) => _LogRow(entry: _logs[i]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_finished)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done — $_sent sent, $_failed failed, $_blocked blocked'),
          ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _StatBadge({required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count $label',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _LogEntry {
  final String id;
  final String name;
  final String status;
  final String msg;
  _LogEntry({
    required this.id,
    required this.name,
    required this.status,
    required this.msg,
  });
}

class _LogRow extends StatelessWidget {
  final _LogEntry entry;
  const _LogRow({required this.entry});

  Color get _dot {
    return switch (entry.status) {
      'ok' => kGreen,
      'err' => kRed,
      'blocked' => Colors.amber,
      'retry' => Colors.orange,
      _ => kSlate400,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.name} — ${entry.msg}',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}