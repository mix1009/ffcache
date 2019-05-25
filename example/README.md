# FFCache test project

Two buttons run test for FFCache and FFCacheSync. If something fails, you will get an assert error.

## FFCache

```

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
  }
```

## FFCacheSync

FFCacheSync is synchronous version of FFCache. FFCacheSync.getInstance is the only async method.

```
  void testFFCacheSync() async {
    final cache = await FFCacheSync.getInstance(debug: true);

    cache.clear();

    // test setString & getString
    {
      final value = 'value';
      cache.setString('key', value);
      final retValue = cache.getString('key');
      assert(retValue == 'value');
    }

    // getString return null if not found
    {
      final retValue = cache.getString('unknownkey');
      assert(retValue == null);
    }

    {
      assert(cache.has('key') == true);
      assert(cache.remove('key') == true);
      assert(cache.has('key') == false);
    }

    {
      final str = 'string data';
      List<int> bytes = utf8.encode(str);

      cache.setBytes('bytes', bytes);
      final rBytes = cache.getBytes('bytes');
      assert(ListEquality().equals(bytes, rBytes));
    }

    {
      final jsonData = json.decode(
          '''[{"id":1,"data":"string data","nested":{"id":"hello","flutter":"rocks"}}]''');
      cache.setJSON('json', jsonData);

      final rJsonData = cache.getJSON('json');
      assert(jsonData.toString().compareTo(rJsonData.toString()) == 0);
    }

    {
      cache.setStringWithTimeout('key', 'value', Duration(milliseconds: 500));
      cache.setStringWithTimeout('key2', 'value', Duration(seconds: 500));

      final dur = cache.remainingDurationForKey('key');
      print(dur);

      sleep(Duration(milliseconds: 600));

      assert(cache.remainingDurationForKey('key').isNegative);

      assert(cache.getString('key') == null);

      print(cache.remainingDurationForKey('key2'));
    }
  }
```