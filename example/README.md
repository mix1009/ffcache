# FFCache test project

Tapping the button runs test for FFCache. If something fails, you will get an assert error.

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
      final willExpireKey = 'willexpirekey';
      await cache.setStringWithTimeout(
          willExpireKey, 'value', Duration(milliseconds: 100));

      assert(!cache.remainingDurationForKey(willExpireKey).isNegative);

      sleep(Duration(milliseconds: 150));

      assert(cache.remainingDurationForKey(willExpireKey).isNegative);

      assert(await cache.getString(willExpireKey) == null);
    }

    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text("testFFCache() passed all asserts. Everything went ok."),
      backgroundColor: Colors.blue,
    ));
  }
```