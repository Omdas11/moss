import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets.dart';
import 'viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final results = _query.isEmpty ? <AssetEntity>[] : gallery.search(_query);
    final selecting = gallery.selected.isNotEmpty;
    final view = gallery.folderView;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search photos…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final hint in [
                  'October 2026',
                  '2026-10',
                  'Screenshots',
                  'Videos',
                ])
                  ActionChip(
                    label: Text(hint),
                    onPressed: () {
                      _controller.text = hint;
                      setState(() => _query = hint);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (selecting) const SelectionActionBar(),
          if (_query.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Search by name, folder, type, or date.\n'
                  'Try "October 2026" or "2026-10".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (results.isEmpty)
            const Expanded(
              child: Center(child: Text('No photos match that search.')),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${results.length} results',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _resultsBody(view, results)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultsBody(MossView view, List<AssetEntity> results) {
    final gallery = context.read<GalleryProvider>();
    switch (view) {
      case MossView.list:
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 110),
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final a = results[i];
            return AssetListRow(
              asset: a,
              selected: gallery.selected.contains(a.id),
              onTap: () => _tap(results, i),
              onLongPress: () => gallery.toggleSelect(a.id),
            );
          },
        );
      case MossView.compact:
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final a = results[i];
            return AssetThumb(
              asset: a,
              size: 80,
              borderRadius: 12,
              selected: gallery.selected.contains(a.id),
              isFavourite: gallery.isFavourite(a.id),
              onTap: () => _tap(results, i),
              onLongPress: () => gallery.toggleSelect(a.id),
            );
          },
        );
      case MossView.grid:
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final a = results[i];
            return AssetThumb(
              asset: a,
              size: 100,
              borderRadius: 18,
              selected: gallery.selected.contains(a.id),
              isFavourite: gallery.isFavourite(a.id),
              onTap: () => _tap(results, i),
              onLongPress: () => gallery.toggleSelect(a.id),
            );
          },
        );
    }
  }

  void _tap(List<AssetEntity> results, int i) {
    final gallery = context.read<GalleryProvider>();
    final a = results[i];
    if (gallery.selected.isNotEmpty) {
      gallery.toggleSelect(a.id);
    } else {
      pushMoss(
        context,
        ViewerScreen(items: results, initialIndex: i),
      );
    }
  }
}
