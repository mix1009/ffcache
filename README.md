# ffcache

[![pub package](https://img.shields.io/pub/v/ffcache.svg)](https://pub.dartlang.org/packages/ffcache)

ffcache(Flutter File Cache) is a file based key value store. It stores cache in iOS/Android app's temporary folder. Cache automatically expires after expiration time.

## Usage

Most methods are asynchronous. So you should use await from an async function.

```
void testFFCache() async {

  final cache = FFCache();

  // initialize. most methods call init() internally if not initialized.
  await cache.init();

  // insert 'key':'value' pair
  await cache.setString('key', 'value');

  // get value for 'key'
  final value = await cache.getString('key');

  // check if 'key' exists
  if (await cache.has('key')) {

    // remove cache for 'key'
    await cache.remove('key');
  }

  // cache expires after Duration.
  await cache.setStringWithTimeout('key', 'value', Duration(hours: 3));

  // remove all cache
  await cache.clear();

  // setBytes & getBytes
  {
    final str = 'string data';
    List<int> bytes = utf8.encode(str);

    await cache.setBytes('bytes', bytes);
    final rBytes = await cache.getBytes('bytes');
  }

  // setJSON & getJSON
  {
    final jsonData = json.decode('''[{"id":1,"data":"string data","nested":{"id":"hello","flutter":"rocks"}}]''');
    await cache.setJSON('json', jsonData);

    final rJsonData = await cache.getJSON('json');
  }
}
```


## API

Available from https://pub.dev/documentation/ffcache/latest/ffcache/FFCache-class.html

## How it works
Cache files are stored in the temporary directory of the app. It uses path_provider's getTemporaryDirectory(). Files in temporary directory can be deleted by the OS at any time. So, FFCache is not for general purpose key value store.

Old cache entries are deleted when FFCache is initialized. By default, cache expires after 1 day.



