import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/diagnostics.dart';

/// Diagnostics / Logs: the persistent diagnostic log, newest first.
/// View it, copy it, share/export it as a text file, or clear it.
/// This is what lets a blank screen (or any bug) be diagnosed from
/// the device itself, without guessing.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await MossLog().load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _copy() async {
    final text = await MossLog().exportText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log copied to clipboard.')),
      );
    }
  }

  Future<void> _share() async {
    try {
      final text = await MossLog().exportText();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/moss-log.txt');
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, name: 'moss-log.txt')]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export log: $e')),
        );
      }
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear log?'),
        content: const Text(
          'This deletes all diagnostic log entries. '
          'Export a copy first if you need them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await MossLog().clear();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Newest first.
    final entries = MossLog().entries.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics & logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy log',
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share / export log',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear log',
            onPressed: _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No log entries yet.\nThe log records app start, '
                      'photo permission results, library loads and '
                      'errors, and duplicate scans.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText(
                        e.line,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: e.level == 'error'
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
