import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';
import 'edit_screen.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.title,
    this.slideshow = false,
  });

  final List<AssetEntity> items;
  final int initialIndex;
  final String? title;
  final bool slideshow;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _controller;
  late int _index;
  Timer? _slideshowTimer;
  bool _playingSlideshow = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    if (widget.slideshow) _startSlideshow();
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    _playingSlideshow = true;
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.items.isEmpty) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
    setState(() {});
  }

  void _stopSlideshow() {
    _playingSlideshow = false;
    _slideshowTimer?.cancel();
    setState(() {});
  }

  AssetEntity get _current => widget.items[_index];

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final asset = _current;
    final isFav = gallery.isFavourite(asset.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ??
              GalleryProvider.formatDate(asset.createDateTime),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.slideshow)
            IconButton(
              icon: Icon(
                _playingSlideshow ? Icons.pause : Icons.play_arrow,
              ),
              color: Colors.white,
              tooltip: _playingSlideshow ? 'Pause slideshow' : 'Play slideshow',
              onPressed: () {
                if (_playingSlideshow) {
                  _stopSlideshow();
                } else {
                  _startSlideshow();
                }
              },
            ),
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            color: isFav ? Colors.red : Colors.white,
            tooltip: 'Favourite',
            onPressed: () => gallery.toggleFavourite(asset.id),
          ),
          // Share lives here, in the overflow menu — no share button in
          // the AppBar or bottom bar anymore.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'share') gallery.quickShare(asset);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            color: Colors.white,
            tooltip: 'Details',
            onPressed: () => _showInfo(context, gallery, asset),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final item = widget.items[i];
          if (item.type == AssetType.video) {
            return _VideoPage(asset: item);
          }
          return _ZoomableImage(asset: item);
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (asset.type == AssetType.image)
                _ViewerAction(
                  icon: Icons.edit,
                  label: 'Edit',
                  onTap: () async {
                    final saved = await pushMoss<bool>(
                      context,
                      EditScreen(asset: asset),
                    );
                    if (saved == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edited copy saved to gallery.'),
                        ),
                      );
                    }
                  },
                ),
              _ViewerAction(
                icon: Icons.lock,
                label: 'Lock',
                onTap: () async {
                  if (!gallery.hasPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Set a PIN in the Locked folder first.'),
                      ),
                    );
                    return;
                  }
                  final ok = await gallery.lockAsset(asset);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Moved to locked folder.' : 'Could not lock.',
                      ),
                    ),
                  );
                  if (ok) Navigator.of(context).pop();
                },
              ),
              _ViewerAction(
                icon: Icons.delete,
                label: 'Delete',
                onTap: () async {
                  final ok = await gallery.moveToTrash(asset);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Moved to trash (30 days).'
                            : 'Could not delete.',
                      ),
                    ),
                  );
                  if (ok) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInfo(
    BuildContext context,
    GalleryProvider gallery,
    AssetEntity asset,
  ) async {
    var size = gallery.sizes[asset.id];
    File? file;
    String path = '';
    try {
      file = await asset.loadFile();
      path = file?.path ?? '';
      size ??= file == null ? null : await file.length();
    } catch (_) {}
    if (!context.mounted) return;
    final d = asset.createDateTime;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.title ?? 'Photo',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow('Date', GalleryProvider.formatDate(d)),
              _infoRow(
                'Time',
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
              ),
              _infoRow('Type', asset.type == AssetType.video ? 'Video' : 'Photo'),
              _infoRow('Resolution', '${asset.width} × ${asset.height}'),
              if (size != null)
                _infoRow('Size', GalleryProvider.formatBytes(size)),
              if (asset.type == AssetType.video)
                _infoRow('Duration', '${asset.duration} sec'),
              if (path.isNotEmpty) _infoRow('Path', path),
              _infoRow('Folder', gallery.folderOf(asset)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

/// Full-screen photo with pinch zoom + double-tap zoom.
/// Double-tap cycles 1x -> 2x -> 4x -> 1x, animated over ~250ms
/// (easeOutCubic), zooming into the tapped point.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.asset});

  final AssetEntity asset;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _controller.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final targetScale = currentScale < 1.5
        ? 2.0
        : currentScale < 3.0
            ? 4.0
            : 1.0;
    final target = targetScale == 1.0
        ? Matrix4.identity()
        : Matrix4.identity()
          ..translateByDouble(
            _doubleTapPosition.dx,
            _doubleTapPosition.dy,
            0.0,
            1.0,
          )
          ..scaleByDouble(targetScale, targetScale, targetScale, 1.0)
          ..translateByDouble(
            -_doubleTapPosition.dx,
            -_doubleTapPosition.dy,
            0.0,
            1.0,
          );
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) {
        _doubleTapPosition = details.localPosition;
      },
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image(
            image: AssetEntityImageProvider(widget.asset, isOriginal: true),
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.asset});

  final AssetEntity asset;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final file = await widget.asset.loadFile();
      if (file == null || !mounted) {
        setState(() => _failed = true);
        return;
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      if (!mounted) return;
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white, size: 48),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          if (c.value.isPlaying) {
            c.pause();
          } else {
            c.play();
          }
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              if (!c.value.isPlaying)
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 72,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
