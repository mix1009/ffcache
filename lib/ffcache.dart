library ffcache;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_shim.dart';

const _default_name = 'ffcache';
const _ffcache_filename = '_ffcache.json';
const _save_map_after = Duration(seconds: 1);
const _defaultTimeoutDuration = Duration(days: 1);

Map<String, FFCache> _ffcaches = {};

class FFCache {
  /// Returns a FFCache object.
  ///
  /// FFCache objects are created and managed internally. FFCache objects are created only once for each [name].
  ///
  /// Cache files are stored in temporary_directory/[name] (default: ffcache).
  /// Cache entries expires after [defaultTimeout] (default: 1 day).
  /// ffcache uses _ffcache.json to store internal information. If you try to use '_ffcache.json' as key, it will through an Exception.
  factory FFCache(
      {String name = _default_name,
      Duration defaultTimeout = _defaultTimeoutDuration,
      bool debug = false}) {
    final cache = _ffcaches[name];
    if (cache != null) {
      cache._debug = debug;
      cache._defaultTimeout = defaultTimeout;
      return cache;
    } else {
      final newCache = FFCache._(name, debug, defaultTimeout);
      _ffcaches[name] = newCache;
      return newCache;
    }
  }

  FFCache._(this._name, this._debug, this._defaultTimeout);

  // _name(name), _debug(debug), _defaultTimeout(defaultTimeout);

  String _name;
  bool _debug;
  Duration _defaultTimeout;
  late String _basePath;
  Map<String, int> _timeoutMap = {};
  Timer? _saveTimer;

  bool _initialized = false;
  Database? _db;

  /// Initialize ffcache.
  ///
  /// This method is called internally from set/get/remove methods if init() was not called.
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _basePath = _name;

      if (_debug) {
        print("FFCache: use idb_shim!");
      }
      final idbFactory = getIdbFactory();
      // open the database
      _db = await idbFactory!.open("$_basePath.db", version: 1,
          onUpgradeNeeded: (VersionChangeEvent event) {
        Database db = event.database;
        // db.createObjectStore(storeName, autoIncrement: true);
        db.createObjectStore(_basePath);
      });

      // load _timeoutMap
      try {
        final val = await _readString(_ffcache_filename);
        if (val != null) {
          final data = json.decode(val);

          for (final k in data.keys) {
            _timeoutMap[k] = data[k];
          }
        }
      } catch (_) {}

      // delete old entries (not tested)
      Map<String, int> _newTimeoutMap = {};

      if (_db != null)
        try {
          var txn = _db!.transaction(_basePath, idbModeReadOnly);
          var store = txn.objectStore(_basePath);
          var keys = await store.getAllKeys();
          await txn.completed;

          for (final keyObject in keys) {
            final key = keyObject as String;
            if (key == _ffcache_filename) {
              continue;
            }
            if (remainingDurationForKey(key).isNegative) {
              if (_debug) {
                print('  $key : delete');
              }
              var txn2 = _db!.transaction(_basePath, idbModeReadWrite);
              var store2 = txn.objectStore(_basePath);
              await store2.delete(key);
              await txn2.completed;
            } else {
              if (_debug) {
                print('  $key : cache ok');
              }
              final val = _timeoutMap[key];
              if (val != null) {
                _newTimeoutMap[key] = val;
              }
            }
          }
        } catch (_) {}

      _timeoutMap = _newTimeoutMap;
      await _saveMap();
    } else {
      final tempDir = await getTemporaryDirectory();
      _basePath = tempDir.path + '/$_name';

      await Directory(_basePath).create(recursive: true);

      if (_debug) {
        print("FFCache path: $_basePath");
      }

      try {
        final data = json
            .decode(await File('$_basePath/$_ffcache_filename').readAsString());

        for (final k in data.keys) {
          _timeoutMap[k] = data[k];
        }
      } catch (_) {}

      Map<String, int> _newTimeoutMap = {};

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
            await entity.delete(recursive: false);
          } else {
            if (_debug) {
              print('  $filename : cache ok');
            }
            final val = _timeoutMap[filename];
            if (val != null) {
              _newTimeoutMap[filename] = val;
            }
          }
        }
      } catch (_) {}

      _timeoutMap = _newTimeoutMap;
      await _saveMap();
    }

    _initialized = true;
  }

  Future<String> _pathForKey(String key) async {
    if (!_initialized) {
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
    await setStringWithTimeout(key, value, _defaultTimeout);
  }

  /// get string value for key.
  ///
  /// if cache entry is expired or not found, returns null.
  Future<String?> getString(String key) async {
    if (!_initialized) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }
    return await _readString(key);
  }

  Future<void> _writeString(String key, String value) async {
    if (kIsWeb) {
      if (_db == null) return;
      var txn = _db!.transaction(_basePath, idbModeReadWrite);
      var store = txn.objectStore(_basePath);
      await store.put([value, DateTime.now()], key);
      await txn.completed;
    } else {
      await File(await _pathForKey(key)).writeAsString(value);
    }
  }

  Future<String?> _readString(String key) async {
    if (kIsWeb) {
      if (_db == null) return null;
      var txn = _db!.transaction(_basePath, idbModeReadOnly);
      var store = txn.objectStore(_basePath);
      var obj = await store.getObject(key);
      await txn.completed;
      if (obj == null) return null;
      var vt = obj as List;
      return vt[0] as String;
    } else {
      final filePath = await _pathForKey(key);

      if (await FileSystemEntity.type(filePath) !=
          FileSystemEntityType.notFound) {
        return File(filePath).readAsString();
      } else {
        return null;
      }
    }
  }

  Future<void> _writeBytes(String key, List<int> bytes) async {
    if (kIsWeb) {
      if (_db == null) return;
      var txn = _db!.transaction(_basePath, idbModeReadWrite);
      var store = txn.objectStore(_basePath);
      await store.put([bytes, DateTime.now()], key);
      await txn.completed;
    } else {
      await File(await _pathForKey(key)).writeAsBytes(bytes);
    }
  }

  /// store (key, stringValue) pair. cache expires after timeout.
  Future<void> setStringWithTimeout(
      String key, String value, Duration timeout) async {
    await _writeString(key, value);
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
      _saveTimer!.cancel();
    }

    _saveTimer = Timer(_save_map_after, () async {
      if (!_initialized) {
        await init();
      }
      String value = json.encode(_timeoutMap);
      if (kIsWeb) {
        await _writeString(value, _ffcache_filename);
      } else {
        await File('$_basePath/$_ffcache_filename').writeAsString(value);
      }
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
  Future<Duration?> ageForKey(String key) async {
    if (remainingDurationForKey(key).isNegative) {
      return null;
    }

    if (kIsWeb) {
      // not tested
      var txn = _db!.transaction(_basePath, idbModeReadOnly);
      var store = txn.objectStore(_basePath);
      var obj = await store.getObject(key);
      await txn.completed;
      if (obj == null) return null;
      var value = obj as List;

      return DateTime.now().difference(value[1] as DateTime);
    } else {
      final filepath = await _pathForKey(key);
      final file = File(filepath);
      if (await file.exists()) {
        final modified = await file.lastModified();
        return DateTime.now().difference(modified);
      } else {
        return null;
      }
    }
  }

  /// store (key, jsonData) pair. cache expires after defaultTimeout.
  ///
  /// jsonData is converted to string using json.encode and stored as (JSON) String.
  Future<void> setJSON(String key, dynamic data) async {
    await setJSONWithTimeout(key, data, _defaultTimeout);
  }

  /// store (key, jsonData) pair. cache expires after timeout.
  ///
  /// jsonData is converted to string using json.encode and stored as (JSON) String.
  Future<void> setJSONWithTimeout(
      String key, dynamic data, Duration timeout) async {
    String value = json.encode(data);
    await _writeString(key, value);
    await _setTimeout(key, timeout);
  }

  /// get JSON value for key.
  ///
  /// stored JSON string is converted to dynamic using json.decode.
  /// if cache entry is expired or not found, returns null.
  Future<dynamic> getJSON(String key) async {
    if (!_initialized) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }

    final val = await _readString(key);

    if (val != null) {
      return json.decode(val);
    } else {
      return null;
    }
  }

  /// store (key, bytes) pair. cache expires after defaultTimeout.
  Future<void> setBytes(String key, List<int> bytes) async {
    await setBytesWithTimeout(key, bytes, _defaultTimeout);
  }

  /// store (key, bytes) pair. cache expires after timeout.
  Future<void> setBytesWithTimeout(
      String key, List<int> bytes, Duration timeout) async {
    await _writeBytes(key, bytes);
    await _setTimeout(key, timeout);
  }

  /// get bytes(List<int>) for key.
  ///
  /// if cache entry is expired or not found, returns null.
  Future<List<int>?> getBytes(String key) async {
    if (!_initialized) {
      await init();
    }
    final timeout = remainingDurationForKey(key);
    if (timeout.isNegative) {
      return null;
    }

    if (kIsWeb) {
      if (_db == null) return null;
      var txn = _db!.transaction(_basePath, idbModeReadOnly);
      var store = txn.objectStore(_basePath);
      var value = await store.getObject(key) as List;
      await txn.completed;
      List<dynamic> dynList = value[0];
      return dynList.cast<int>();
    } else {
      final filePath = await _pathForKey(key);

      if (await FileSystemEntity.type(filePath) !=
          FileSystemEntityType.notFound) {
        return File(filePath).readAsBytes();
      } else {
        return null;
      }
    }
  }

  /// remove cache entry for key
  ///
  /// returns true if key existed and was removed. returns false if key did not exists.
  Future<bool> remove(String key) async {
    if (!_initialized) {
      await init();
    }
    _timeoutMap.remove(key);
    await _saveMap();

    if (kIsWeb) {
      if (_db == null) return false;
      var txn = _db!.transaction(_basePath, idbModeReadWrite);
      var store = txn.objectStore(_basePath);
      await store.delete(key);
      await txn.completed;
      return true;
    } else {
      final filePath = await _pathForKey(key);

      if (await FileSystemEntity.type(filePath) !=
          FileSystemEntityType.notFound) {
        await File(filePath).delete();
        return true;
      } else {
        return false;
      }
    }
  }

  /// check if cache entry for key exist.
  Future<bool> has(String key) async {
    if (!_initialized) {
      await init();
    }

    if (remainingDurationForKey(key).isNegative) {
      return false;
    }

    if (kIsWeb) {
      final txn = _db?.transaction(_basePath, idbModeReadOnly);
      final store = txn?.objectStore(_basePath);
      final value = await store?.getObject(key);
      await txn?.completed;
      return value != null;
    } else {
      return await FileSystemEntity.type(await _pathForKey(key)) !=
          FileSystemEntityType.notFound;
    }
  }

  /// remove all cache entries.
  Future<void> clear() async {
    if (!_initialized) {
      await init();
    }

    if (kIsWeb) {
      if (_db != null) {
        _db!.close();
      }
      final idbFactory = getIdbFactory();

      await idbFactory!.deleteDatabase("$_basePath.db");
      _db = await idbFactory.open("$_basePath.db", version: 1,
          onUpgradeNeeded: (VersionChangeEvent event) {
        Database db = event.database;
        db.createObjectStore(_basePath);
      });
    } else {
      await Directory(_basePath).delete(recursive: true);
      await Directory(_basePath).create(recursive: true);
    }

    _timeoutMap.clear();

    await _saveMap();
  }
}
