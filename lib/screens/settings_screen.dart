// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/tier_model.dart';
import '../services/storage_service.dart';
import '../services/telegram_service.dart';
import '../theme.dart';

// ── Shared confirmation dialog ────────────────────────────────────────────────

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = kRed,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: confirmColor, size: 22),
          const SizedBox(width: 8),
        ],
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
      content: Text(message,
          style: const TextStyle(fontSize: 14, color: kSlate500)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Settings Screen ───────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late TabController _tabs;
  late AppConfig _config;

  // ── Tier + assignment + name row lists ────────────────────────────────────
  final List<_TierDefRow> _tierRows   = [];
  final List<_AssignRow>  _assignRows = [];
  final List<_NameRow>    _nameRows   = [];

  // ── Bot tab controllers ───────────────────────────────────────────────────
  late TextEditingController _botTokenCtrl;
  late TextEditingController _adminCtrl;
  late TextEditingController _templateCtrl;
  bool _tokenVisible = false;

  @override
  void initState() {
    super.initState();
    _tabs   = TabController(length: 4, vsync: this);
    _config = _storage.loadConfig();
    _botTokenCtrl = TextEditingController(text: _config.botToken);
    _adminCtrl    = TextEditingController(text: _config.adminUsername);
    _templateCtrl = TextEditingController(text: _config.captionTemplate);
    _loadFromConfig();
  }

  @override
  void dispose() {
    _botTokenCtrl.dispose();
    _adminCtrl.dispose();
    _templateCtrl.dispose();
    super.dispose();
  }

  // ── Populate rows from config ─────────────────────────────────────────────

  void _loadFromConfig() {
    // Tier definitions
    _tierRows.clear();
    for (final t in _config.tierDefinitions) {
      _tierRows.add(_TierDefRow(
        id:    t.id,
        name:  TextEditingController(text: t.name),
        min:   TextEditingController(text: t.minOk.toString()),
        max:   TextEditingController(text: t.maxOk.toString()),
        price: TextEditingController(text: t.pricePerOk.toString()),
      ));
    }

    // Assignments: one row per user with their list of tier IDs
    _assignRows.clear();
    _config.userTierIds.forEach((uid, ids) {
      _assignRows.add(_AssignRow(
        userId:  TextEditingController(text: uid),
        tierIds: List<int>.from(ids),
      ));
    });

    // Custom names
    _nameRows.clear();
    _config.customNames.forEach((uid, name) {
      _nameRows.add(_NameRow(
        userId: TextEditingController(text: uid),
        name:   TextEditingController(text: name),
      ));
    });

    // Sync bot controllers
    _botTokenCtrl.text = _config.botToken;
    _adminCtrl.text    = _config.adminUsername;
    _templateCtrl.text = _config.captionTemplate;
  }

  // ── Build current tier defs from rows ─────────────────────────────────────

  List<TierDefinition> get _currentTierDefs => _tierRows.map((r) {
        return TierDefinition(
          id:         r.id,
          name:       r.name.text.trim(),
          minOk:      int.tryParse(r.min.text)    ?? 0,
          maxOk:      int.tryParse(r.max.text)    ?? 0,
          pricePerOk: double.tryParse(r.price.text) ?? 0,
        );
      }).where((t) => t.name.isNotEmpty).toList();

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final tierDefs   = _currentTierDefs;
    final validIds   = tierDefs.map((t) => t.id).toSet();

    // userTierIds: strip IDs that no longer exist
    final userTierIds = <String, List<int>>{};
    for (final a in _assignRows) {
      final uid = a.userId.text.trim();
      if (uid.isEmpty) continue;
      final cleanIds = a.tierIds.where((id) => validIds.contains(id)).toList();
      if (cleanIds.isNotEmpty) userTierIds[uid] = cleanIds;
    }

    final customNames = <String, String>{};
    for (final n in _nameRows) {
      final uid = n.userId.text.trim();
      if (uid.isNotEmpty) customNames[uid] = n.name.text.trim();
    }

    final newConfig = _config.copyWith(
      botToken:        _botTokenCtrl.text.trim(),
      adminUsername:   _adminCtrl.text.trim().replaceAll('@', ''),
      captionTemplate: _templateCtrl.text,
      tierDefinitions: tierDefs,
      userTierIds:     userTierIds,
      customNames:     customNames,
    );

    await _storage.saveConfig(newConfig);
    setState(() => _config = newConfig);

    // Immediately sync the running TelegramService singleton so that any
    // subsequent send uses the newly saved token — no restart needed.
    TelegramService().botToken        = newConfig.botToken;
    TelegramService().adminUsername   = newConfig.adminUsername;
    TelegramService().captionTemplate = newConfig.captionTemplate;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved & exported'), backgroundColor: kGreen));
    }
  }

  Future<void> _exportConfig() async {
    try {
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Exported to ${_storage.configExportPath}'),
            backgroundColor: kGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'), backgroundColor: kRed));
      }
    }
  }

  Future<void> _importConfig() async {
    final confirmed = await _showConfirmDialog(
      context,
      title:        'Import Config',
      message:      'Importing will replace your current settings. Unsaved changes will be lost.',
      confirmLabel: 'Import',
      confirmColor: kGreen,
      icon:         Icons.file_download_outlined,
    );
    if (!confirmed) return;

    final success = await _storage.importConfig();
    if (success) {
      setState(() { _config = _storage.loadConfig(); _loadFromConfig(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Config imported from default path'),
            backgroundColor: kGreen));
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.path != null) {
      final ok = await _storage.importConfigFromFile(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Config imported successfully' : 'Import failed'),
            backgroundColor: ok ? kGreen : kRed));
        if (ok) setState(() { _config = _storage.loadConfig(); _loadFromConfig(); });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Tiers'),
            Tab(text: 'Assignments'),
            Tab(text: 'Names'),
            Tab(icon: Icon(Icons.smart_toy_outlined, size: 18), text: 'Bot'),
          ],
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TierDefsTab(
                    rows:      _tierRows,
                    nextId:    _config.nextTierId,
                    onChanged: () => setState(() {})),
                _AssignTab(
                    rows:      _assignRows,
                    tierDefs:  _currentTierDefs,
                    onChanged: () => setState(() {})),
                _NamesTab(
                    rows:      _nameRows,
                    onChanged: () => setState(() {})),
                _BotTab(
                    tokenCtrl:         _botTokenCtrl,
                    adminCtrl:         _adminCtrl,
                    templateCtrl:      _templateCtrl,
                    tokenVisible:      _tokenVisible,
                    onToggleVisibility: () =>
                        setState(() => _tokenVisible = !_tokenVisible)),
              ],
            ),
          ),
          // Import / Export footer
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kSlate200)),
                color: Colors.white),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importConfig,
                  icon:  const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Import Config'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportConfig,
                  icon:  const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Export Config'),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Export → ${_storage.configExportPath}',
                  style: const TextStyle(
                      fontSize: 10, color: kSlate500, fontFamily: 'monospace')),
              Text('CSV folder → ${_storage.csvDir}',
                  style: const TextStyle(
                      fontSize: 10, color: kSlate500, fontFamily: 'monospace')),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Tier Definitions Tab ──────────────────────────────────────────────────────

class _TierDefRow {
  int id;
  final TextEditingController name;
  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController price;

  _TierDefRow({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    required this.price,
  });
}

class _TierDefsTab extends StatelessWidget {
  final List<_TierDefRow> rows;
  final int nextId;
  final VoidCallback onChanged;

  const _TierDefsTab(
      {required this.rows, required this.nextId, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final tierName = rows[index].name.text.trim();
    final confirmed = await _showConfirmDialog(context,
        title:        'Delete Tier',
        message:      tierName.isNotEmpty
            ? 'Delete tier "$tierName"? This cannot be undone.'
            : 'Delete this tier? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: kRed,
        icon:         Icons.delete_outline);
    if (confirmed) { rows.removeAt(index); onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding:     const EdgeInsets.all(12),
          itemCount:   rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // ID badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color:        kSlate200,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('ID ${r.id}',
                            style: const TextStyle(
                                fontSize:   11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: r.name,
                          decoration: const InputDecoration(
                              labelText: 'Tier Name', hintText: 'Standard'),
                        ),
                      ),
                      IconButton(
                        icon:      const Icon(Icons.delete_outline, color: kRed),
                        onPressed: () => _confirmDelete(context, i),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller:  r.min,
                              keyboardType: TextInputType.number,
                              decoration:  const InputDecoration(labelText: 'Min OK'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller:  r.max,
                              keyboardType: TextInputType.number,
                              decoration:  const InputDecoration(labelText: 'Max OK'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller:  r.price,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration:  const InputDecoration(labelText: '৳ / OK'))),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              int newId = nextId;
              final used = rows.map((r) => r.id).toSet();
              while (used.contains(newId)) newId++;
              rows.add(_TierDefRow(
                id:    newId,
                name:  TextEditingController(),
                min:   TextEditingController(),
                max:   TextEditingController(),
                price: TextEditingController(),
              ));
              onChanged();
            },
            icon:  const Icon(Icons.add),
            label: const Text('Add Tier'),
          ),
        ),
      ),
    ]);
  }
}

// ── Assignment Tab ────────────────────────────────────────────────────────────
// Each row = one user → multi-chip selector for their tier IDs.

// Dark-mode palette for the Assignments tab
const _kAssignBg     = Color(0xFF0F172A);
const _kAssignCard   = Color(0xFF1E293B);
const _kAssignBorder = Color(0xFF2D3F55);
const _kAssignTeal   = Color(0xFF0D9488);
const _kTextPrimary  = Color(0xFFE2E8F0);
const _kTextMuted    = Color(0xFF94A3B8);
const _kTextDim      = Color(0xFF64748B);

class _AssignRow {
  final TextEditingController userId;
  List<int> tierIds;

  _AssignRow({required this.userId, required this.tierIds});
}

class _AssignTab extends StatelessWidget {
  final List<_AssignRow>     rows;
  final List<TierDefinition> tierDefs;
  final VoidCallback         onChanged;

  const _AssignTab(
      {required this.rows, required this.tierDefs, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final uid       = rows[index].userId.text.trim();
    final confirmed = await _showConfirmDialog(context,
        title:        'Remove Assignment',
        message:      uid.isNotEmpty
            ? 'Remove all tier assignments for user "$uid"?'
            : 'Remove this user assignment?',
        confirmLabel: 'Remove',
        confirmColor: kRed,
        icon:         Icons.person_remove_outlined);
    if (confirmed) { rows.removeAt(index); onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kAssignBg,
      child: Column(children: [
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined, size: 52, color: _kTextDim),
                      const SizedBox(height: 12),
                      const Text('No assignments yet',
                          style: TextStyle(fontSize: 15, color: _kTextMuted,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Tap "Add User" below to get started',
                          style: TextStyle(fontSize: 12, color: _kTextDim)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:     const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  itemCount:   rows.length,
                  itemBuilder: (ctx, i) {
                    final row = rows[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color:        _kAssignCard,
                        borderRadius: BorderRadius.circular(16),
                        border:       Border.all(color: _kAssignBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header: index badge + User ID + delete ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: _kAssignTeal.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _kAssignTeal)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller:   row.userId,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                      color: _kTextPrimary,
                                      fontFamily: 'monospace',
                                      fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText:  'Telegram User ID',
                                    labelStyle: const TextStyle(
                                        color: _kTextDim, fontSize: 13),
                                    prefixIcon: const Icon(Icons.person_outline,
                                        size: 18, color: _kTextDim),
                                    filled:    true,
                                    fillColor: _kAssignBg,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: _kAssignBorder)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: _kAssignTeal, width: 2)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: kRed, size: 20),
                                tooltip:  'Remove',
                                onPressed: () => _confirmDelete(ctx, i),
                              ),
                            ]),
                          ),

                          // ── Section divider ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: [
                              const Icon(Icons.layers_outlined,
                                  size: 13, color: _kTextDim),
                              const SizedBox(width: 5),
                              const Text('ASSIGNED TIERS',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextDim,
                                      letterSpacing: 1.1)),
                              const SizedBox(width: 8),
                              Expanded(child: Container(
                                  height: 1, color: _kAssignBorder)),
                              if (row.tierIds.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kAssignTeal.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${row.tierIds.length}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _kAssignTeal)),
                                ),
                              ],
                            ]),
                          ),

                          // ── Tier toggle chips ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: tierDefs.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _kAssignBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _kAssignBorder),
                                    ),
                                    child: const Row(children: [
                                      Icon(Icons.info_outline,
                                          size: 14, color: _kTextDim),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'No tier definitions yet — add them in the Tiers tab.',
                                          style: TextStyle(
                                              fontSize: 12, color: _kTextDim),
                                        ),
                                      ),
                                    ]),
                                  )
                                : Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: tierDefs.map((def) {
                                      final selected =
                                          row.tierIds.contains(def.id);
                                      return GestureDetector(
                                        onTap: () {
                                          if (selected) {
                                            row.tierIds.remove(def.id);
                                          } else {
                                            if (!row.tierIds.contains(def.id)) {
                                              row.tierIds.add(def.id);
                                            }
                                          }
                                          onChanged();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 160),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? _kAssignTeal.withOpacity(0.18)
                                                : _kAssignBg,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: selected
                                                  ? _kAssignTeal
                                                  : _kAssignBorder,
                                              width: selected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                selected
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                                size:  13,
                                                color: selected
                                                    ? _kAssignTeal
                                                    : _kTextDim,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(def.name,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: selected
                                                          ? _kAssignTeal
                                                          : _kTextMuted)),
                                              const SizedBox(width: 5),
                                              Text(
                                                '${def.minOk}–${def.maxOk}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: selected
                                                        ? _kAssignTeal
                                                            .withOpacity(0.7)
                                                        : _kTextDim),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // ── Add button ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            color:  _kAssignCard,
            border: Border(top: BorderSide(color: _kAssignBorder)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAssignTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:   const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              onPressed: () {
                rows.add(_AssignRow(
                    userId: TextEditingController(), tierIds: []));
                onChanged();
              },
              icon:  const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add User Assignment',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Custom Names Tab ──────────────────────────────────────────────────────────

class _NameRow {
  final TextEditingController userId;
  final TextEditingController name;
  _NameRow({required this.userId, required this.name});
}

class _NamesTab extends StatelessWidget {
  final List<_NameRow> rows;
  final VoidCallback   onChanged;
  const _NamesTab({required this.rows, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final uid       = rows[index].userId.text.trim();
    final confirmed = await _showConfirmDialog(context,
        title:        'Delete Name',
        message:      uid.isNotEmpty
            ? 'Delete custom name for user "$uid"?'
            : 'Delete this custom name entry?',
        confirmLabel: 'Delete',
        confirmColor: kRed,
        icon:         Icons.delete_outline);
    if (confirmed) { rows.removeAt(index); onChanged(); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding:     const EdgeInsets.all(12),
          itemCount:   rows.length,
          itemBuilder: (_, i) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller:  rows[i].userId,
                        keyboardType: TextInputType.number,
                        decoration:  const InputDecoration(labelText: 'User ID'),
                        style:       const TextStyle(fontFamily: 'monospace'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: rows[i].name,
                        decoration: const InputDecoration(
                            labelText: 'Display Name'))),
                IconButton(
                  icon:      const Icon(Icons.delete_outline, color: kRed),
                  onPressed: () => _confirmDelete(context, i),
                ),
              ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              rows.add(_NameRow(
                  userId: TextEditingController(),
                  name:   TextEditingController()));
              onChanged();
            },
            icon:  const Icon(Icons.add),
            label: const Text('Add Name'),
          ),
        ),
      ),
    ]);
  }
}

// ── Bot Tab ───────────────────────────────────────────────────────────────────

class _BotTab extends StatelessWidget {
  final TextEditingController tokenCtrl;
  final TextEditingController adminCtrl;
  final TextEditingController templateCtrl;
  final bool         tokenVisible;
  final VoidCallback onToggleVisibility;

  const _BotTab({
    required this.tokenCtrl,
    required this.adminCtrl,
    required this.templateCtrl,
    required this.tokenVisible,
    required this.onToggleVisibility,
  });

  bool _looksValid(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    final parts = t.split(':');
    return parts.length == 2 &&
        RegExp(r'^\d+$').hasMatch(parts[0]) &&
        parts[1].length >= 30;
  }

  /// Build a preview of the caption using the current template + admin value.
  String _preview(String template, String admin) {
    return template
        .replaceAll('{user_id}', '5247038532')
        .replaceAll('{date}',    '2024-12-25')
        .replaceAll('{admin}',   admin.replaceAll('@', '').trim());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Section header ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.smart_toy_outlined, size: 20, color: kSlate500),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Telegram Bot',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      'Token & admin are stored in SharedPreferences only — '
                      'never written to Config.json.',
                      style: TextStyle(fontSize: 12, color: kSlate500),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // ── Bot token ─────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bot Token',
                    style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      kSlate500)),
                const SizedBox(height: 8),
                TextField(
                  controller:  tokenCtrl,
                  obscureText: !tokenVisible,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText:   '1234567890:ABCdefGHIjklMNOpqrSTUvwx...',
                    hintStyle:  const TextStyle(fontSize: 12, color: kSlate500),
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        tokenVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: onToggleVisibility,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                // Live format validation
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: tokenCtrl,
                  builder: (_, val, __) {
                    final tok = val.text.trim();
                    if (tok.isEmpty) return const SizedBox.shrink();
                    final valid = _looksValid(tok);
                    return Row(children: [
                      Icon(
                        valid
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size:  14,
                        color: valid ? kGreen : kRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        valid
                            ? 'Token format looks valid'
                            : 'Expected format: 123456789:ABCdef...',
                        style: TextStyle(
                            fontSize: 11,
                            color:    valid ? kGreen : kRed),
                      ),
                    ]);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Admin username ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Username',
                    style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      kSlate500)),
                const SizedBox(height: 2),
                const Text(
                  'Shown in the receipt caption as @username. Used as {admin} placeholder.',
                  style: TextStyle(fontSize: 11, color: kSlate400),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: adminCtrl,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    prefixText: '@',
                    hintText:   'turja_un',
                    border:     OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Caption template ──────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Caption Template',
                        style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            color:      kSlate500)),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding:         EdgeInsets.zero,
                          minimumSize:     const Size(0, 0),
                          tapTargetSize:   MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        templateCtrl.text =
                            AppConfig.defaultCaptionTemplate;
                      },
                      child: const Text('Reset to default',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Placeholder help
                Wrap(
                  spacing:    6,
                  runSpacing: 4,
                  children:   ['{user_id}', '{date}', '{admin}'].map((p) {
                    return ActionChip(
                      label: Text(p,
                          style: const TextStyle(
                              fontSize: 11, fontFamily: 'monospace')),
                      visualDensity:        VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        final ctrl     = templateCtrl;
                        final text     = ctrl.text;
                        final sel      = ctrl.selection;
                        final newText  = text.replaceRange(
                            sel.start < 0 ? text.length : sel.start,
                            sel.end   < 0 ? text.length : sel.end,
                            p);
                        ctrl.value = TextEditingValue(
                          text:      newText,
                          selection: TextSelection.collapsed(
                              offset: (sel.start < 0
                                  ? text.length
                                  : sel.start) + p.length),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller:  templateCtrl,
                  maxLines:    8,
                  style:       const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration:  const InputDecoration(
                    border:      OutlineInputBorder(),
                    hintText:    'Enter HTML caption…',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Live preview ──────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preview',
                    style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      kSlate500)),
                const SizedBox(height: 4),
                const Text('(HTML tags will render on Telegram, shown raw here)',
                    style: TextStyle(fontSize: 10, color: kSlate400)),
                const SizedBox(height: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: templateCtrl,
                  builder: (_, tplVal, __) =>
                      ValueListenableBuilder<TextEditingValue>(
                    valueListenable: adminCtrl,
                    builder: (_, admVal, __) {
                      final preview = _preview(tplVal.text, admVal.text);
                      final tooLong = preview.length > 1024;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width:      double.infinity,
                            padding:    const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:        kSlate100,
                              borderRadius: BorderRadius.circular(10),
                              border:       Border.all(
                                  color: tooLong ? kRed : kSlate200),
                            ),
                            child: Text(
                              preview,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.55),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${preview.length} / 1024 chars',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: tooLong ? kRed : kSlate400),
                              ),
                            ],
                          ),
                          if (tooLong)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '⚠ Caption exceeds Telegram limit of 1024 characters.',
                                style: TextStyle(fontSize: 11, color: kRed),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── How-to card ───────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How to get a bot token',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const _Step(n: '1', text: 'Open Telegram and search for @BotFather'),
                const _Step(n: '2', text: 'Send /newbot and follow the prompts'),
                const _Step(n: '3', text: 'Copy the token BotFather gives you'),
                const _Step(n: '4',
                    text: 'Paste it above and tap Save — '
                        'stored in SharedPreferences only'),
              ],
            ),
          ),
        ),

      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width:     20,
          height:    20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: kSlate200, shape: BoxShape.circle),
          child: Text(n,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: kSlate500))),
      ]),
    );
  }
}
