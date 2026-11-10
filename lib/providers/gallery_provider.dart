import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortMode { dateNew, dateOld, sizeLarge, name, folder }

extension SortModeLabel on SortMode {
  String get label => switch (this) {
        SortMode.dateNew => 'Newest first',
        SortMode.dateOld => 'Oldest first',
        SortMode.sizeLarge => 'Largest first',
        SortMode.name => 'Name (A–Z)',
        SortMode.folder => 'Folder (A–Z)',
      };
}

enum MossFilter { all, photos, videos, screenshots, favourites, duplicates }

/// Grid layout choice, persisted per view (Photos vs folder/album views).
enum MossView { grid, compact, list }

extension MossViewLabel on MossView {
  String get label => switch (this) {
        MossView.grid => 'Grid',
        MossView.compact => 'Compact grid',
        MossView.list => 'List',
      };
}

extension MossFilterLabel on MossFilter {
  String get label => switch (this) {
        MossFilter.all => 'All',
        MossFilter.photos => 'Photos',
        MossFilter.videos => 'Videos',
        MossFilter.screenshots => 'Screenshots',
        MossFilter.favourites => 'Favourites',
        MossFilter.duplicates => 'Duplicates',
      };
}

/// One item in Moss Trash: the original file bytes are kept in the app's
/// private trash folder until restore or 30-day expiry.
class TrashItem {
  TrashItem({
    required this.id,
    required this.title,
    required this.isVideo,
    required this.deletedAt,
    required this.filePath,
    required this.width,
    required this.height,
    required this.size,
    required this.dateTakenMs,
  });

  factory TrashItem.fromJson(Map<String, dynamic> j) => TrashItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Photo',
        isVideo: j['isVideo'] as bool? ?? false,
        deletedAt:
            DateTime.fromMillisecondsSinceEpoch(j['deletedAt'] as int),
        filePath: j['filePath'] as String,
        width: j['width'] as int? ?? 0,
        height: j['height'] as int? ?? 0,
        size: j['size'] as int? ?? 0,
        dateTakenMs: j['dateTakenMs'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isVideo': isVideo,
        'deletedAt': deletedAt.millisecondsSinceEpoch,
        'filePath': filePath,
        'width': width,
        'height': height,
        'size': size,
        'dateTakenMs': dateTakenMs,
      };

  final String id;
  final String title;
  final bool isVideo;
  final DateTime deletedAt;
  final String filePath;
  final int width;
  final int height;
  final int size;
  final int dateTakenMs;

  int get daysLeft =>
      30 - DateTime.now().difference(deletedAt).inDays;
}

/// One item in the PIN-locked folder: file bytes live in the app's private
/// locked folder, invisible to the system gallery.
class LockedItem {
  LockedItem({
    required this.id,
    required this.title,
    required this.isVideo,
    required this.lockedAt,
    required this.filePath,
    required this.width,
    required this.height,
    required this.size,
    required this.dateTakenMs,
  });

  factory LockedItem.fromJson(Map<String, dynamic> j) => LockedItem(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Photo',
        isVideo: j['isVideo'] as bool? ?? false,
        lockedAt: DateTime.fromMillisecondsSinceEpoch(j['lockedAt'] as int),
        filePath: j['filePath'] as String,
        width: j['width'] as int? ?? 0,
        height: j['height'] as int? ?? 0,
        size: j['size'] as int? ?? 0,
        dateTakenMs: j['dateTakenMs'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isVideo': isVideo,
        'lockedAt': lockedAt.millisecondsSinceEpoch,
        'filePath': filePath,
        'width': width,
        'height': height,
        'size': size,
        'dateTakenMs': dateTakenMs,
      };

  final String id;
  final String title;
  final bool isVideo;
  final DateTime lockedAt;
  final String filePath;
  final int width;
  final int height;
  final int size;
  final int dateTakenMs;
}

class GalleryProvider extends ChangeNotifier {
  GalleryProvider();

  // ----- library state -----
  PermissionState _permission = PermissionState.notDetermined;
  PermissionState get permission => _permission;
  bool get hasPermission =>
      _permission == PermissionState.authorized ||
      _permission == PermissionState.limited;

  bool loading = false;
  String? error;
  double loadProgress = 0;

  /// True while the remaining pages load in the background after the
  /// first page is already on screen.
  bool loadingMore = false;

  // ----- view options (persisted per view) -----
  MossView photosView = MossView.grid;
  MossView folderView = MossView.grid;

  List<AssetEntity> assets = [];
  List<AssetPathEntity> albums = [];

  /// asset id -> file size in bytes (filled lazily; see ensureSizes).
  final Map<String, int> sizes = {};

  // ----- user state (all local, survives restarts) -----
  final Set<String> favourites = {};
  List<TrashItem> trash = [];
  List<LockedItem> locked = [];
  String? _pinHash;
  bool get hasPin => _pinHash != null;

  // ----- sort / filter state -----
  SortMode sort = SortMode.dateNew;
  MossFilter chip = MossFilter.all;
  int? filterYear;
  int? filterMonth;
  int? filterDay;
  int? minSizeBytes; // null = any size

  // ----- duplicates scan -----
  bool scanning = false;
  double scanProgress = 0;
  String scanStatus = '';
  List<List<String>> duplicateGroups = [];
  final Set<String> duplicateIds = {};
  final Set<String> similarIds = {};
  final Set<String> blurryIds = {};
  bool scanDone = false;
  bool _scanCancelled = false;

  // ----- free disk space (via platform channel; null = unavailable) -----
  static const _storageChannel = MethodChannel('moss.storage');
  int? _freeSpaceBytes;
  bool _freeSpaceChecked = false;
  int? get freeSpaceBytes => _freeSpaceBytes;
  bool get freeSpaceChecked => _freeSpaceChecked;

  // ----- multi-select -----
  final Set<String> selected = {};

  int columns = 3;

  // ----- derived -----
  bool get isScreenshotAsset =>
      assets.any((a) => _isScreenshot(a));

  bool _isScreenshot(AssetEntity a) {
    final p = (a.relativePath ?? '').toLowerCase();
    final t = (a.title ?? '').toLowerCase();
    return p.contains('screenshot') || t.contains('screenshot');
  }

  String folderOf(AssetEntity a) {
    final p = a.relativePath;
    if (p == null || p.isEmpty) return 'Unknown';
    final parts = p.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Unknown';
    return parts.last;
  }

  List<AssetEntity> get filteredAssets {
    Iterable<AssetEntity> list = assets;
    switch (chip) {
      case MossFilter.photos:
        list = list.where((a) => a.type == AssetType.image);
      case MossFilter.videos:
        list = list.where((a) => a.type == AssetType.video);
      case MossFilter.screenshots:
        list = list.where(_isScreenshot);
      case MossFilter.favourites:
        list = list.where((a) => favourites.contains(a.id));
      case MossFilter.duplicates:
        list = list.where((a) => duplicateIds.contains(a.id));
      case MossFilter.all:
        break;
    }
    if (filterYear != null) {
      list = list.where((a) => a.createDateTime.year == filterYear);
    }
    if (filterMonth != null) {
      list = list.where((a) => a.createDateTime.month == filterMonth);
    }
    if (filterDay != null) {
      list = list.where((a) => a.createDateTime.day == filterDay);
    }
    if (minSizeBytes != null) {
      list = list.where(
          (a) => (sizes[a.id] ?? 0) >= minSizeBytes!);
    }
    final sorted = list.toList();
    switch (sort) {
      case SortMode.dateNew:
        sorted.sort((a, b) =>
            b.createDateTime.compareTo(a.createDateTime));
      case SortMode.dateOld:
        sorted.sort((a, b) =>
            a.createDateTime.compareTo(b.createDateTime));
      case SortMode.sizeLarge:
        sorted.sort((a, b) =>
            (sizes[b.id] ?? 0).compareTo(sizes[a.id] ?? 0));
      case SortMode.name:
        sorted.sort((a, b) => (a.title ?? a.id)
            .toLowerCase()
            .compareTo((b.title ?? b.id).toLowerCase()));
      case SortMode.folder:
        sorted.sort((a, b) =>
            folderOf(a).compareTo(folderOf(b)));
    }
    return sorted;
  }

  /// Photos taken today (same month + day) in past years.
  List<AssetEntity> get memories {
    final now = DateTime.now();
    return assets
        .where((a) =>
            a.createDateTime.month == now.month &&
            a.createDateTime.day == now.day &&
            a.createDateTime.year < now.year)
        .toList()
      ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
  }

  /// Months present in the library, newest first, as (year, month).
  List<(int, int)> get availableMonths {
    final set = <(int, int)>{};
    for (final a in assets) {
      set.add((a.createDateTime.year, a.createDateTime.month));
    }
    final list = set.toList()
      ..sort((a, b) => b.$1 != a.$1
          ? b.$1.compareTo(a.$1)
          : b.$2.compareTo(a.$2));
    return list;
  }

  int get totalKnownBytes =>
      sizes.values.fold<int>(0, (p, e) => p + e);

  // ----- storage breakdown (Profile tab) -----
  int get photosBytes => assets
      .where((a) => a.type == AssetType.image)
      .fold<int>(0, (p, a) => p + (sizes[a.id] ?? 0));

  int get videosBytes => assets
      .where((a) => a.type == AssetType.video)
      .fold<int>(0, (p, a) => p + (sizes[a.id] ?? 0));

  int get screenshotsBytes => assets
      .where(_isScreenshot)
      .fold<int>(0, (p, a) => p + (sizes[a.id] ?? 0));

  int get downloadsBytes => assets
      .where(
        (a) => (a.relativePath ?? '').toLowerCase().contains('download'),
      )
      .fold<int>(0, (p, a) => p + (sizes[a.id] ?? 0));

  /// Biggest folders by known size, top 5, as (folder name, bytes).
  List<(String, int)> get biggestFolders {
    final byFolder = <String, int>{};
    for (final a in assets) {
      final f = folderOf(a);
      byFolder[f] = (byFolder[f] ?? 0) + (sizes[a.id] ?? 0);
    }
    final list = byFolder.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).map((e) => (e.key, e.value)).toList();
  }

  /// Bytes wasted on extra copies: every duplicate group keeps one copy,
  /// the rest are waste.
  int get duplicateWasteBytes {
    var waste = 0;
    for (final group in duplicateGroups) {
      final sized = group
          .map((id) => sizes[id] ?? 0)
          .where((s) => s > 0)
          .toList();
      if (sized.length > 1) {
        sized.sort();
        waste += sized.sublist(0, sized.length - 1).fold(0, (p, e) => p + e);
      }
    }
    return waste;
  }

  int get trashBytes =>
      trash.fold<int>(0, (p, t) => p + t.size);

  /// Free space on the shared storage volume, via the platform channel.
  /// Returns null when it cannot be obtained — the UI omits it then.
  Future<int?> refreshFreeSpace() async {
    try {
      final bytes = await _storageChannel.invokeMethod<int>('getFreeSpace');
      _freeSpaceBytes = bytes;
      _freeSpaceChecked = true;
      notifyListeners();
      return bytes;
    } catch (_) {
      _freeSpaceChecked = true;
      notifyListeners();
      return null;
    }
  }

  bool get sizesComplete =>
      assets.isNotEmpty && sizes.length >= assets.length;

  List<AssetEntity> get biggestFiles {
    final list = assets.toList()
      ..sort((a, b) => (sizes[b.id] ?? 0).compareTo(sizes[a.id] ?? 0));
    return list.take(20).toList();
  }

  // ----- init / loading -----

  Future<void> init() async {
    await _loadLocalState();
    _permission = await PhotoManager.requestPermissionExtend();
    notifyListeners();
    if (hasPermission) {
      await loadLibrary();
    }
  }

  Future<void> requestPermission() async {
    _permission = await PhotoManager.requestPermissionExtend();
    notifyListeners();
    if (hasPermission) await loadLibrary();
  }

  /// Fast first load: the first page (~100 assets) is shown immediately;
  /// the remaining pages load in the background without blocking the UI.
  /// Never blocks first paint on the full scan, the sizes scan or the
  /// hash scan.
  int _loadGen = 0;

  Future<void> loadLibrary() async {
    _loadGen++;
    final gen = _loadGen;
    loading = true;
    error = null;
    loadProgress = 0;
    notifyListeners();
    try {
      albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        onlyAll: false,
      );
      final all = albums.firstWhere(
        (p) => p.isAll,
        orElse: () => albums.first,
      );
      final count = await all.assetCountAsync;
      const firstPageSize = 100;
      final first = await all.getAssetListPaged(
        page: 0,
        size: firstPageSize,
      );
      assets = first;
      loadProgress = count == 0 ? 1 : first.length / count;
      loading = false;
      _purgeExpiredTrash();
      notifyListeners();
      if (first.length < count) {
        // Background: remaining pages, one page at a time.
        unawaited(_loadRemainingPages(all, count, first.length, gen));
      } else {
        loadProgress = 1;
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRemainingPages(
    AssetPathEntity all,
    int count,
    int alreadyLoaded,
    int gen,
  ) async {
    loadingMore = true;
    try {
      // Contiguous background load, 100 items per page (page 0 is the
      // first page already on screen).
      var loaded = alreadyLoaded;
      var page = 1;
      while (loaded < count) {
        if (gen != _loadGen) return; // a fresh load started — stop
        final chunk = await all.getAssetListPaged(page: page, size: 100);
        if (chunk.isEmpty) break;
        assets = [...assets, ...chunk];
        loaded += chunk.length;
        page++;
        loadProgress = loaded / count;
        notifyListeners();
      }
      loadProgress = 1;
    } catch (_) {
      // Background load failing must not blank the first page.
    } finally {
      if (gen == _loadGen) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => loadLibrary();

  // ----- local persistence -----

  Future<Directory> get _docs async =>
      getApplicationDocumentsDirectory();

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    favourites
      ..clear()
      ..addAll(prefs.getStringList('moss_favourites') ?? []);
    photosView = MossView.values.firstWhere(
      (v) => v.name == prefs.getString('moss_photos_view'),
      orElse: () => MossView.grid,
    );
    folderView = MossView.values.firstWhere(
      (v) => v.name == prefs.getString('moss_folder_view'),
      orElse: () => MossView.grid,
    );
    _pinHash = prefs.getString('moss_pin_hash');
    final dir = await _docs;
    final trashFile = File('${dir.path}/moss_trash.json');
    if (await trashFile.exists()) {
      try {
        final raw = jsonDecode(await trashFile.readAsString()) as List;
        trash = raw
            .map((e) => TrashItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        trash = [];
      }
    }
    final lockedFile = File('${dir.path}/moss_locked.json');
    if (await lockedFile.exists()) {
      try {
        final raw = jsonDecode(await lockedFile.readAsString()) as List;
        locked = raw
            .map((e) => LockedItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        locked = [];
      }
    }
  }

  Future<void> _saveFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('moss_favourites', favourites.toList());
  }

  Future<void> _saveTrash() async {
    final dir = await _docs;
    await File('${dir.path}/moss_trash.json').writeAsString(
      jsonEncode(trash.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _saveLocked() async {
    final dir = await _docs;
    await File('${dir.path}/moss_locked.json').writeAsString(
      jsonEncode(locked.map((t) => t.toJson()).toList()),
    );
  }

  Future<Directory> _trashDir() async {
    final dir = Directory('${(await _docs).path}/moss_trash');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _lockedDir() async {
    final dir = Directory('${(await _docs).path}/moss_locked');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void _purgeExpiredTrash() {
    final now = DateTime.now();
    final expired =
        trash.where((t) => now.difference(t.deletedAt).inDays >= 30);
    for (final t in expired) {
      File(t.filePath).delete().catchError((_) => File(t.filePath));
    }
    if (expired.isNotEmpty) {
      trash.removeWhere(
          (t) => now.difference(t.deletedAt).inDays >= 30);
      _saveTrash();
    }
  }

  // ----- favourites -----

  Future<void> toggleFavourite(String id) async {
    if (favourites.contains(id)) {
      favourites.remove(id);
    } else {
      favourites.add(id);
    }
    await _saveFavourites();
    notifyListeners();
  }

  bool isFavourite(String id) => favourites.contains(id);

  // ----- Quick Share (system share sheet, original file, offline) -----

  /// Shares the ORIGINAL files of [items] through the Android share sheet.
  /// Fully offline — no upload, the file goes straight to the app the user
  /// picks (WhatsApp, Gmail, …).
  Future<bool> shareAssets(List<AssetEntity> items) async {
    if (items.isEmpty) return false;
    final files = <XFile>[];
    for (final a in items) {
      final f = await a.loadFile();
      if (f != null && await f.exists()) {
        files.add(XFile(f.path, name: a.title ?? 'photo'));
      }
    }
    if (files.isEmpty) return false;
    await SharePlus.instance.share(
      ShareParams(files: files),
    );
    return true;
  }

  /// One-tap share of a single photo — the Quick Share button.
  Future<bool> quickShare(AssetEntity asset) => shareAssets([asset]);

  /// Shares a file that lives in Moss's private folders (trash / locked).
  Future<bool> shareLocalFile(String path, {String name = 'photo'}) async {
    final f = File(path);
    if (!await f.exists()) return false;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path, name: name)]),
    );
    return true;
  }

  // ----- copy / move between folders -----

  /// All folder names present in the library, most items first.
  List<String> get folderNames {
    final counts = <String, int>{};
    for (final a in assets) {
      final f = folderOf(a);
      counts[f] = (counts[f] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.map((e) => e.key).toList();
  }

  /// The MediaStore relative path (e.g. "DCIM/Camera/") of a folder,
  /// taken from an asset that lives in it. Null when no asset is in it.
  String? relativePathOfFolder(String folder) {
    for (final a in assets) {
      if (folderOf(a) == folder) {
        final p = a.relativePath;
        if (p != null && p.isNotEmpty) return p;
      }
    }
    return null;
  }

  /// Copy [items] into a folder. [destFolder] is an existing folder name
  /// (copies land next to that folder's other files) or, when
  /// [isNewFolder] is true, a brand-new folder created under Pictures/.
  /// Returns the assets that were copied successfully.
  Future<List<AssetEntity>> copyAssets(
    List<AssetEntity> items, {
    required String destFolder,
    bool isNewFolder = false,
  }) async {
    final destRel = isNewFolder
        ? 'Pictures/$destFolder/'
        : (relativePathOfFolder(destFolder) ?? 'Pictures/$destFolder/');
    final copied = <AssetEntity>[];
    for (final a in items) {
      File? file;
      try {
        file = await a.loadFile();
      } catch (_) {
        continue;
      }
      if (file == null) continue;
      try {
        if (a.type == AssetType.video) {
          await PhotoManager.editor.saveVideo(
            file,
            title: a.title,
            relativePath: destRel,
            creationDate: a.createDateTime,
          );
        } else {
          await PhotoManager.editor.saveImageWithPath(
            file.path,
            title: a.title,
            relativePath: destRel,
            creationDate: a.createDateTime,
          );
        }
        copied.add(a);
      } catch (_) {
        // One failed file must not stop the rest.
      }
    }
    if (copied.isNotEmpty) await loadLibrary();
    return copied;
  }

  /// Move [items] into a folder: copy, then delete the originals.
  /// Returns the assets that were moved successfully.
  Future<List<AssetEntity>> moveAssets(
    List<AssetEntity> items, {
    required String destFolder,
    bool isNewFolder = false,
  }) async {
    final copied = await copyAssets(
      items,
      destFolder: destFolder,
      isNewFolder: isNewFolder,
    );
    if (copied.isEmpty) return copied;
    for (final a in copied) {
      try {
        await PhotoManager.editor.deleteWithIds([a.id]);
      } catch (_) {}
      assets.removeWhere((x) => x.id == a.id);
      favourites.remove(a.id);
      selected.remove(a.id);
    }
    notifyListeners();
    return copied;
  }

  // ----- sizes / storage -----

  /// Fills in file sizes for assets that don't have one yet. Runs in the
  /// background in batches; the grid and storage meter update as it goes.
  Future<void> ensureSizes({int limit = 100000}) async {
    var done = 0;
    for (final a in assets) {
      if (done >= limit) break;
      if (sizes.containsKey(a.id)) continue;
      try {
        final f = await a.loadFile();
        if (f != null) sizes[a.id] = await f.length();
      } catch (_) {
        // File unreadable — leave unknown.
      }
      done++;
      if (done % 50 == 0) notifyListeners();
    }
    notifyListeners();
  }

  // ----- duplicates / similar / blurry scan -----

  /// Exact duplicates by SHA-256 of the file bytes (photos only — hashing
  /// whole videos would take too long and drain battery).
  /// Similar = same dimensions with a file size within 15%.
  /// Possible blurry = very few bytes per pixel for its resolution.
  /// All three are labelled honestly in the UI; nothing is auto-deleted.
  ///
  /// File paths are resolved on the main thread, then files are hashed in
  /// batches of ~20 inside isolates ([Isolate.run]) so the UI stays
  /// responsive. [stopScan] cancels cleanly between batches and KEEPS the
  /// results found so far (scanDone=true, partial results).
  Future<void> scanDuplicates() async {
    if (scanning) return;
    scanning = true;
    _scanCancelled = false;
    scanDone = false;
    scanStatus = 'Starting scan…';
    scanProgress = 0;
    duplicateGroups = [];
    duplicateIds.clear();
    similarIds.clear();
    blurryIds.clear();
    notifyListeners();
    try {
      final images =
          assets.where((a) => a.type == AssetType.image).toList();
      // Step 1: resolve paths + sizes on the main thread (cheap metadata).
      final entries = <_ScanEntry>[];
      for (var i = 0; i < images.length; i++) {
        final a = images[i];
        if (i % 25 == 0) {
          scanStatus = 'Listing ${i + 1} of ${images.length} photos…';
          scanProgress = (i / images.length) * 0.1;
          notifyListeners();
        }
        File? file;
        try {
          file = await a.loadFile();
        } catch (_) {
          continue;
        }
        if (file == null) continue;
        int size;
        try {
          size = await file.length();
        } catch (_) {
          continue;
        }
        sizes[a.id] = size;
        final pixels = math.max(1, a.width * a.height);
        // Heuristic only: under 0.05 bytes per pixel is unusually small
        // for a photo of this resolution — likely blurry / low detail.
        if (size / pixels < 0.05) blurryIds.add(a.id);
        entries.add(
          _ScanEntry(
            id: a.id,
            path: file.path,
            size: size,
            dims: '${a.width}x${a.height}',
          ),
        );
      }
      // Step 2: hash in batches of 20 inside isolates.
      final byHash = <String, List<String>>{};
      final byDims = <String, List<(String, int)>>{};
      for (final e in entries) {
        byDims.putIfAbsent(e.dims, () => []).add((e.id, e.size));
      }
      const batchSize = 20;
      var hashed = 0;
      for (var start = 0; start < entries.length; start += batchSize) {
        if (_scanCancelled) break;
        final batch = entries.sublist(
          start,
          math.min(start + batchSize, entries.length),
        );
        final results = await Isolate.run(
          () => _hashBatch(batch.map((e) => e.path).toList()),
        );
        for (var i = 0; i < batch.length; i++) {
          final hash = results[i];
          if (hash != null) {
            byHash.putIfAbsent(hash, () => []).add(batch[i].id);
          }
        }
        hashed += batch.length;
        scanProgress = 0.1 + 0.9 * (hashed / entries.length);
        scanStatus = 'Hashing $hashed of ${entries.length} photos…';
        notifyListeners();
        // Tiny breather between batches so the UI thread stays free.
        await Future.delayed(const Duration(milliseconds: 10));
      }
      _finalizeScan(byHash, byDims);
      if (_scanCancelled) {
        scanStatus = 'Stopped — partial results '
            '(${duplicateGroups.length} duplicate groups so far)';
      } else {
        scanStatus =
            '${duplicateGroups.length} duplicate groups, ${similarIds.length} similar, ${blurryIds.length} possibly blurry';
      }
    } catch (e) {
      scanStatus = 'Scan failed: $e';
    } finally {
      scanning = false;
      scanDone = true;
      scanProgress = _scanCancelled ? scanProgress : 1;
      notifyListeners();
    }
  }

  /// Cancel a running scan. Results found so far are kept.
  void stopScan() {
    _scanCancelled = true;
  }

  void _finalizeScan(
    Map<String, List<String>> byHash,
    Map<String, List<(String, int)>> byDims,
  ) {
    duplicateGroups = [];
    duplicateIds.clear();
    similarIds.clear();
    for (final group in byHash.values) {
      if (group.length > 1) {
        duplicateGroups.add(group);
        duplicateIds.addAll(group);
      }
    }
    for (final group in byDims.values) {
      if (group.length < 2) continue;
      for (var x = 0; x < group.length; x++) {
        for (var y = x + 1; y < group.length; y++) {
          final s1 = group[x].$2;
          final s2 = group[y].$2;
          if (s1 == 0 || s2 == 0) continue;
          final ratio = s1 > s2 ? s1 / s2 : s2 / s1;
          if (ratio <= 1.15) {
            similarIds.add(group[x].$1);
            similarIds.add(group[y].$1);
          }
        }
      }
    }
    // Exact duplicates are not "similar" — keep the groups distinct.
    similarIds.removeAll(duplicateIds);
  }

  AssetEntity? byId(String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ----- trash -----

  Future<bool> moveToTrash(AssetEntity asset) async {
    File? file;
    try {
      file = await asset.loadFile();
    } catch (_) {
      return false;
    }
    if (file == null) return false;
    int size = sizes[asset.id] ?? 0;
    try {
      size = await file.length();
    } catch (_) {}
    final dir = await _trashDir();
    final ext = _extensionOf(asset.title ?? 'photo.jpg');
    final dest = File('${dir.path}/${asset.id}$ext');
    try {
      await file.copy(dest.path);
    } catch (_) {
      return false;
    }
    final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (deleted.isEmpty) {
      await dest.delete().catchError((_) => dest);
      return false;
    }
    assets.removeWhere((a) => a.id == asset.id);
    favourites.remove(asset.id);
    selected.remove(asset.id);
    trash.insert(
      0,
      TrashItem(
        id: asset.id,
        title: asset.title ?? 'Photo',
        isVideo: asset.type == AssetType.video,
        deletedAt: DateTime.now(),
        filePath: dest.path,
        width: asset.width,
        height: asset.height,
        size: size,
        dateTakenMs:
            asset.createDateTime.millisecondsSinceEpoch,
      ),
    );
    await _saveTrash();
    notifyListeners();
    return true;
  }

  Future<void> moveManyToTrash(List<AssetEntity> items) async {
    for (final a in items) {
      await moveToTrash(a);
    }
    selected.clear();
    notifyListeners();
  }

  /// Permanently deletes the originals (no trash copy) — used from the
  /// duplicates screen after the user picks which copies to keep.
  Future<int> deletePermanently(List<AssetEntity> items) async {
    var count = 0;
    for (final a in items) {
      try {
        final deleted =
            await PhotoManager.editor.deleteWithIds([a.id]);
        if (deleted.isNotEmpty) count++;
      } catch (_) {}
      assets.removeWhere((x) => x.id == a.id);
      favourites.remove(a.id);
      selected.remove(a.id);
    }
    notifyListeners();
    return count;
  }

  Future<bool> restoreFromTrash(TrashItem item) async {
    final f = File(item.filePath);
    if (!await f.exists()) return false;
    try {
      if (item.isVideo) {
        await PhotoManager.editor.saveVideo(
          f,
          title: item.title,
          creationDate:
              DateTime.fromMillisecondsSinceEpoch(item.dateTakenMs),
        );
      } else {
        await PhotoManager.editor.saveImageWithPath(
          f.path,
          title: item.title,
          creationDate:
              DateTime.fromMillisecondsSinceEpoch(item.dateTakenMs),
        );
      }
    } catch (_) {
      return false;
    }
    await f.delete().catchError((_) => f);
    trash.removeWhere((t) => t.id == item.id);
    await _saveTrash();
    await loadLibrary();
    return true;
  }

  Future<void> deleteTrashItemPermanently(TrashItem item) async {
    await File(item.filePath).delete().catchError((_) => File(item.filePath));
    trash.removeWhere((t) => t.id == item.id);
    await _saveTrash();
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    for (final t in trash) {
      await File(t.filePath).delete().catchError((_) => File(t.filePath));
    }
    trash.clear();
    await _saveTrash();
    notifyListeners();
  }

  // ----- locked folder -----

  String _pinHashOf(String pin) =>
      sha256.convert(utf8.encode('moss-pin:$pin')).toString();

  Future<void> setPin(String pin) async {
    _pinHash = _pinHashOf(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moss_pin_hash', _pinHash!);
    notifyListeners();
  }

  bool verifyPin(String pin) => _pinHash == _pinHashOf(pin);

  Future<bool> lockAsset(AssetEntity asset) async {
    File? file;
    try {
      file = await asset.loadFile();
    } catch (_) {
      return false;
    }
    if (file == null) return false;
    final dir = await _lockedDir();
    final ext = _extensionOf(asset.title ?? 'photo.jpg');
    final dest = File('${dir.path}/${asset.id}$ext');
    try {
      await file.copy(dest.path);
    } catch (_) {
      return false;
    }
    final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (deleted.isEmpty) {
      await dest.delete().catchError((_) => dest);
      return false;
    }
    int size = sizes[asset.id] ?? 0;
    try {
      size = await file.length();
    } catch (_) {}
    assets.removeWhere((a) => a.id == asset.id);
    favourites.remove(asset.id);
    selected.remove(asset.id);
    locked.insert(
      0,
      LockedItem(
        id: asset.id,
        title: asset.title ?? 'Photo',
        isVideo: asset.type == AssetType.video,
        lockedAt: DateTime.now(),
        filePath: dest.path,
        width: asset.width,
        height: asset.height,
        size: size,
        dateTakenMs:
            asset.createDateTime.millisecondsSinceEpoch,
      ),
    );
    await _saveLocked();
    notifyListeners();
    return true;
  }

  Future<bool> unlockAsset(LockedItem item) async {
    final f = File(item.filePath);
    if (!await f.exists()) return false;
    try {
      if (item.isVideo) {
        await PhotoManager.editor.saveVideo(
          f,
          title: item.title,
          creationDate:
              DateTime.fromMillisecondsSinceEpoch(item.dateTakenMs),
        );
      } else {
        await PhotoManager.editor.saveImageWithPath(
          f.path,
          title: item.title,
          creationDate:
              DateTime.fromMillisecondsSinceEpoch(item.dateTakenMs),
        );
      }
    } catch (_) {
      return false;
    }
    await f.delete().catchError((_) => f);
    locked.removeWhere((t) => t.id == item.id);
    await _saveLocked();
    await loadLibrary();
    return true;
  }

  Future<void> deleteLockedItemPermanently(LockedItem item) async {
    await File(item.filePath).delete().catchError((_) => File(item.filePath));
    locked.removeWhere((t) => t.id == item.id);
    await _saveLocked();
    notifyListeners();
  }

  // ----- filters / sort setters -----

  void setSort(SortMode s) {
    sort = s;
    notifyListeners();
    if (s == SortMode.sizeLarge) {
      unawaited(ensureSizes());
    }
  }

  void setChip(MossFilter c) {
    chip = c;
    notifyListeners();
  }

  void setMonthFilter(int? year, int? month) {
    filterYear = year;
    filterMonth = month;
    filterDay = null;
    notifyListeners();
  }

  void setDayFilter(DateTime? day) {
    if (day == null) {
      filterYear = null;
      filterMonth = null;
      filterDay = null;
    } else {
      filterYear = day.year;
      filterMonth = day.month;
      filterDay = day.day;
    }
    notifyListeners();
  }

  void setMinSize(int? bytes) {
    minSizeBytes = bytes;
    notifyListeners();
    if (bytes != null) unawaited(ensureSizes());
  }

  void clearFilters() {
    filterYear = null;
    filterMonth = null;
    filterDay = null;
    minSizeBytes = null;
    chip = MossFilter.all;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      chip != MossFilter.all ||
      filterYear != null ||
      filterMonth != null ||
      filterDay != null ||
      minSizeBytes != null;

  void setColumns(int c) {
    columns = c.clamp(2, 6);
    notifyListeners();
  }

  Future<void> setPhotosView(MossView v) async {
    photosView = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moss_photos_view', v.name);
  }

  Future<void> setFolderView(MossView v) async {
    folderView = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moss_folder_view', v.name);
  }

  void toggleSelect(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  List<AssetEntity> get selectedAssets =>
      assets.where((a) => selected.contains(a.id)).toList();

  /// Search by name, folder, type word, or date ("2026-10", "Oct 2026").
  List<AssetEntity> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    int? qYear;
    int? qMonth;
    final ym = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(q);
    if (ym != null) {
      qYear = int.tryParse(ym.group(1)!);
      qMonth = int.tryParse(ym.group(2)!);
    } else {
      for (var i = 0; i < monthNames.length; i++) {
        if (q.contains(monthNames[i])) {
          qMonth = i + 1;
          final y = RegExp(r'(\d{4})').firstMatch(q);
          if (y != null) qYear = int.tryParse(y.group(1)!);
          break;
        }
      }
    }
    return assets.where((a) {
      final title = (a.title ?? '').toLowerCase();
      final folder = folderOf(a).toLowerCase();
      if (title.contains(q) || folder.contains(q)) return true;
      if (q == 'photo' || q == 'photos' || q == 'image') {
        return a.type == AssetType.image;
      }
      if (q == 'video' || q == 'videos') {
        return a.type == AssetType.video;
      }
      if (q == 'screenshot' || q == 'screenshots') return _isScreenshot(a);
      if (qYear != null) {
        if (a.createDateTime.year != qYear) return false;
        if (qMonth != null && a.createDateTime.month != qMonth) {
          return false;
        }
        return true;
      }
      if (qMonth != null) return a.createDateTime.month == qMonth;
      return false;
    }).toList();
  }

  // ----- helpers -----

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String formatMonthYear(int year, int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month - 1]} $year';
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    if (ext.length > 5) return '.jpg';
    return ext;
  }
}

/// One file queued for hashing in the duplicates scan.
class _ScanEntry {
  const _ScanEntry({
    required this.id,
    required this.path,
    required this.size,
    required this.dims,
  });

  final String id;
  final String path;
  final int size;
  final String dims;
}

/// Runs inside an isolate ([Isolate.run]): SHA-256 each file in [paths].
/// Returns the hex hash per path, or null when a file cannot be read.
/// Top-level so it can cross the isolate boundary.
List<String?> _hashBatch(List<String> paths) {
  return paths.map((p) {
    try {
      final bytes = File(p).readAsBytesSync();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }).toList();
}
