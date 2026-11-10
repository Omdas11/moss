import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';
import 'viewer_screen.dart';

/// Duplicates finder. Exact duplicates are SHA-256 matches on the file
/// bytes. "Similar" means same dimensions with a file size within 15%.
/// "Possibly blurry" is a heuristic (very few bytes per pixel) and is
/// labelled as such — it is not a certainty. Nothing is deleted here
/// without the user choosing it.
class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicates & similar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exact duplicates are matched by file hash. Similar photos share '
              'the same dimensions and a near-identical size. Blurry is a '
              'heuristic — small file for its resolution — and may be wrong. '
              'Moss never deletes anything on its own.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: gallery.scanning
                  ? FilledButton.icon(
                      onPressed: gallery.stopScan,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop scan'),
                    )
                  : FilledButton.icon(
                      onPressed: gallery.scanDuplicates,
                      icon: const Icon(Icons.search),
                      label: const Text('Scan now'),
                    ),
            ),
            if (gallery.scanning) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: gallery.scanProgress),
              const SizedBox(height: 8),
              Text(gallery.scanStatus),
            ] else if (gallery.scanDone) ...[
              const SizedBox(height: 16),
              Text(
                gallery.scanStatus,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (gallery.duplicateGroups.isNotEmpty) ...[
                    const Text(
                      'Exact duplicates',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    for (final group in gallery.duplicateGroups)
                      _DuplicateGroup(
                        ids: group,
                        onDeleteExtras: () =>
                            _deleteExtras(context, gallery, group),
                      ),
                  ],
                  if (gallery.similarIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Similar (same size & dimensions)',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    _IdGrid(ids: gallery.similarIds.toList()),
                  ],
                  if (gallery.blurryIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Possibly blurry (heuristic — check before deleting)',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    _IdGrid(ids: gallery.blurryIds.toList()),
                  ],
                  if (gallery.scanDone &&
                      gallery.duplicateGroups.isEmpty &&
                      gallery.similarIds.isEmpty &&
                      gallery.blurryIds.isEmpty)
                    const Text('No duplicates, similar or blurry photos found.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExtras(
    BuildContext context,
    GalleryProvider gallery,
    List<String> group,
  ) async {
    // Keep the first (newest is first in the list order), delete the rest.
    final extras = group
        .skip(1)
        .map(gallery.byId)
        .whereType<AssetEntity>()
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete extra copies?'),
        content: Text(
          'Keep 1 copy and permanently delete ${extras.length} '
          'identical copies? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final count = await gallery.deletePermanently(extras);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $count duplicate copies.')),
      );
    }
  }
}

class _DuplicateGroup extends StatelessWidget {
  const _DuplicateGroup({required this.ids, required this.onDeleteExtras});

  final List<String> ids;
  final VoidCallback onDeleteExtras;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ids.length} identical copies'),
            const SizedBox(height: 8),
            _IdGrid(ids: ids),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onDeleteExtras,
              child: const Text('Keep one, delete the rest'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdGrid extends StatelessWidget {
  const _IdGrid({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final items = ids.map(gallery.byId).whereType<AssetEntity>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final a = items[i];
        return AssetThumb(
          asset: a,
          size: 80,
          onTap: () => pushMoss(
            context,
            ViewerScreen(items: items, initialIndex: i),
          ),
        );
      },
    );
  }
}
