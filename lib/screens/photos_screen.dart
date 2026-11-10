import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';
import 'viewer_screen.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  double _scaleBase = 3;
  bool _sizesStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sizes scan runs in the background — never blocks first paint.
    if (!_sizesStarted) {
      _sizesStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<GalleryProvider>().ensureSizes();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (!gallery.hasPermission) {
      return _PermissionPrompt(onAllow: () => gallery.requestPermission());
    }

    if (gallery.loading && gallery.assets.isEmpty) {
      // Skeleton placeholders instead of a full-screen spinner.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Moss',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, _) => const SkeletonTile(),
            ),
          ),
        ],
      );
    }

    if (gallery.assets.isEmpty) {
      return const Center(
        child: Text('No photos or videos found on this device.'),
      );
    }

    final items = gallery.filteredAssets;
    final selecting = gallery.selected.isNotEmpty;
    final view = gallery.photosView;

    return GestureDetector(
      onScaleStart: (_) {
        _scaleBase = gallery.columns.toDouble();
      },
      onScaleUpdate: (details) {
        if (details.scale == 1) return;
        final next = (_scaleBase / details.scale).round().clamp(2, 6);
        if (next != gallery.columns) gallery.setColumns(next);
      },
      child: CustomScrollView(
        slivers: [
          _HeaderBar(
            onSort: () => _showSortMenu(context, gallery),
            onFilter: () => _showFilterSheet(context, gallery),
          ),
          // Filter chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  for (final c in MossFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c.label),
                        selected: gallery.chip == c,
                        onSelected: (_) => gallery.setChip(c),
                        selectedColor: scheme.secondaryContainer,
                        checkmarkColor: scheme.onSecondaryContainer,
                      ),
                    ),
                  if (gallery.hasActiveFilters)
                    TextButton(
                      onPressed: gallery.clearFilters,
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
          ),
          // Active month / size filter summary
          if (gallery.filterYear != null || gallery.minSizeBytes != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (gallery.filterYear != null)
                      Chip(
                        label: Text(
                          gallery.filterDay != null
                              ? GalleryProvider.formatDate(
                                  DateTime(
                                    gallery.filterYear!,
                                    gallery.filterMonth!,
                                    gallery.filterDay!,
                                  ),
                                )
                              : GalleryProvider.formatMonthYear(
                                  gallery.filterYear!,
                                  gallery.filterMonth ?? 1,
                                ),
                        ),
                        onDeleted: () => gallery.setMonthFilter(null, null),
                      ),
                    if (gallery.minSizeBytes != null)
                      Chip(
                        label: Text(
                          'Larger than ${GalleryProvider.formatBytes(gallery.minSizeBytes!)}',
                        ),
                        onDeleted: () => gallery.setMinSize(null),
                      ),
                  ],
                ),
              ),
            ),
          // Memories banner
          if (gallery.memories.isNotEmpty && !selecting)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Card(
                  color: scheme.secondaryContainer,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _openMemories(context, gallery),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'On this day: ${gallery.memories.length} photos from past years',
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.play_circle_fill,
                            color: scheme.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Selection action bar
          if (selecting)
            const SliverToBoxAdapter(child: SelectionActionBar()),
          // Timeline grid / list
          if (items.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Nothing matches these filters.')),
            )
          else
            _TimelineSlivers(
              items: items,
              view: view,
              columns: gallery.columns,
              onOpen: (index) => _openViewer(context, items, index),
            ),
          // Room for the floating nav dock.
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    List<AssetEntity> items,
    int index,
  ) {
    pushMoss(
      context,
      ViewerScreen(items: items, initialIndex: index),
    );
  }

  void _openMemories(BuildContext context, GalleryProvider gallery) {
    pushMoss(
      context,
      ViewerScreen(
        items: gallery.memories,
        initialIndex: 0,
        title: 'On this day',
        slideshow: true,
      ),
    );
  }

  void _showSortMenu(BuildContext context, GalleryProvider gallery) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final s in SortMode.values)
              ListTile(
                leading: Icon(
                  gallery.sort == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(s.label),
                onTap: () {
                  gallery.setSort(s);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, GalleryProvider gallery) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Month',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Any month'),
                    onPressed: () {
                      gallery.setMonthFilter(null, null);
                      Navigator.of(ctx).pop();
                    },
                  ),
                  for (final m in gallery.availableMonths.take(12))
                    ActionChip(
                      label: Text(
                        GalleryProvider.formatMonthYear(m.$1, m.$2),
                      ),
                      onPressed: () {
                        gallery.setMonthFilter(m.$1, m.$2);
                        Navigator.of(ctx).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Size',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Any size'),
                    onPressed: () {
                      gallery.setMinSize(null);
                      Navigator.of(ctx).pop();
                    },
                  ),
                  ActionChip(
                    label: const Text('Larger than 5 MB'),
                    onPressed: () {
                      gallery.setMinSize(5 * 1024 * 1024);
                      Navigator.of(ctx).pop();
                    },
                  ),
                  ActionChip(
                    label: const Text('Larger than 20 MB'),
                    onPressed: () {
                      gallery.setMinSize(20 * 1024 * 1024);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pull-down expandable header: logo, app name, photo/video counts,
/// total storage used, and a Memories teaser. Pulling down at the top
/// expands it; scrolling up collapses it.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onSort, required this.onFilter});

  final VoidCallback onSort;
  final VoidCallback onFilter;

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

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      floating: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onPressed: onSort,
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter by date / size',
          onPressed: onFilter,
        ),
        _ViewToggle(),
        const ThemeModeButton(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.55),
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const MossLogo(size: 52),
                      const SizedBox(width: 12),
                      Text(
                        'Moss',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$photos photos · $videos videos',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gallery.sizesComplete
                        ? '${GalleryProvider.formatBytes(gallery.totalKnownBytes)} on this device'
                        : 'Scanning sizes… ${GalleryProvider.formatBytes(gallery.totalKnownBytes)} so far',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (gallery.loadingMore) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: gallery.loadProgress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  if (gallery.memories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Memories: ${gallery.memories.length} photos from this day in past years — tap the banner below to relive them.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid / compact grid / list toggle (Photos view, persisted).
class _ViewToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    return PopupMenuButton<MossView>(
      icon: Icon(
        switch (gallery.photosView) {
          MossView.grid => Icons.grid_view,
          MossView.compact => Icons.view_comfy,
          MossView.list => Icons.view_list,
        },
      ),
      tooltip: 'View: ${gallery.photosView.label}',
      onSelected: (v) => gallery.setPhotosView(v),
      itemBuilder: (_) => [
        for (final v in MossView.values)
          PopupMenuItem(
            value: v,
            child: Row(
              children: [
                Icon(
                  gallery.photosView == v
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
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MossLogo(size: 72),
            const SizedBox(height: 16),
            const Text(
              'Moss needs access to your photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your photos stay on your phone. Moss is fully offline — '
              'nothing is uploaded anywhere.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAllow,
              child: const Text('Allow photo access'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timeline grouped by day, with date headers. In grid view the first
/// photo of each day is a wide tile spanning 2 columns; compact grid uses
/// more columns with a smaller radius; list view shows rows.
class _TimelineSlivers extends StatelessWidget {
  const _TimelineSlivers({
    required this.items,
    required this.view,
    required this.columns,
    required this.onOpen,
  });

  final List<AssetEntity> items;
  final MossView view;
  final int columns;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    // Group by day, keeping the overall order.
    final groups = <String, List<(int, AssetEntity)>>{};
    final order = <String>[];
    for (var i = 0; i < items.length; i++) {
      final d = items[i].createDateTime;
      final key = '${d.year}-${d.month}-${d.day}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add((i, items[i]));
    }

    return SliverMainAxisGroup(
      slivers: [
        for (final key in order) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _headerFor(groups[key]!.first.$2),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          switch (view) {
            MossView.list => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final entry = groups[key]![i];
                    final asset = entry.$2;
                    final selected =
                        gallery.selected.contains(asset.id);
                    return AssetListRow(
                      asset: asset,
                      selected: selected,
                      onTap: () => _tap(context, gallery, asset, entry.$1),
                      onLongPress: () =>
                          _longPress(context, gallery, asset),
                    );
                  },
                  childCount: groups[key]!.length,
                ),
              ),
            MossView.compact => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final entry = groups[key]![i];
                      final asset = entry.$2;
                      return AssetThumb(
                        asset: asset,
                        size: 80,
                        borderRadius: 12,
                        selected: gallery.selected.contains(asset.id),
                        isFavourite: gallery.isFavourite(asset.id),
                        onTap: () => _tap(context, gallery, asset, entry.$1),
                        onLongPress: () =>
                            _longPress(context, gallery, asset),
                      );
                    },
                    childCount: groups[key]!.length,
                  ),
                ),
              ),
            MossView.grid => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverQuiltedGridDelegate(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    pattern: _quiltPattern(groups[key]!.length),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final entry = groups[key]![i];
                      final asset = entry.$2;
                      return AssetThumb(
                        asset: asset,
                        size: 100,
                        borderRadius: 18,
                        selected: gallery.selected.contains(asset.id),
                        isFavourite: gallery.isFavourite(asset.id),
                        onTap: () =>
                            _tap(context, gallery, asset, entry.$1),
                        onLongPress: () =>
                            _longPress(context, gallery, asset),
                      );
                    },
                    childCount: groups[key]!.length,
                  ),
                ),
              ),
          },
        ],
      ],
    );
  }

  /// First tile of the day spans 2 columns; the rest are square.
  /// The pattern is exactly as long as the group, so it never repeats
  /// a wide tile mid-group.
  List<QuiltedGridTile> _quiltPattern(int count) {
    if (count <= 1) return [const QuiltedGridTile(1, 1)];
    return [
      const QuiltedGridTile(2, 1),
      for (var i = 1; i < count; i++) const QuiltedGridTile(1, 1),
    ];
  }

  void _tap(
    BuildContext context,
    GalleryProvider gallery,
    AssetEntity asset,
    int index,
  ) {
    if (gallery.selected.isNotEmpty) {
      gallery.toggleSelect(asset.id);
    } else {
      onOpen(index);
    }
  }

  /// Long-press enters selection mode (tap toggles after that).
  void _longPress(
    BuildContext context,
    GalleryProvider gallery,
    AssetEntity asset,
  ) {
    gallery.toggleSelect(asset.id);
  }

  String _headerFor(AssetEntity a) {
    final d = a.createDateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final date = GalleryProvider.formatDate(d);
    if (diff == 0) return 'Today · $date';
    if (diff == 1) return 'Yesterday · $date';
    return date;
  }
}
