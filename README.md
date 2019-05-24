# ffcache

[![pub package](https://img.shields.io/pub/v/ffcache.svg)](https://pub.dartlang.org/packages/ffcache)

ffcache(Flutter File Cache) is a file based key value store. It stores cache in iOS/Android app's temporary folder. Cache automatically expires after expiration time.

## API

### Constructors

`FFCache()` uses '$tempdir/ffcache' directory for cache.

`FFCache({String name})` uses '$tempdir/$name' directory for cache.


### Methods

`Future<void> init()` Initialize cache.  Most methods call init() internally if it's not initialized.

`Future<void> setString(String key, String value)` stores (key, string) pair. cache expires after FFCache.defaultTimeout (1 day).

`Future<void> setStringWithTimeout(String key, String value, Duration timeout)` stores (key, string) pair. cache expires after timeout.

`Future<String> getString(String key)` retrieves string value for key.

`Future<void> setBytes(String key, List<int> value)` stores (key, bytes) pair with default timeout.

`Future<void> setBytesWithTimeout(String key, List<int> value, Duration timeout)` stores (key, bytes) pair with timeout.

`Future<List<int>> getBytes(String key)` retrieves bytes for key.

`Future<void> setJSON(String key, dynamic value)` stores (key, json) pair with default timeout.

`Future<void> setJSONWithTimeout(String key, dynamic value, Duration timeout)` stores (key, json) pair with timeout.

`Future<dynamic> getJSON(String key)` retrieves json for key.

`Future<bool> has(key)` checks for existence of key.

`Future<bool> remove(key)` removes key from cache. returns true if key existed and removed.

`Future<void> clear()` removes all pairs from cache.


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




## How it works
Cache files are stored in the temporary directory of the app. It uses path_provider's getTemporaryDirectory(). Files in temporary directory can be deleted by the OS at any time. So, FFCache is not for general purpose key value store.

Old cache entries are deleted when FFCache is initialized. By default, cache expires after 1 day.



