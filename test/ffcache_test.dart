import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ffcache/ffcache.dart';

void main() {
  test('FFCache test', () async {
    final cache = FFCache.globalCache();

    await cache.clear();

    await cache.setString('hello', 'world');
    await cache.setString('a/b/c', 'value');

    expect(await cache.getString('hello'), 'world');
    expect(await cache.getString('a/b/c'), 'value');
    expect(await cache.getString('dontexist'), null);

    expect(await cache.has('hello'), true);
    expect(await cache.has('a/b/c'), true);
    expect(await cache.has('unknown'), false);

    expect(await cache.remove('hello'), true);
    expect(await cache.remove('dontexist'), false);
    expect(await cache.getString('hello'), false);

    List<int> bytes = utf8.encode("Some data");
    await cache.setBytes('bytes', bytes);
    expect(await cache.getBytes('bytes'), bytes);
  });
}
