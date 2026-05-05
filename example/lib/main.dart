import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ffcache/ffcache.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFCache Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('FFCache Demo')),
        body: const FFCacheTestPage(),
      ),
    );
  }
}

class FFCacheTestPage extends StatefulWidget {
  const FFCacheTestPage({super.key});

  @override
  State<FFCacheTestPage> createState() => _FFCacheTestPageState();
}

class _FFCacheTestPageState extends State<FFCacheTestPage> {
  void testFFCacheSaved() async {
    final cache = FFCache(name: 'test');
    await cache.init();

    if (!await cache.has('key1')) {
      await cache.setString('key1', 'test');
    }
    if (!await cache.has('key2')) {
      await cache.setStringWithTimeout(
          'key2', 'test', const Duration(seconds: 60));
    }
    if (!await cache.has('key3')) {
      await cache.setStringWithTimeout(
          'key3', 'test', const Duration(hours: 10));
    }

    debugPrint('${cache.remainingDurationForKey('key1')}');
    debugPrint('${cache.remainingDurationForKey('key2')}');
    debugPrint('${cache.remainingDurationForKey('key3')}');
    debugPrint('${await cache.ageForKey('key1')}');
  }

  void testFFCache() async {
    final cache = FFCache(debug: true);

    await cache.clear();

    // test setString & getString
    {
      const value = 'value';
      await cache.setString('key', value);
      final retValue = await cache.getString('key');
      assert(retValue == 'value');
    }

    // getString return null if not found
    {
      final retValue = await cache.getString('unknownkey');
      assert(retValue == null);
    }

    {
      assert(await cache.has('key') == true);
      assert(await cache.remove('key') == true);
      assert(await cache.has('key') == false);
    }

    {
      final str = 'string data';
      final bytes = utf8.encode(str);

      await cache.setBytes('bytes', bytes);
      final rBytes = await cache.getBytes('bytes');
      assert(listEquals(bytes, rBytes));
    }

    {
      final jsonData = json.decode(
          '''[{"id":1,"data":"string data","nested":{"id":"hello","flutter":"rocks"}}]''');
      await cache.setJSON('json', jsonData);

      final rJsonData = await cache.getJSON('json');
      assert(jsonData.toString().compareTo(rJsonData.toString()) == 0);
    }

    {
      const willExpireKey = 'willexpirekey';
      await cache.setStringWithTimeout(
          willExpireKey, 'value', const Duration(milliseconds: 100));

      assert(!cache.remainingDurationForKey(willExpireKey).isNegative);

      await Future.delayed(const Duration(milliseconds: 150));

      assert(cache.remainingDurationForKey(willExpireKey).isNegative);
      assert(await cache.getString(willExpireKey) == null);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('testFFCache() passed all asserts. Everything went ok.'),
      backgroundColor: Colors.blue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            onPressed: testFFCache,
            child: const Text('test FFCache'),
          ),
        ],
      ),
    );
  }
}
