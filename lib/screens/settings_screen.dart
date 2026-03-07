// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/tier_model.dart';
import '../services/storage_service.dart';
import '../theme.dart';

// ── Shared confirmation dialog helper ────────────────────────────────────────

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
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: confirmColor, size: 22),
            const SizedBox(width: 8),
          ],
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 14, color: kSlate500)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
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

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late TabController _tabs;
  late AppConfig _config;

  // Tier definition controllers
  final List<_TierDefRow> _tierDefs = [];

  // User assignment controllers
  final List<_AssignRow> _assigns = [];

  // Custom name controllers
  final List<_NameRow> _names = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _config = _storage.loadConfig();
    _loadFromConfig();
  }

  void _loadFromConfig() {
    _tierDefs.clear();
    for (final t in _config.tierDefinitions) {
      _tierDefs.add(_TierDefRow(
        name: TextEditingController(text: t.name),
        min: TextEditingController(text: t.minOk.toString()),
        max: TextEditingController(text: t.maxOk.toString()),
        price: TextEditingController(text: t.pricePerOk.toString()),
      ));
    }

    _assigns.clear();
    _config.userTiers.forEach((uid, tiers) {
      for (final t in tiers) {
        final matchingDef = _config.tierDefinitions.firstWhere(
          (d) => d.minOk == t.minOk && d.maxOk == t.maxOk && d.pricePerOk == t.pricePerOk,
          orElse: () => TierDefinition(name: '', minOk: t.minOk, maxOk: t.maxOk, pricePerOk: t.pricePerOk),
        );
        _assigns.add(_AssignRow(
          userId: TextEditingController(text: uid),
          tierName: matchingDef.name,
        ));
      }
    });

    _names.clear();
    _config.customNames.forEach((uid, name) {
      _names.add(_NameRow(
        userId: TextEditingController(text: uid),
        name: TextEditingController(text: name),
      ));
    });
  }

  List<TierDefinition> get _currentTierDefs {
    return _tierDefs.map((r) {
      return TierDefinition(
        name: r.name.text.trim(),
        minOk: int.tryParse(r.min.text) ?? 0,
        maxOk: int.tryParse(r.max.text) ?? 0,
        pricePerOk: double.tryParse(r.price.text) ?? 0,
      );
    }).where((t) => t.name.isNotEmpty).toList();
  }

  Future<void> _save() async {
    final tierDefs = _currentTierDefs;

    final userTiers = <String, List<UserTier>>{};
    for (final a in _assigns) {
      final uid = a.userId.text.trim();
      if (uid.isEmpty) continue;
      final def = tierDefs.firstWhere((d) => d.name == a.tierName,
          orElse: () => TierDefinition(name: '', minOk: 0, maxOk: 0, pricePerOk: 0));
      if (def.name.isEmpty) continue;
      userTiers.putIfAbsent(uid, () => []).add(UserTier(
        minOk: def.minOk,
        maxOk: def.maxOk,
        pricePerOk: def.pricePerOk,
      ));
    }

    final customNames = <String, String>{};
    for (final n in _names) {
      final uid = n.userId.text.trim();
      if (uid.isNotEmpty) customNames[uid] = n.name.text.trim();
    }

    final newConfig = _config.copyWith(
      tierDefinitions: tierDefs,
      userTiers: userTiers,
      customNames: customNames,
    );
    await _storage.saveConfig(newConfig);
    setState(() => _config = newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved'), backgroundColor: kGreen));
    }
  }

  Future<void> _exportConfig() async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Export Config',
      message: 'This will save the current settings to:\n${_storage.configExportPath}\n\nAny existing file will be overwritten.',
      confirmLabel: 'Export',
      confirmColor: kGreen,
      icon: Icons.file_upload_outlined,
    );
    if (!confirmed) return;

    try {
      await _save();
      final path = await _storage.exportConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $path'), backgroundColor: kGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e'), backgroundColor: kRed));
      }
    }
  }

  Future<void> _importConfig() async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Import Config',
      message: 'Importing will replace your current settings with the file contents. Unsaved changes will be lost.',
      confirmLabel: 'Import',
      confirmColor: kGreen,
      icon: Icons.file_download_outlined,
    );
    if (!confirmed) return;

    // Try default path first
    final success = await _storage.importConfig();
    if (success) {
      setState(() {
        _config = _storage.loadConfig();
        _loadFromConfig();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Config imported from default path'), backgroundColor: kGreen));
      }
      return;
    }

    // Let user pick a file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      final ok = await _storage.importConfigFromFile(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Config imported successfully' : 'Import failed'),
            backgroundColor: ok ? kGreen : kRed));
        if (ok) {
          setState(() {
            _config = _storage.loadConfig();
            _loadFromConfig();
          });
        }
      }
    }
  }

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
                _TierDefsTab(rows: _tierDefs, onChanged: () => setState(() {})),
                _AssignTab(rows: _assigns, tierDefs: _currentTierDefs, onChanged: () => setState(() {})),
                _NamesTab(rows: _names, onChanged: () => setState(() {})),
              ],
            ),
          ),
          // Import/Export footer
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kSlate200)),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importConfig,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Import Config'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportConfig,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Export Config'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export → ${_storage.configExportPath}',
                    style: const TextStyle(fontSize: 10, color: kSlate500, fontFamily: 'monospace')),
                Text('CSV folder → ${_storage.csvDir}',
                    style: const TextStyle(fontSize: 10, color: kSlate500, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tier Definitions Tab ─────────────────────────────────────────────────────

class _TierDefRow {
  final TextEditingController name;
  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController price;
  _TierDefRow({required this.name, required this.min, required this.max, required this.price});
}

class _TierDefsTab extends StatelessWidget {
  final List<_TierDefRow> rows;
  final VoidCallback onChanged;
  const _TierDefsTab({required this.rows, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final tierName = rows[index].name.text.trim();
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Delete Tier',
      message: tierName.isNotEmpty
          ? 'Delete tier "$tierName"? This cannot be undone.'
          : 'Delete this tier? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: kRed,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      rows.removeAt(index);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rows[i].name,
                            decoration: const InputDecoration(labelText: 'Tier Name', hintText: 'Standard'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: kRed),
                          onPressed: () => _confirmDelete(context, i),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: rows[i].min,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min OK'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: rows[i].max,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max OK'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: rows[i].price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: '৳ / OK'))),
                      ],
                    ),
                  ],
                ),
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
                rows.add(_TierDefRow(
                  name: TextEditingController(),
                  min: TextEditingController(),
                  max: TextEditingController(),
                  price: TextEditingController(),
                ));
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Tier'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Assignment Tab ────────────────────────────────────────────────────────────

class _AssignRow {
  final TextEditingController userId;
  String tierName;
  _AssignRow({required this.userId, required this.tierName});
}

class _AssignTab extends StatelessWidget {
  final List<_AssignRow> rows;
  final List<TierDefinition> tierDefs;
  final VoidCallback onChanged;
  const _AssignTab({required this.rows, required this.tierDefs, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final userId = rows[index].userId.text.trim();
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Remove Assignment',
      message: userId.isNotEmpty
          ? 'Remove tier assignment for user "$userId"?'
          : 'Remove this user assignment?',
      confirmLabel: 'Remove',
      confirmColor: kRed,
      icon: Icons.person_remove_outlined,
    );
    if (confirmed) {
      rows.removeAt(index);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rows[i].userId,
                        decoration: const InputDecoration(labelText: 'User ID'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: tierDefs.any((d) => d.name == rows[i].tierName) ? rows[i].tierName : null,
                        decoration: const InputDecoration(labelText: 'Tier'),
                        items: tierDefs.map((d) => DropdownMenuItem(
                          value: d.name,
                          child: Text('${d.name} (${d.minOk}–${d.maxOk} @ ৳${d.pricePerOk})',
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        )).toList(),
                        onChanged: (v) { if (v != null) { rows[i].tierName = v; onChanged(); } },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      onPressed: () => _confirmDelete(context, i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: tierDefs.isEmpty ? null : () {
                rows.add(_AssignRow(userId: TextEditingController(), tierName: tierDefs.first.name));
                onChanged();
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Assign User'),
            ),
          ),
        ),
      ],
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
  final VoidCallback onChanged;
  const _NamesTab({required this.rows, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final userId = rows[index].userId.text.trim();
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Delete Name',
      message: userId.isNotEmpty
          ? 'Delete custom name for user "$userId"?'
          : 'Delete this custom name entry?',
      confirmLabel: 'Delete',
      confirmColor: kRed,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      rows.removeAt(index);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: rows[i].userId,
                        decoration: const InputDecoration(labelText: 'User ID'),
                        style: const TextStyle(fontFamily: 'monospace'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: rows[i].name,
                        decoration: const InputDecoration(labelText: 'Display Name'))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      onPressed: () => _confirmDelete(context, i),
                    ),
                  ],
                ),
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
                rows.add(_NameRow(userId: TextEditingController(), name: TextEditingController()));
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Name'),
            ),
          ),
        ),
      ],
    );
  }
}
