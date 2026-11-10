import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../services/diagnostics.dart';
import '../services/notifications.dart';

/// Light edit only: rotate, straighten, centre-crop to a preset ratio.
/// Natural look — no filters, no AI, no saturation changes. The result is
/// saved as a NEW copy in the gallery; the original is never touched.
class EditScreen extends StatefulWidget {
  const EditScreen({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  int _quarterTurns = 0; // 0..3, each = 90° clockwise
  double _straighten = 0; // -45..45 degrees
  String _crop = 'Original';

  static const _crops = ['Original', '1:1', '4:3', '16:9', '3:2'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await widget.asset.loadFile();
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _bytes = bytes);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_bytes == null) return;
    final decoded = img.decodeImage(_bytes!);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read this photo.')),
        );
      }
      return;
    }
    var out = decoded;
    // Straighten first (small angle), then 90° steps, then crop.
    if (_straighten != 0) {
      out = img.copyRotate(out, angle: _straighten);
    }
    if (_quarterTurns != 0) {
      out = img.copyRotate(out, angle: _quarterTurns * 90);
    }
    if (_crop != 'Original') {
      final parts = _crop.split(':');
      final rw = double.parse(parts[0]);
      final rh = double.parse(parts[1]);
      final target = rw / rh;
      final current = out.width / out.height;
      if (current > target) {
        final w = (out.height * target).round();
        final x = ((out.width - w) / 2).round();
        out = img.copyCrop(out, x: x, y: 0, width: w, height: out.height);
      } else {
        final h = (out.width / target).round();
        final y = ((out.height - h) / 2).round();
        out = img.copyCrop(out, x: 0, y: y, width: out.width, height: h);
      }
    }
    final encoded = Uint8List.fromList(img.encodeJpg(out, quality: 92));
    final name = widget.asset.title ?? 'photo.jpg';
    final base = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    try {
      await PhotoManager.editor.saveImage(
        encoded,
        filename: 'moss_edit_$base.jpg',
        title: 'moss_edit_$base',
        relativePath: 'Pictures/Moss',
      );
      if (!mounted) return;
      final gallery = context.read<GalleryProvider>();
      await gallery.loadLibrary();
      MossLog().log('export', 'Edited copy saved: moss_edit_$base.jpg');
      unawaited(MossNotifications().showExportSaved('Edited photo'));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the edited copy.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit photo'),
        actions: [
          TextButton(
            onPressed: _bytes == null ? null : _save,
            child: const Text('Save copy'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bytes == null
              ? const Center(child: Text('Could not load this photo.'))
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Transform.rotate(
                          angle: (_quarterTurns * 90 + _straighten) *
                              3.141592653589793 /
                              180,
                          child: Image.memory(_bytes!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Light edit only — crop, straighten, rotate. '
                        'Saved as a new copy; the original stays untouched.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Crop presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          for (final c in _crops)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: _crop == c,
                                onSelected: (_) =>
                                    setState(() => _crop = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Straighten slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten),
                          Expanded(
                            child: Slider(
                              value: _straighten,
                              min: -45,
                              max: 45,
                              divisions: 90,
                              label: '${_straighten.round()}°',
                              onChanged: (v) =>
                                  setState(() => _straighten = v),
                            ),
                          ),
                          Text('${_straighten.round()}°'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => setState(
                              () => _quarterTurns =
                                  (_quarterTurns + 1) % 4,
                            ),
                            icon: const Icon(Icons.rotate_right),
                            label: const Text('Rotate 90°'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => setState(() {
                              _quarterTurns = 0;
                              _straighten = 0;
                              _crop = 'Original';
                            }),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
