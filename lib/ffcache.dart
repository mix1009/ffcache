library ffcache;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _default_name = 'ffcache';
const _ffcache_filename = '_ffcache.json';
const _save_map_after = Duration(seconds: 1);
const _defaultTimeoutDuration = Duration(days: 1);

Map<String, FFCache> _ffcaches = {};

class FFCache {
  /// Returns a FFCache object.
  ///
  /// FFCache objects are created and managed internally. FFCache objects are creates only once for each [name].
  ///
  /// Cache files are stored in temporary_directory/[name] (default: ffcache).
  /// Cache entries expires after [defaultTimeout] (default: 1 day).
  /// ffcache uses _ffcache.json to store internal information. If you try to use '_ffcache.json' as key, it will through an Exception.
  factory FFCache({String name, Duration defaultTimeout, bool debug}) {
    name = name ?? _default_name;
    final cache = _ffcaches[name];
    if (cache != null) {
      if (debug != null) {
        cache._debug = debug;
      }
      if (defaultTimeout != null) {
        cache.defaultTimeout = defaultTimeout;
      }
      return cache;
    } else {
      debug = debug ?? false;
      defaultTimeout = defaultTimeout ?? _defaultTimeoutDuration;
      final newCache =
          FFCache._(name: name, debug: debug, defaultTimeout: defaultTimeout);
      _ffcaches[name] = newCache;
      return newCache;
    }
  }

  FFCache._({String name, bool debug, Duration defaultTimeout}) {
    _name = name;
    _debug = debug;
    this.defaultTimeout = defaultTimeout;
  }

  String _name;
  bool _debug;
  Duration defaultTimeout;
  String _basePath;
  Map<String, int> _timeoutMap = {};
  Timer _saveTimer;

  /// Initialize ffcache.
  ///
  /// This method is called internally from set/get/remove methods if init() was not called.
  Future<void> init() async {
    if (_basePath != null) return;

    final tempDir = await getTemporaryDirectory();
    _basePath = tempDir.path + '/$_name';

    Directory(_basePath).createSync(recursive: true);

    try {
      final data = json
          .decode(await File('$_basePath/$_ffcache_filename').readAsString());

      for (final k in data.keys) {
        _timeoutMap[k] = data[k];
      }
    } catch (_) {}

    // final now = DateTime.now();
    try {
      final files =
          Directory(_basePath).listSync(recursive: false, followLinks: false);
      for (final entity in files) {
        final filename = entity.path.split('/').last;
        if (filename == _ffcache_filename) {
          continue;
        }
        if (remainingDurationForKey(filename).isNegative) {
          if (_debug) {
            print('  $filename : delete');
          }
          entity.deleteSync(recursive: false);
        } else {
          if (_debug) {
            print('  $filename : cache ok');
          }
        }
      }
    } catch (_) {}
  }

  Future<String> _pathForKey(String key) async {
    if (_basePath == null) {
      await init();
    }
    key = key.replaceAll('/', '-');
    if (key == _ffcache_filename) {
      throw Exception('ffcache: key reserved for $_ffcache_filename');
    }
    return '$_basePath/$key';
  }

  /// store (key, stringValue) pair. cache expires after defaultTimeout.
  Future<void> setString(String key, String value) async {
    await setStringWithTimeout(key, value, defaultTimeout);
  }

  /// get string value for key.
  ///
  /// if cache entry is expired or not found, returns null.
  Future<String> getString(String key) async {
    if (_basePath == null) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return File(filePath).readAsString();
    } else {
      return null;
    }
  }

  /// store (key, stringValue) pair. cache expires after timeout.
  Future<void> setStringWithTimeout(
      String key, String value, Duration timeout) async {
    await File(await _pathForKey(key)).writeAsString(value);
    await _setTimeout(key, timeout);
  }

  Future<void> _setTimeout(String key, Duration timeout) async {
    if (timeout.isNegative) {
    } else {
      _timeoutMap[key] = DateTime.now().add(timeout).millisecondsSinceEpoch;

      await _saveMap();
    }
  }

  Future<void> _saveMap() async {
    if (_saveTimer != null) {
      _saveTimer.cancel();
    }

    _saveTimer = Timer(_save_map_after, () async {
      if (_basePath == null) {
        await init();
      }
      String value = json.encode(_timeoutMap);
      await File('$_basePath/$_ffcache_filename').writeAsString(value);
      _saveTimer = null;
      if (_debug) {
        print('saved $_ffcache_filename');
      }
    });
  }

  /// returns cache entry remaining duration for key.
  ///
  /// If cache entry is expired or does not exist, returns negative Duration. You can check Duration.isNegative to check if cache does not exist.
  Duration remainingDurationForKey(String key) {
    final expireDate = _timeoutMap[key];
    if (expireDate == null) {
      return Duration(milliseconds: -1);
    }
    return Duration(
        milliseconds: expireDate - DateTime.now().millisecondsSinceEpoch);
  }

  /// returns cache entry age (Duration since creation)
  ///
  /// If cache entry does not exist or expired, it returns null.
  Future<Duration> ageForKey(String key) async {
    if (remainingDurationForKey(key).isNegative) {
      return null;
    }
    final filepath = await _pathForKey(key);
    final file = File(filepath);
    if (file.existsSync()) {
      final modified = await file.lastModified();
      return DateTime.now().difference(modified);
    } else {
      return null;
    }
  }

  /// store (key, jsonData) pair. cache expires after defaultTimeout.
  ///
  /// jsonData is converted to string using json.encode and stored as (JSON) String.
  Future<void> setJSON(String key, dynamic data) async {
    await setJSONWithTimeout(key, data, defaultTimeout);
  }

  /// store (key, jsonData) pair. cache expires after timeout.
  ///
  /// jsonData is converted to string using json.encode and stored as (JSON) String.
  Future<void> setJSONWithTimeout(
      String key, dynamic data, Duration timeout) async {
    String value = json.encode(data);
    await File(await _pathForKey(key)).writeAsString(value);
    await _setTimeout(key, timeout);
  }

  /// get JSON value for key.
  ///
  /// stored JSON string is converted to dynamic using json.decode.
  /// if cache entry is expired or not found, returns null.
  Future<dynamic> getJSON(String key) async {
    if (_basePath == null) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return json.decode(await File(filePath).readAsString());
    } else {
      return null;
    }
  }

  /// store (key, bytes) pair. cache expires after defaultTimeout.
  Future<void> setBytes(String key, List<int> bytes) async {
    await setBytesWithTimeout(key, bytes, defaultTimeout);
  }

  /// store (key, bytes) pair. cache expires after timeout.
  Future<void> setBytesWithTimeout(
      String key, List<int> bytes, Duration timeout) async {
    await File(await _pathForKey(key)).writeAsBytes(bytes);
    await _setTimeout(key, timeout);
  }

  /// get bytes(List<int>) for key.
  ///
  /// if cache entry is expired or not found, returns null.
  Future<List<int>> getBytes(String key) async {
    if (_basePath == null) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }

    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return File(filePath).readAsBytes();
    } else {
      return null;
    }
  }

  /// remove cache entry for key
  ///
  /// returns true if key existed and was removed. returns false if key did not exists.
  Future<bool> remove(String key) async {
    if (_basePath == null) {
      await init();
    }
    _timeoutMap.remove(key);
    await _saveMap();

    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      File(filePath).deleteSync();
      return true;
    } else {
      return false;
    }
  }

  /// check if cache entry for key exist.
  Future<bool> has(String key) async {
    if (_basePath == null) {
      await init();
    }

    if (remainingDurationForKey(key).isNegative) {
      return false;
    }

    return FileSystemEntity.typeSync(await _pathForKey(key)) !=
        FileSystemEntityType.notFound;
  }

  /// remove all cache entries.
  Future<void> clear() async {
    if (_basePath == null) {
      await init();
    }

    await Directory(_basePath).delete(recursive: true);
    await Directory(_basePath).create(recursive: true);

    _timeoutMap.clear();

    await _saveMap();
  }
}
