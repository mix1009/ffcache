library ffcache;

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FFCache {
  factory FFCache.globalCache() {
    return FFCache('globalCache');
  }

  FFCache(String name) {
    _name = name;
  }

  String _name;
  String _basePath;
  Duration timeoutInterval = Duration(days: 1);

  Future<void> _initCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    _basePath = tempDir.path + '/$_name';
    await Directory(_basePath).create(recursive: true);

    final now = DateTime.now();

    Directory(_basePath)
        .list(recursive: false, followLinks: false)
        .listen((FileSystemEntity entity) {
      final fstat = entity.statSync();
      final diff = now.difference(fstat.modified);
      if (diff.compareTo(timeoutInterval) > 0) {
        print('remove old cache: ${entity.path}');
        entity.deleteSync(recursive: false);
      }
      print('diff = $diff');
    });

    print('end of initCacheDirectory');
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

  Future<bool> remove(String key) async {
    final filePath = await _pathForKey(key);

    if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.notFound) {
      File(filePath).deleteSync();
      return true;
    } else {
      return false;
    }
  }

  Future<bool> hasCacheForKey(String key) async {
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

/*
void testFFCache() async {
  print('### testFFCache ###');
  final cache = FFCache.globalCache();

  await cache.setString('hello', 'world');
  // await cache.setString('world', 'world');
  // await cache.setString('hahaha', 'world');

  final val = await cache.getString('hello');

  print('val = $val');
  final uval = await cache.getString('worl');
  print('val = $uval');

  final bVal1 = await cache.hasCacheForKey('hello');
  print('bool = $bVal1');
  final bVal2 = await cache.hasCacheForKey('unknown');
  print('bool = $bVal2');

  final bVal3 = await cache.remove('unknown');
  print('remove1 = $bVal3');

  final bVal4 = await cache.remove('hahaha');
  print('remove2 = $bVal4');

  print('### testFFCache ///');
}
*/
