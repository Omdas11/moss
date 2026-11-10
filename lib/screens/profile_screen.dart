import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../providers/theme_provider.dart';
import '../services/diagnostics.dart';
import '../theme.dart';
import '../widgets.dart';
import 'logs_screen.dart';

/// Profile tab: Moss logo + version, theme picker (6 themes + mode),
/// and a storage breakdown. Fully offline.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _sizesStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sizesStarted) {
      _sizesStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final gallery = context.read<GalleryProvider>();
        gallery.ensureSizes();
        gallery.refreshFreeSpace();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    final photos = gallery.assets
        .where((a) => a.type == AssetType.image)
        .length;
    final videos = gallery.assets
        .where((a) => a.type == AssetType.video)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [ThemeModeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          // Identity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const MossLogo(size: 64),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moss',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Version $kMossVersion',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Local gallery — no account, no cloud.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Theme', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Theme picker: grid of swatches with names.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: MossThemes.all.length,
            itemBuilder: (ctx, i) {
              final def = MossThemes.all[i];
              final selected = themeProvider.themeId == def.id;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => themeProvider.setTheme(def.id),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: selected ? 2.5 : 1,
                    ),
                    color: scheme.surfaceContainerLow,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Swatch(color: def.swatchLight),
                          const SizedBox(width: 4),
                          _Swatch(color: def.swatchDark),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        def.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Mode: System / Light / Dark / AMOLED.
          SegmentedButton<MossThemeMode>(
            segments: [
              for (final m in MossThemeMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label, style: const TextStyle(fontSize: 12)),
                ),
            ],
            selected: {themeProvider.mode},
            onSelectionChanged: (s) => themeProvider.setMode(s.first),
          ),
          const SizedBox(height: 24),
          Text('Storage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          gallery.sizesComplete
                              ? '${GalleryProvider.formatBytes(gallery.totalKnownBytes)} '
                                  'in $photos photos & $videos videos'
                              : 'Scanning sizes… '
                                  '${GalleryProvider.formatBytes(gallery.totalKnownBytes)} '
                                  'so far (${gallery.sizes.length}/${gallery.assets.length} files)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!gallery.sizesComplete)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Segmented bar: photos vs videos (a true partition).
                  _SegmentedBar(
                    segments: [
                      (
                        gallery.photosBytes,
                        scheme.primary,
                        'Photos',
                      ),
                      (
                        gallery.videosBytes,
                        scheme.tertiary,
                        'Videos',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    label: 'Photos',
                    bytes: gallery.photosBytes,
                    total: gallery.totalKnownBytes,
                    color: scheme.primary,
                  ),
                  _BreakdownRow(
                    label: 'Videos',
                    bytes: gallery.videosBytes,
                    total: gallery.totalKnownBytes,
                    color: scheme.tertiary,
                  ),
                  _BreakdownRow(
                    label: 'Screenshots (included in Photos)',
                    bytes: gallery.screenshotsBytes,
                    total: gallery.totalKnownBytes,
                    color: scheme.secondary,
                  ),
                  _BreakdownRow(
                    label: 'Downloads (included in Photos)',
                    bytes: gallery.downloadsBytes,
                    total: gallery.totalKnownBytes,
                    color: scheme.secondary,
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Biggest folders',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (gallery.biggestFolders.isEmpty)
                    const Text(
                      'Sizes still scanning — check back in a moment.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    for (final f in gallery.biggestFolders)
                      _BreakdownRow(
                        label: f.$1,
                        bytes: f.$2,
                        total: gallery.totalKnownBytes,
                        color: scheme.primary,
                      ),
                  const Divider(height: 24),
                  _InfoRow(
                    label: 'Duplicate waste',
                    value: gallery.scanDone
                        ? GalleryProvider.formatBytes(
                            gallery.duplicateWasteBytes,
                          )
                        : 'Run the Duplicates scan to see this',
                  ),
                  _InfoRow(
                    label: 'Trash',
                    value:
                        '${GalleryProvider.formatBytes(gallery.trashBytes)} '
                        '(${gallery.trash.length} items, 30 days)',
                  ),
                  if (gallery.freeSpaceChecked &&
                      gallery.freeSpaceBytes != null)
                    _InfoRow(
                      label: 'Free space on device',
                      value: GalleryProvider.formatBytes(
                        gallery.freeSpaceBytes!,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Library', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _InfoRow(label: 'Photos', value: '$photos'),
                _InfoRow(label: 'Videos', value: '$videos'),
                _InfoRow(
                  label: 'Favourites',
                  value: '${gallery.favourites.length}',
                ),
                _InfoRow(
                  label: 'Locked items',
                  value: '${gallery.locked.length}',
                ),
                _InfoRow(
                  label: 'Trash items',
                  value: '${gallery.trash.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Diagnostics: the persistent log — view, copy, share, clear.
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnostics & logs'),
              subtitle: const Text(
                'App log — helpful when reporting a bug',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushMoss(context, const LogsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Moss is fully offline — no account, no cloud, no uploads.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

/// Segmented bar: one segment per (bytes, colour); widths by share.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.segments});

  final List<(int, Color, String)> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (p, e) => p + e.$1);
    final scheme = Theme.of(context).colorScheme;
    if (total <= 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          for (final s in segments)
            if (s.$1 > 0)
              Expanded(
                flex: s.$1,
                child: Container(height: 12, color: s.$2),
              ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.bytes,
    required this.total,
    required this.color,
  });

  final String label;
  final int bytes;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (bytes / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      GalleryProvider.formatBytes(bytes),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? bytes / total : 0,
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
