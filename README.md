# Moss

A local, fully offline photo gallery for Android. No account, no cloud, no
analytics, no uploads — your photos never leave your phone.

## What it does (v1.1)

- **Photos** — timeline grid with date headers. The first photo of each day
  is a wide tile; pinch to change grid size. Sort by newest / oldest /
  largest / name / folder. Filter chips: All, Photos, Videos, Screenshots,
  Favourites, Duplicates. Filter by month (e.g. October 2026) and by size.
  Pull down at the top to expand the header (logo, counts, storage,
  Memories teaser). First page of photos appears immediately; the rest
  loads in the background, with skeleton tiles while the first page loads.
- **View options** — grid, compact grid, and list (thumbnail + title +
  date + size), switchable from the AppBar and remembered separately for
  Photos and for folder views.
- **Multi-select** — long-press a photo to enter selection mode, tap to
  toggle. Copy, Move, Delete (to Trash), Favourite, Lock, and Share.
  Copy/Move open a destination picker: existing folders or a new folder.
- **Quick Share** — sharing lives in multi-select and in the viewer's
  overflow menu only. No per-photo share buttons. Opens the Android
  system share sheet (WhatsApp, Gmail, …) with the original file. Fully
  offline — no upload.
- **Albums** — smart albums (All photos, Videos, Screenshots, Favourites),
  by-month albums, folders from the device (each with the same view
  options and multi-select as Photos).
- **Search** — by name, folder, type, or date ("October 2026", "2026-10"),
  with the same view options and multi-select.
- **Viewer** — full-screen swipe, pinch zoom, and double-tap zoom that
  cycles 1x → 2x → 4x → 1x with a smooth animated transition. Video
  playback, info sheet (date, time, type, resolution, size, path,
  folder), favourite toggle. Share is in the overflow (⋮) menu.
- **Duplicates** — exact duplicates by file hash (SHA-256, hashed in
  batches inside isolates so the UI stays responsive), similar photos
  (same dimensions, size within 15%), possibly-blurry photos (heuristic:
  very few bytes per pixel — labelled as a guess, not a fact). A STOP
  button cancels the scan cleanly and keeps the results found so far.
  Nothing is ever deleted automatically; you choose what to delete.
- **Storage / Profile** — Profile tab shows the Moss logo and version, a
  theme picker, and a storage breakdown: total photo/video size, split by
  type (photos, videos, screenshots, downloads) with segmented bars,
  biggest folders (top 5), duplicate waste, trash size, and free space
  on the device when it can be read.
- **Trash** — deleted items kept 30 days with restore, then permanently
  deleted.
- **Locked folder** — PIN-protected (4 digits, stored only on-device as a
  hash). Items are hidden from the main grid and the system gallery.
  There is no PIN reset — no account, no cloud.
- **Light edit** — crop (preset ratios), straighten, rotate. Saved as a new
  copy; the original is never touched. No filters, no AI, natural look.
- **16:9 collage maker** — pick 2–6 photos, choose a layout, export one
  16:9 image to the gallery.
- **Memories / On this day** — photos from the same date in past years,
  with a slideshow mode.
- **Themes** — a custom "Moss" theme (organic, soft, nature-inspired;
  system fonts only, no downloads) in six flavours — Moss Emerald,
  Forest, Dusk, Sand, Midnight, Meadow — each with light and dark, plus
  an AMOLED black mode. Pick in Profile; the mode cycle button stays in
  the AppBar.
- **Floating nav** — Photos | Albums | Search | Profile in a floating
  pill dock; page content scrolls underneath it. All screen transitions
  are a shared fade + slight slide (280ms).

## Tech

Flutter, `photo_manager` for device media, `provider` for state,
`shared_preferences` + local JSON files for favourites / trash / locked
metadata, `share_plus` for the system share sheet, `image` for edits and
collage export, `video_player` for video playback,
`flutter_staggered_grid_view` for the varied tile layout,
`flutter_launcher_icons` for the launcher icon (generated from
`assets/logo.png`, drawn with `tool/make_logo.py` — no stock images).

Everything is stored locally: favourites in SharedPreferences; trash and
locked files in the app's private documents folder. Free-space reading is
a tiny platform channel in `MainActivity` (`StatFs`, no network).

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug      # debug APK
flutter build apk --release    # release APK (signed with debug keys for now)
```

Package: `com.moss.gallery`. The manifest deliberately has **no**
`INTERNET` permission. Media permissions: `READ_MEDIA_IMAGES` /
`READ_MEDIA_VIDEO` (Android 13+) and `READ_EXTERNAL_STORAGE` (older).
