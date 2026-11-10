import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';

/// PIN-protected locked folder. Items here are stored as files in the app's
/// private folder — they do not appear in the system gallery or in Moss's
/// main grid. Unlocking moves them back to the gallery.
class LockedScreen extends StatefulWidget {
  const LockedScreen({super.key});

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  bool _unlocked = false;
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Locked folder')),
      body: !gallery.hasPin
          ? _SetPinView(
              onSet: (pin) async {
                await gallery.setPin(pin);
                setState(() => _unlocked = true);
              },
            )
          : !_unlocked
              ? _EnterPinView(
                  error: _error,
                  onSubmit: (pin) {
                    if (gallery.verifyPin(pin)) {
                      setState(() {
                        _unlocked = true;
                        _error = null;
                      });
                    } else {
                      setState(() => _error = 'Wrong PIN. Try again.');
                    }
                  },
                )
              : gallery.locked.isEmpty
                  ? const Center(
                      child: Text(
                        'Locked folder is empty.\n'
                        'Long-press a photo and choose "Move to locked folder".',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Text(
                          'These photos are hidden from the gallery. '
                          'Unlocking moves them back.',
                        ),
                        const SizedBox(height: 12),
                        for (final item in gallery.locked)
                          Card(
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(item.filePath),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image),
                                ),
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                GalleryProvider.formatBytes(item.size),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lock_open),
                                    tooltip: 'Move back to gallery',
                                    onPressed: () async {
                                      final ok = await gallery
                                          .unlockAsset(item);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ok
                                                  ? 'Moved back to gallery.'
                                                  : 'Could not unlock.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.delete_forever),
                                    tooltip: 'Delete forever',
                                    onPressed: () => gallery
                                        .deleteLockedItemPermanently(item),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _SetPinView extends StatefulWidget {
  const _SetPinView({required this.onSet});

  final Future<void> Function(String pin) onSet;

  @override
  State<_SetPinView> createState() => _SetPinViewState();
}

class _SetPinViewState extends State<_SetPinView> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Set a 4-digit PIN for your locked folder',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'PIN (4 digits)'),
          ),
          TextField(
            controller: _confirm,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (_pin.text.length != 4) {
                setState(() => _error = 'PIN must be 4 digits.');
                return;
              }
              if (_pin.text != _confirm.text) {
                setState(() => _error = 'PINs do not match.');
                return;
              }
              await widget.onSet(_pin.text);
            },
            child: const Text('Set PIN'),
          ),
          const SizedBox(height: 12),
          const Text(
            'The PIN is stored only on this phone as a hash. '
            'If you forget it, locked photos cannot be recovered — '
            'there is no reset, because there is no account or cloud.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EnterPinView extends StatelessWidget {
  const _EnterPinView({required this.error, required this.onSubmit});

  final String? error;
  final void Function(String pin) onSubmit;

  @override
  Widget build(BuildContext context) {
    final pin = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Enter your 4-digit PIN',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'PIN'),
            onSubmitted: onSubmit,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onSubmit(pin.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}
