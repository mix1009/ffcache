library ffcache;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _default_directory = 'ffcache';
const _ffcache_filename = '_ffcache.json';
const _save_map_after = Duration(seconds: 1);

Map<String, FFCache> _ffcaches = {};

class FFCache {
  factory FFCache.globalCache() {
    return FFCache(_default_directory);
  }

  factory FFCache(String name) {
    final cache = _ffcaches[name];
    if (cache != null) {
      return cache;
    } else {
      final newCache = FFCache._constructor(name);
      _ffcaches[name] = newCache;
      return newCache;
    }
  }

  FFCache._constructor(String name) {
    _name = name;
  }

  String _name;
  String _basePath;
  Map<String, int> _timeoutMap = {};
  Duration defaultTimeout = Duration(days: 1);
  Timer saveTimer;

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
        print(filename);
        if (filename == _ffcache_filename) {
          continue;
        }
        if (ageForKey(filename).isNegative) {
          print('  delete $filename');
          entity.deleteSync(recursive: false);
        } else {
          print('  file ok $filename');
        }
      }
    } catch (_) {}
  }

  Future<String> _pathForKey(String key) async {
    if (_basePath == null) {
      await init();
    }
    key = key.replaceAll('/', '-');
    return '$_basePath/$key';
  }

  Future<void> setString(String key, String value) async {
    await setStringWithTimeout(key, value, defaultTimeout);
  }

  Future<String> getString(String key) async {
    final timeout = ageForKey(key);
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
    if (saveTimer != null) {
      saveTimer.cancel();
    }

    saveTimer = Timer(_save_map_after, () async {
      print('saving ffcache.json');
      String value = json.encode(_timeoutMap);
      await File(await _pathForKey(_ffcache_filename)).writeAsString(value);
      saveTimer = null;
    });
  }

  Duration ageForKey(String key) {
    final expireDate = _timeoutMap[key];
    if (expireDate == null) {
      return Duration(milliseconds: -1);
    }
    return Duration(
        milliseconds: expireDate - DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setJSON(String key, dynamic data) async {
    await setJSONWithTimeout(key, data, defaultTimeout);
  }

  Future<void> setJSONWithTimeout(
      String key, dynamic data, Duration timeout) async {
    String value = json.encode(data);
    await File(await _pathForKey(key)).writeAsString(value);
    await _setTimeout(key, timeout);
  }

  Future<dynamic> getJSON(String key) async {
    final timeout = ageForKey(key);
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

  Future<void> setBytes(String key, List<int> bytes) async {
    await setBytesWithTimeout(key, bytes, defaultTimeout);
  }

  Future<void> setBytesWithTimeout(
      String key, List<int> bytes, Duration timeout) async {
    await File(await _pathForKey(key)).writeAsBytes(bytes);
    await _setTimeout(key, timeout);
  }

  Future<List<int>> getBytes(String key) async {
    final timeout = ageForKey(key);
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

  Future<bool> remove(String key) async {
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

  Future<bool> has(String key) async {
    if (ageForKey(key).isNegative) {
      return false;
    }

    return FileSystemEntity.typeSync(await _pathForKey(key)) !=
        FileSystemEntityType.notFound;
  }

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
