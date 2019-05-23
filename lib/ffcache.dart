library ffcache;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FFCache {
  factory FFCache.globalCache() {
    return FFCache('ffcache');
  }

  FFCache(String name) {
    _name = name;
  }

  String _name;
  String _basePath;
  Duration expiresAfter = Duration(days: 1);

  Future<void> _initCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    _basePath = tempDir.path + '/$_name';

    Directory(_basePath).createSync(recursive: true);

    final now = DateTime.now();

    try {
      final files =
          Directory(_basePath).listSync(recursive: false, followLinks: false);
      for (final entity in files) {
        final fstat = entity.statSync();
        final diff = now.difference(fstat.modified);
        if (diff.compareTo(expiresAfter) > 0) {
          entity.deleteSync(recursive: false);
        }
      }
    } catch (_) {}

    // try {
    //   Directory(_basePath)
    //       .list(recursive: false, followLinks: false)
    //       .listen((FileSystemEntity entity) {
    //     final fstat = entity.statSync();
    //     final diff = now.difference(fstat.modified);
    //     if (diff.compareTo(expiresAfter) > 0) {
    //       entity.deleteSync(recursive: false);
    //     }
    //   });
    // } catch (_) {}
  }

  Future<String> _pathForKey(String key) async {
    if (_basePath == null) {
      await _initCacheDirectory();
    }
    key = key.replaceAll('/', '-');
    return '$_basePath/$key';
  }

  Future<void> setString(String key, String value) async {
    await File(await _pathForKey(key)).writeAsString(value);
  }

  Future<String> getString(String key) async {
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return File(filePath).readAsString();
    } else {
      return null;
    }
  }

  Future<void> setJSON(String key, dynamic data) async {
    String value = json.encode(data);
    await File(await _pathForKey(key)).writeAsString(value);
  }

  Future<dynamic> getJSON(String key) async {
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return json.decode(await File(filePath).readAsString());
    } else {
      return null;
    }
  }

  Future<void> setBytes(String key, List<int> bytes) async {
    await File(await _pathForKey(key)).writeAsBytes(bytes);
  }

  Future<List<int>> getBytes(String key) async {
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      return File(filePath).readAsBytes();
    } else {
      return null;
    }
  }

  Future<bool> remove(String key) async {
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      File(filePath).deleteSync();
      return true;
    } else {
      return false;
    }
  }

  Future<bool> has(String key) async {
    return FileSystemEntity.typeSync(await _pathForKey(key)) !=
        FileSystemEntityType.notFound;

    // return false;
  }

  Future<void> clear() async {
    if (_basePath == null) {
      await _initCacheDirectory();
    }

    await Directory(_basePath).delete(recursive: true);
    await Directory(_basePath).create(recursive: true);
  }
}
