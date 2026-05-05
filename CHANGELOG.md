## [1.1.1] - 2026/05/05

* Updated Dart SDK constraint to >=3.0.0 <4.0.0.
* Updated `idb_shim` to ^2.9.1.
* Updated `path_provider` to ^2.1.5.
* Modernized Android example build configuration to AGP 8.12.0 / Gradle 8.13.
* Fixed lint warnings: renamed constants to lowerCamelCase style.
* Fixed bug: `_saveMap` was writing args in wrong order on web.
* Fixed bug: `clear()` on web was using wrong txn object for delete.
* Added `flutter_lints` dev dependency.

## [1.1.0] - 2021/10/26

* support for web platform

## [1.0.0] - 2021/03/09

* add null safety.

## [0.1.3] - 2019/05/26

* fix consistency issue when cache files are deleted externally.
* use async file methods when possible.
* update example project & documentation.

## [0.1.2] - 2019/05/24

* add example project
* fix issue when ffcache is not initialized.

## [0.1.1] - 2019/05/24

* add optional parameter for constructor. Duration defaultTimeout & bool debug.
* add API documentation to source code.
* saveTimer property changed to private

## [0.1.0] - 2019/05/23

* initial release
