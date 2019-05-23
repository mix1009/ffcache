import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:ffcache/ffcache.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'FFCache Demo'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  void _testFFCacheSaved() async {
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

  void _testFFCache() async {
    final cache = FFCache();

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
      await cache.setStringWithTimeout(
          'key', 'value', Duration(milliseconds: 500));
      await cache.setStringWithTimeout('key2', 'value', Duration(seconds: 500));

      final dur = cache.remainingDurationForKey('key');
      print(dur);

      sleep(Duration(milliseconds: 600));

      assert(cache.remainingDurationForKey('key').isNegative);

      assert(await cache.getString('key') == null);

      print(cache.remainingDurationForKey('key2'));
    }

    print("if you didn't see assert errors, everything went ok.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
          child: RaisedButton(
        child: Text("press to test"),
        onPressed: _testFFCache,
      )),
    );
  }
}
