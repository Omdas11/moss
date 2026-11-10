import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';
import 'collage_screen.dart';
import 'duplicates_screen.dart';
import 'locked_screen.dart';
import 'trash_screen.dart';
import 'viewer_screen.dart';

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key, required this.onGoToPhotos});

  final VoidCallback onGoToPhotos;

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final photos = gallery.assets
        .where((a) => a.type == AssetType.image)
        .length;
    final videos = gallery.assets
        .where((a) => a.type == AssetType.video)
        .length;
    final screenshots = gallery.assets
        .where((a) =>
            (a.relativePath ?? '').toLowerCase().contains('screenshot') ||
            (a.title ?? '').toLowerCase().contains('screenshot'))
        .length;

    // Folders with counts.
    final folderCounts = <String, int>{};
    for (final a in gallery.assets) {
      final f = gallery.folderOf(a);
      folderCounts[f] = (folderCounts[f] ?? 0) + 1;
    }
    final folders = folderCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Months with counts.
    final monthCounts = <(int, int), int>{};
    for (final a in gallery.assets) {
      final k = (a.createDateTime.year, a.createDateTime.month);
      monthCounts[k] = (monthCounts[k] ?? 0) + 1;
    }
    final months = monthCounts.entries.toList()
      ..sort((a, b) => b.key.$1 != a.key.$1
          ? b.key.$1.compareTo(a.key.$1)
          : b.key.$2.compareTo(a.key.$2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: const [ThemeModeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
        Text(
          'Smart albums',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _AlbumTile(
              icon: Icons.photo,
              label: 'All photos',
              count: photos,
              onTap: () {
                gallery.setChip(MossFilter.photos);
                onGoToPhotos();
              },
            ),
            _AlbumTile(
              icon: Icons.videocam,
              label: 'Videos',
              count: videos,
              onTap: () {
                gallery.setChip(MossFilter.videos);
                onGoToPhotos();
              },
            ),
            _AlbumTile(
              icon: Icons.screenshot_monitor,
              label: 'Screenshots',
              count: screenshots,
              onTap: () {
                gallery.setChip(MossFilter.screenshots);
                onGoToPhotos();
              },
            ),
            _AlbumTile(
              icon: Icons.favorite,
              label: 'Favourites',
              count: gallery.favourites.length,
              onTap: () {
                gallery.setChip(MossFilter.favourites);
                onGoToPhotos();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'By month',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final e in months.take(6))
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(
              GalleryProvider.formatMonthYear(e.key.$1, e.key.$2),
            ),
            trailing: Text('${e.value} items'),
            onTap: () {
              gallery.setMonthFilter(e.key.$1, e.key.$2);
              onGoToPhotos();
            },
          ),
        const SizedBox(height: 24),
        Text(
          'Folders',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final e in folders.take(12))
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(e.key),
            trailing: Text('${e.value} items'),
            onTap: () {
              // Folder filter: show the folder's items in the folder view.
              pushMoss(
                context,
                _FolderView(folder: e.key),
              );
            },
          ),
        const SizedBox(height: 24),
        Text(
          'Tools',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        StatCard(
          icon: Icons.copy_all,
          title: 'Duplicates & similar',
          subtitle: gallery.scanDone
              ? '${gallery.duplicateGroups.length} duplicate groups · '
                  '${gallery.similarIds.length} similar · '
                  '${gallery.blurryIds.length} possibly blurry'
              : 'Find exact duplicates, similar and blurry photos',
          onTap: () => pushMoss(context, const DuplicatesScreen()),
        ),
        const SizedBox(height: 8),
        StatCard(
          icon: Icons.storage,
          title: 'Storage',
          subtitle: gallery.sizesComplete
              ? '${GalleryProvider.formatBytes(gallery.totalKnownBytes)} '
                  'in photos & videos'
              : 'Tap to scan sizes — ${GalleryProvider.formatBytes(gallery.totalKnownBytes)} found so far',
          onTap: () => _showStorage(context, gallery),
        ),
        const SizedBox(height: 8),
        StatCard(
          icon: Icons.delete,
          title: 'Trash',
          subtitle: gallery.trash.isEmpty
              ? 'Empty — deleted photos stay here 30 days'
              : '${gallery.trash.length} items — oldest deleted first',
          onTap: () => pushMoss(context, const TrashScreen()),
        ),
        const SizedBox(height: 8),
        StatCard(
          icon: Icons.lock,
          title: 'Locked folder',
          subtitle: gallery.locked.isEmpty
              ? 'PIN-protected — hidden from the main grid'
              : '${gallery.locked.length} items locked',
          onTap: () => pushMoss(context, const LockedScreen()),
        ),
        const SizedBox(height: 8),
        StatCard(
          icon: Icons.grid_view,
          title: '16:9 collage maker',
          subtitle: 'Pick photos, arrange them, export one 16:9 image',
          onTap: () => pushMoss(context, const CollageScreen()),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Moss is fully offline — no account, no cloud, no uploads.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        ],
      ),
    );
  }

  void _showStorage(BuildContext context, GalleryProvider gallery) {
    gallery.ensureSizes();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) {
          return Consumer<GalleryProvider>(
            builder: (ctx, g, _) {
              final biggest = g.biggestFiles;
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Storage',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    g.sizesComplete
                        ? 'Total: ${GalleryProvider.formatBytes(g.totalKnownBytes)} '
                            'across ${g.assets.length} items'
                        : 'Scanning sizes… ${GalleryProvider.formatBytes(g.totalKnownBytes)} so far (${g.sizes.length}/${g.assets.length} files)',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Biggest files first',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final a in biggest)
                    ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: AssetEntityImageProvider(
                              a,
                              isOriginal: false,
                              thumbnailSize: ThumbnailSize.square(120),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(a.title ?? 'Photo'),
                      subtitle: Text(
                        GalleryProvider.formatBytes(g.sizes[a.id] ?? 0),
                      ),
                      onTap: () => pushMoss(
                        context,
                        ViewerScreen(
                          items: biggest,
                          initialIndex: biggest.indexOf(a),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('$count items'),
            ],
          ),
        ),
      ),
    );
  }
}

/// One device folder: grid / compact grid / list, long-press to select,
/// multi-select bar with Copy / Move / Delete / Favourite / Lock / Share.
class _FolderView extends StatelessWidget {
  const _FolderView({required this.folder});

  final String folder;

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final items = gallery.assets
        .where((a) => gallery.folderOf(a) == folder)
        .toList();
    final selecting = gallery.selected.isNotEmpty;
    final view = gallery.folderView;

    Widget gridBody() {
      switch (view) {
        case MossView.list:
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 110),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final a = items[i];
              return AssetListRow(
                asset: a,
                selected: gallery.selected.contains(a.id),
                onTap: () => _tap(context, gallery, items, i),
                onLongPress: () => gallery.toggleSelect(a.id),
              );
            },
          );
        case MossView.compact:
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final a = items[i];
              return AssetThumb(
                asset: a,
                size: 80,
                borderRadius: 12,
                selected: gallery.selected.contains(a.id),
                isFavourite: gallery.isFavourite(a.id),
                onTap: () => _tap(context, gallery, items, i),
                onLongPress: () => gallery.toggleSelect(a.id),
              );
            },
          );
        case MossView.grid:
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final a = items[i];
              return AssetThumb(
                asset: a,
                size: 100,
                borderRadius: 18,
                selected: gallery.selected.contains(a.id),
                isFavourite: gallery.isFavourite(a.id),
                onTap: () => _tap(context, gallery, items, i),
                onLongPress: () => gallery.toggleSelect(a.id),
              );
            },
          );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(folder),
        actions: [
          PopupMenuButton<MossView>(
            icon: Icon(
              switch (view) {
                MossView.grid => Icons.grid_view,
                MossView.compact => Icons.view_comfy,
                MossView.list => Icons.view_list,
              },
            ),
            tooltip: 'View: ${view.label}',
            onSelected: (v) => gallery.setFolderView(v),
            itemBuilder: (_) => [
              for (final v in MossView.values)
                PopupMenuItem(
                  value: v,
                  child: Row(
                    children: [
                      Icon(
                        view == v
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(v.label),
                    ],
                  ),
                ),
            ],
          ),
          const ThemeModeButton(),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No items in this folder.'))
          : Column(
              children: [
                if (selecting) const SelectionActionBar(),
                Expanded(child: gridBody()),
              ],
            ),
    );
  }

  void _tap(
    BuildContext context,
    GalleryProvider gallery,
    List<AssetEntity> items,
    int i,
  ) {
    final a = items[i];
    if (gallery.selected.isNotEmpty) {
      gallery.toggleSelect(a.id);
    } else {
      pushMoss(
        context,
        ViewerScreen(items: items, initialIndex: i),
      );
    }
  }
}
