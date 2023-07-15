import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_storage/get_storage.dart';

///
/// A Dart utility which helps you manage the communication between Firebase Storage and you app.
/// It natively implements a low dependencies cache to save time and computational costs.
///
class CachedFirestorage {
  static late GetStorage _storageInstance;
  static late CachedFirestorage instance;
  Map<String, String> _storageKeys = {'default': 'default'};
  int cacheTimeout;

  CachedFirestorage._(this.cacheTimeout);

  static Future<void> init() async {
    await GetStorage.init();
    _storageInstance = GetStorage();
    instance = CachedFirestorage._(360);
  }

  /// Sets the storage keys
  void setStorageKeys(Map<String, String> keys) {
    assert(
      !keys.keys.contains('default'),
      'The default key is automatically set',
    );
    _storageKeys = {..._storageKeys, ...keys};
  }

  /// Private method
  Future<String> _getDownloadURL(
    String filePath, {
    String? fallbackFilePath,
  }) async {
    try {
      return await FirebaseStorage.instance.ref(filePath).getDownloadURL();
    } catch (_) {
      if (fallbackFilePath == null) {
        return '';
      }

      try {
        return await FirebaseStorage.instance
            .ref(fallbackFilePath)
            .getDownloadURL();
      } catch (__) {
        return '';
      }
    }
  }

  /// Gets Firebase Storage download URL and stores it into a cache
  Future<String> getDownloadURL({
    required String mapKey,
    required String filePath,
    String? storageKey,
    String? fallbackFilePath,
  }) async {
    assert(storageKey == null || _storageKeys.containsKey(storageKey));

    final Map<String, dynamic> mapDownloadURLs =
        _storageInstance.read(_storageKeys[storageKey ?? 'default']!) ?? {};
    final DateTime now = DateTime.now();

    if (mapDownloadURLs[mapKey] != null) {
      final DateTime lastWrite = DateTime.parse(
        mapDownloadURLs[mapKey]['lastWrite'],
      );
      final int difference = now.difference(lastWrite).inMinutes;
      if (difference < cacheTimeout) {
        return mapDownloadURLs[mapKey]['value'];
      }
    }

    final String downloadURL = await _getDownloadURL(
      filePath,
      fallbackFilePath: fallbackFilePath,
    );

    mapDownloadURLs[mapKey] = {
      'value': downloadURL,
      'lastWrite': now.toIso8601String(),
    };

    _storageInstance.write(
      _storageKeys[storageKey ?? 'default']!,
      mapDownloadURLs,
    );

    return downloadURL;
  }

  /// Deletes a cache entry
  void removeCacheEntry({
    required String mapKey,
    String? storageKey,
  }) {
    final Map<String, dynamic> mapDownloadURLs =
        _storageInstance.read(_storageKeys[storageKey ?? 'default']!) ?? {};

    if (mapDownloadURLs[mapKey] != null) {
      mapDownloadURLs.remove(mapKey);
      _storageInstance.write(
        _storageKeys[storageKey ?? 'default']!,
        mapDownloadURLs,
      );
    }
  }
}
