import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:ffcache/ffcache.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFCache Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
          appBar: AppBar(title: Text('FFCache Demo')), body: FFCacheTestPage()),
    );
  }
}

class FFCacheTestPage extends StatefulWidget {
  FFCacheTestPage({Key? key}) : super(key: key);

  @override
  _FFCacheTestPageState createState() => _FFCacheTestPageState();
}

class _FFCacheTestPageState extends State<FFCacheTestPage> {
  void testFFCacheSaved() async {
    final cache = FFCache(name: 'test');
    await cache.init();

    if (!await cache.has('key1')) {
      await cache.setString('key1', 'test');
    }
    if (!await cache.has('key2')) {
      await cache.setStringWithTimeout('key2', 'test', Duration(seconds: 60));
    }
    if (!await cache.has('key3')) {
      await cache.setStringWithTimeout('key3', 'test', Duration(hours: 10));
    }

    print(cache.remainingDurationForKey('key1'));
    print(cache.remainingDurationForKey('key2'));
    print(cache.remainingDurationForKey('key3'));

    print(await cache.ageForKey('key1'));
  }

  void testFFCache() async {
    final cache = FFCache(debug: true);

    await cache.clear();

    // test setString & getString
    {
      final value = 'value';
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
      List<int> bytes = utf8.encode(str);

      await cache.setBytes('bytes', bytes);
      final rBytes = await cache.getBytes('bytes');
      assert(ListEquality().equals(bytes, rBytes));
    }

    {
      final jsonData = json.decode(
          '''[{"id":1,"data":"string data","nested":{"id":"hello","flutter":"rocks"}}]''');
      await cache.setJSON('json', jsonData);

      final rJsonData = await cache.getJSON('json');
      assert(jsonData.toString().compareTo(rJsonData.toString()) == 0);
    }

    {
      final willExpireKey = 'willexpirekey';
      await cache.setStringWithTimeout(
          willExpireKey, 'value', Duration(milliseconds: 100));

      assert(!cache.remainingDurationForKey(willExpireKey).isNegative);

      // sleep(Duration(milliseconds: 150)); // doesn't work on web
      await Future.delayed(const Duration(milliseconds: 150));

      assert(cache.remainingDurationForKey(willExpireKey).isNegative);

      assert(await cache.getString(willExpireKey) == null);
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("testFFCache() passed all asserts. Everything went ok."),
      backgroundColor: Colors.blue,
    ));
  }

  // void test2() async {
  //   final cache = FFCache(debug: true);
  //   await cache.init();
  //   await cache.setString('test1', 'aaa');
  //   await cache.setString('test2', 'bbb');
  //   await cache.setString('test3', 'ccc');
  // }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            child: Text("test FFCache"),
            onPressed: testFFCache,
          ),
          // RaisedButton(
          //   child: Text("test 2"),
          //   onPressed: test2,
          // ),
        ],
      ),
    );
  }
}
