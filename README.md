# ffcache

[![pub package](https://img.shields.io/pub/v/ffcache.svg)](https://pub.dartlang.org/packages/ffcache)

Flutter File Cache is a file based simple key value store.




## Usage


```
    final cache = FFCache.globalCache();

```
`setString(key, value)` stores key value string pair.

`getString(key)` retrieves value for key.

`hasCacheForKey(key)` checks for existence of key.

`remove(key)` removes key from the cache.

`clear()` removes all pairs from the cache.


Most methods are asynchronous. So you should use await from an async function.

```
void testFFCache() async {

  final cache = FFCache.globalCache();

  // insert 'key':'value' pair
  await cache.setString('key', 'value');

  // get value for 'key'
  final value = await cache.getString('key');

  // check if 'key' exists
  if (await cache.hasCacheForKey('key')) {

    // remove cache for 'key'
    await cache.remove('key');
  }

  // remove all cache
  await cache.clear();

}

```

## How it works
Cached files are stored in the temporary directory of the app. It uses path_provider's TemporaryDirectory
Temporary directory can be deleted by the OS. So, FFCache is not fit for general purpose key value store.
Old cache entries are deleted when FFCache is initialized. By default, cache expires after 1 day.



## Getting Started

This project is a starting point for a Dart
[package](https://flutter.dev/developing-packages/),
a library module containing code that can be shared easily across
multiple Flutter or Dart projects.

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

