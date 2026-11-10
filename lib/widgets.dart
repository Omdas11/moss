import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:provider/provider.dart';

import 'providers/gallery_provider.dart';
import 'providers/theme_provider.dart';

/// Shared page transition for the whole app: fade + slight slide,
/// 280ms, easeOutCubic. Use [pushMoss] for EVERY Navigator.push.
Future<T?> pushMoss<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Moss logo — clean geometric mark: soft rounded moss mounds in emerald
/// with a small two-leaf sprout. Drawn with CustomPaint (no image asset
/// needed in-app); the launcher icon is the matching PNG in assets/.
class MossLogo extends StatelessWidget {
  const MossLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MossLogoPainter(),
    );
  }
}

class _MossLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.68;

    Paint fill(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    // Back mounds (upper half-ellipses).
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.30, groundY),
        width: w * 0.42,
        height: h * 0.34,
      ),
      math.pi,
      math.pi,
      true,
      fill(const Color(0xFF34D399)),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.72, groundY),
        width: w * 0.40,
        height: h * 0.30,
      ),
      math.pi,
      math.pi,
      true,
      fill(const Color(0xFF6EE7B7)),
    );
    // Front mound.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, groundY),
        width: w * 0.58,
        height: h * 0.46,
      ),
      math.pi,
      math.pi,
      true,
      fill(const Color(0xFF10B981)),
    );
    // Sprout: two small leaves, tilted apart.
    void leaf(double cx, double cy, double angle, Color color) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: w * 0.13,
          height: h * 0.26,
        ),
        fill(color),
      );
      canvas.restore();
    }

    leaf(w * 0.40, h * 0.30, -0.55, const Color(0xFFA7F3D0));
    leaf(w * 0.60, h * 0.30, 0.55, const Color(0xFF34D399));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A grid thumbnail. No per-photo share button (removed in v1.1): sharing
/// lives in multi-select and the viewer's overflow menu only.
/// Thumbnails fade in on load; the selection checkmark animates.
class AssetThumb extends StatelessWidget {
  const AssetThumb({
    super.key,
    required this.asset,
    required this.size,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.isFavourite = false,
    this.borderRadius = 18,
  });

  final AssetEntity asset;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isFavourite;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: scheme.surfaceContainerHighest),
            Image(
              image: AssetEntityImageProvider(
                asset,
                isOriginal: false,
                thumbnailSize: ThumbnailSize.square(300),
              ),
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: scheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image),
              ),
            ),
            if (asset.type == AssetType.video)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _duration(asset.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (isFavourite)
              const Positioned(
                left: 4,
                top: 4,
                child: Icon(Icons.favorite, size: 16, color: Colors.red),
              ),
            if (selected)
              Container(
                color: scheme.primary.withValues(alpha: 0.35),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _duration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Soft grey rounded tile shown while the first page of photos loads.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.borderRadius = 18});

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(color: scheme.surfaceContainerHighest),
    );
  }
}

/// One row of the list view: thumbnail + title + date + size.
class AssetListRow extends StatelessWidget {
  const AssetListRow({
    super.key,
    required this.asset,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final size = gallery.sizes[asset.id];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Image(
              image: AssetEntityImageProvider(
                asset,
                isOriginal: false,
                thumbnailSize: ThumbnailSize.square(160),
              ),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: scheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
        title: Text(
          asset.title ?? 'Photo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${GalleryProvider.formatDate(asset.createDateTime)}'
          '${size != null ? ' · ${GalleryProvider.formatBytes(size)}' : ''}'
          '${asset.type == AssetType.video ? ' · video' : ''}',
        ),
        trailing: AnimatedScale(
          scale: selected ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primary,
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Multi-select action bar shared by Photos, folder views and Search.
/// Offers Copy, Move, Delete (to Trash), Favourite, Lock, Share.
/// Copy/Move open a destination picker (existing folders + new folder).
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final count = gallery.selected.length;
    return Container(
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Clear selection',
            onPressed: gallery.clearSelection,
          ),
          Text(
            '$count selected',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Action(
                    icon: Icons.copy,
                    label: 'Copy',
                    onTap: () => _copyMove(context, gallery, move: false),
                  ),
                  _Action(
                    icon: Icons.drive_file_move,
                    label: 'Move',
                    onTap: () => _copyMove(context, gallery, move: true),
                  ),
                  _Action(
                    icon: Icons.delete,
                    label: 'Delete',
                    onTap: () => _trashSelection(context, gallery),
                  ),
                  _Action(
                    icon: Icons.favorite,
                    label: 'Favourite',
                    onTap: () => _favouriteSelection(context, gallery),
                  ),
                  _Action(
                    icon: Icons.lock,
                    label: 'Lock',
                    onTap: () => _lockSelection(context, gallery),
                  ),
                  _Action(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () => _shareSelection(context, gallery),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyMove(
    BuildContext context,
    GalleryProvider gallery, {
    required bool move,
  }) async {
    final dest = await showDestinationPicker(context, gallery);
    if (dest == null || !context.mounted) return;
    final items = gallery.selectedAssets;
    final done = move
        ? await gallery.moveAssets(
            items,
            destFolder: dest.$1,
            isNewFolder: dest.$2,
          )
        : await gallery.copyAssets(
            items,
            destFolder: dest.$1,
            isNewFolder: dest.$2,
          );
    gallery.clearSelection();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done.isEmpty
              ? 'Could not ${move ? 'move' : 'copy'} those files.'
              : '${done.length} ${move ? 'moved' : 'copied'} to ${dest.$1}.',
        ),
      ),
    );
  }

  Future<void> _trashSelection(
    BuildContext context,
    GalleryProvider gallery,
  ) async {
    final items = gallery.selectedAssets;
    await gallery.moveManyToTrash(items);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${items.length} moved to trash (30 days).'),
        ),
      );
    }
  }

  Future<void> _favouriteSelection(
    BuildContext context,
    GalleryProvider gallery,
  ) async {
    for (final a in gallery.selectedAssets) {
      if (!gallery.isFavourite(a.id)) await gallery.toggleFavourite(a.id);
    }
    gallery.clearSelection();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favourites.')),
      );
    }
  }

  Future<void> _lockSelection(
    BuildContext context,
    GalleryProvider gallery,
  ) async {
    if (!gallery.hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a PIN in the Locked folder first.'),
        ),
      );
      return;
    }
    final items = gallery.selectedAssets;
    var count = 0;
    for (final a in items) {
      if (await gallery.lockAsset(a)) count++;
    }
    gallery.clearSelection();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count moved to locked folder.')),
      );
    }
  }

  Future<void> _shareSelection(
    BuildContext context,
    GalleryProvider gallery,
  ) async {
    final items = gallery.selectedAssets;
    final ok = await gallery.shareAssets(items);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share those files.')),
      );
    }
    gallery.clearSelection();
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: label,
      onPressed: onTap,
    );
  }
}

/// Destination picker for Copy / Move: existing folders + a "New folder"
/// text field. Returns (folder name, isNewFolder), or null if cancelled.
Future<(String, bool)?> showDestinationPicker(
  BuildContext context,
  GalleryProvider gallery,
) {
  final controller = TextEditingController();
  final folders = gallery.folderNames;
  return showDialog<(String, bool)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Choose destination folder'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'New folder',
                      hintText: 'e.g. Holiday 2026',
                      prefixIcon: Icon(Icons.create_new_folder),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(ctx).pop(
                              (controller.text.trim(), true),
                            ),
                    child: const Text('Create new folder'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Existing folders',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final f in folders)
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(f),
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Navigator.of(ctx).pop((f, false)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ),
  );
}

/// AppBar button that cycles the theme mode (System → Light → Dark →
/// AMOLED). The theme itself is picked in Profile.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return IconButton(
      icon: Icon(
        themeProvider.mode == MossThemeMode.light
            ? Icons.light_mode
            : themeProvider.mode == MossThemeMode.dark
                ? Icons.dark_mode
                : themeProvider.mode == MossThemeMode.amoled
                    ? Icons.nightlight_round
                    : Icons.brightness_auto,
      ),
      tooltip: 'Theme: ${themeProvider.mode.label}',
      onPressed: () => themeProvider.cycle(),
    );
  }
}

/// Small stat card used on the Albums screen.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                child: Icon(icon, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
