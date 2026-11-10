import 'package:flutter/services.dart';

/// Local notifications — fully offline, no server, no analytics.
///
/// Implemented with a tiny native channel in MainActivity (Android
/// NotificationManager, framework APIs only — deliberately NOT the
/// flutter_local_notifications plugin: v23 needs AGP 9.1.1 + compileSdk
/// 37, neither of which this sandbox's Gradle can fetch, see AGENTS.md).
///
/// Only completion/failure events, never routine pings:
///   * duplicate scan finished (with counts found)
///   * collage / edited photo exported and saved
///   * photo library failed to load (so a silent blank screen is
///     impossible — the user gets told)
///
/// Notification permission is asked at the moment it is first needed
/// (the first time one of these events fires), never at first launch.
/// On Android 12 and older notifications are on by default, so nothing
/// is asked at all. Everything is guarded: if notifications are
/// unavailable (or denied) the app just carries on silently.
class MossNotifications {
  MossNotifications._();

  static final MossNotifications _instance = MossNotifications._();

  factory MossNotifications() => _instance;

  static const _channel = MethodChannel('moss.notifications');

  bool _permissionAsked = false;

  /// Asks for notification permission the first time a notification is
  /// actually needed. Returns false when notifications cannot be shown.
  Future<bool> _ensurePermission() async {
    if (_permissionAsked) return true;
    _permissionAsked = true;
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final ok = await _ensurePermission();
      if (!ok) return;
      await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  Future<void> showScanComplete({
    required int groups,
    required int similar,
    required int blurry,
  }) =>
      _show(
        id: 1,
        title: 'Duplicate scan finished',
        body: '$groups duplicate groups, $similar similar, '
            '$blurry possibly blurry',
      );

  Future<void> showExportSaved(String what) => _show(
        id: 2,
        title: '$what saved',
        body: '$what was saved to your gallery.',
      );

  Future<void> showLibraryLoadFailed(String detail) => _show(
        id: 3,
        title: "Moss couldn't load your photos",
        body: detail,
      );
}
