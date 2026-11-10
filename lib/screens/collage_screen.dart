import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';

/// 16:9 collage maker: pick 2–6 photos, choose a layout, export one 16:9
/// image to the gallery. Fully offline.
class CollageScreen extends StatefulWidget {
  const CollageScreen({super.key});

  @override
  State<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends State<CollageScreen> {
  final _picked = <AssetEntity>[];
  final _files = <String, File>{};
  int _layout = 0; // 0 = 2 across, 1 = 1 big + 2 stacked, 2 = 2x2, 3 = 3x2
  final _boundaryKey = GlobalKey();
  bool _exporting = false;

  static const _layouts = ['2 photos', '3 photos', '4 photos', '6 photos'];

  Future<File?> _fileFor(AssetEntity a) async {
    if (_files.containsKey(a.id)) return _files[a.id];
    try {
      final f = await a.loadFile();
      if (f != null) _files[a.id] = f;
      return f;
    } catch (_) {
      return null;
    }
  }

  Future<void> _export() async {
    if (_picked.length < 2) return;
    setState(() => _exporting = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;
      await PhotoManager.editor.saveImage(
        bytes,
        filename: 'moss_collage_${DateTime.now().millisecondsSinceEpoch}.png',
        title: 'moss_collage',
        relativePath: 'Pictures/Moss',
      );
      if (!mounted) return;
      final gallery = context.read<GalleryProvider>();
      await gallery.loadLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collage saved to gallery.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export collage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final photos = gallery.assets
        .where((a) => a.type == AssetType.image)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('16:9 collage maker'),
        actions: [
          TextButton(
            onPressed: _picked.length >= 2 && !_exporting ? _export : null,
            child: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Export'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 16:9 preview canvas
          Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.black,
                  child: _picked.isEmpty
                      ? const Center(
                          child: Text(
                            'Pick 2–6 photos below',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : _buildLayout(),
                ),
              ),
            ),
          ),
          // Layout picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < _layouts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_layouts[i]),
                      selected: _layout == i,
                      onSelected: (_) => setState(() => _layout = i),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${_picked.length} picked (2–6)'),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) {
                final a = photos[i];
                final picked = _picked.contains(a);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AssetThumb(
                      asset: a,
                      size: 80,
                      selected: picked,
                      onTap: () async {
                        setState(() {
                          if (picked) {
                            _picked.remove(a);
                          } else if (_picked.length < 6) {
                            _picked.add(a);
                          }
                        });
                        await _fileFor(a);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayout() {
    final tiles = _picked.map((a) {
      final f = _files[a.id];
      if (f == null) {
        return Container(color: Colors.grey.shade800);
      }
      return Image.file(f, fit: BoxFit.cover);
    }).toList();

    Widget row(List<Widget> children) => Row(
          children: children
              .map((w) => Expanded(child: w))
              .toList(),
        );

    switch (_layout) {
      case 1: // 1 big + 2 stacked
        if (tiles.length < 3) return row(tiles);
        return Row(
          children: [
            Expanded(flex: 2, child: tiles[0]),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tiles[1]),
                  Expanded(child: tiles[2]),
                ],
              ),
            ),
          ],
        );
      case 2: // 2x2
        if (tiles.length < 4) return row(tiles);
        return Column(
          children: [
            Expanded(child: row(tiles.sublist(0, 2))),
            Expanded(child: row(tiles.sublist(2, 4))),
          ],
        );
      case 3: // 3x2
        if (tiles.length < 6) {
          final rows = <Widget>[];
          for (var i = 0; i < tiles.length; i += 3) {
            final end = (i + 3).clamp(0, tiles.length);
            rows.add(Expanded(child: row(tiles.sublist(i, end))));
          }
          return Column(children: rows);
        }
        return Column(
          children: [
            Expanded(child: row(tiles.sublist(0, 3))),
            Expanded(child: row(tiles.sublist(3, 6))),
          ],
        );
      case 0:
      default: // side by side
        return row(tiles);
    }
  }
}
