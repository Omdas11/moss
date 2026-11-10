import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (gallery.trash.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Empty trash?'),
                    content: const Text(
                      'All items in trash will be permanently deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Empty trash'),
                      ),
                    ],
                  ),
                );
                if (ok == true) gallery.emptyTrash();
              },
              child: const Text('Empty'),
            ),
        ],
      ),
      body: gallery.trash.isEmpty
          ? const Center(
              child: Text(
                'Trash is empty.\nDeleted photos stay here for 30 days.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text(
                  'Items are permanently deleted 30 days after they were trashed.',
                ),
                const SizedBox(height: 12),
                for (final item in gallery.trash)
                  Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(item.filePath),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        '${GalleryProvider.formatBytes(item.size)} · '
                        '${item.daysLeft} days left',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore),
                            tooltip: 'Restore',
                            onPressed: () async {
                              final ok =
                                  await gallery.restoreFromTrash(item);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Restored to gallery.'
                                          : 'Could not restore.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever),
                            tooltip: 'Delete forever',
                            onPressed: () =>
                                gallery.deleteTrashItemPermanently(item),
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
