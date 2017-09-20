import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:build/build.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart';
import 'package:sass/sass.dart';

final _packageNameRegExp = new RegExp('package:([^\/]*)\/');
final _packagePathRegExp = new RegExp('package:[^\/]*\/(.*)');
final _importBlockRegExp = new RegExp('@import ([^;]*);');
final _fileNameRegExp = new RegExp('(?:\'|\")([^\'\"]*)(?:\'|\")');

/// A `Builder` to compile .css files from .scss source using dart-sass.
///
/// NOTE: Because Sass requires reading from the disk this `Builder` copies all
/// `Assets` to a temporary directory with a structure similar to that defined
/// in `.packages`. Sass will read from the temporary directory when compiling.
class SassBuilder extends Builder {
  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;

    if (basename(inputId.path).startsWith('_')) {
      // Do not produce any output for .scss partials.
      return;
    }

    // Copy all this asset and all imported assets to the temp directory.
    var tempDir = await Directory.systemTemp.createTemp();
    await _readAndCopyImports(inputId, buildStep, tempDir);

    try {
      // Compile the css.
      var tempAssetPath = join(tempDir.path, inputId.package, inputId.path);
      var cssOutput = compile(tempAssetPath,
          packageResolver: _tempDirPackageResolver(tempDir));

      // Write the builder output
      buildStep.writeAsString(inputId.addExtension('.css'), '${cssOutput}\n');
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  @override
  final buildExtensions = const {
    '.scss': const ['.scss.css']
  };

  // Reads all assets transitively from `id` and copies them to `tempDir`.
  //
  // Uses `buildStep to read the assets and standard file IO to write to the
  // temp directory.
  Future _readAndCopyImports(
      AssetId id, BuildStep buildStep, Directory tempDir) async {
    var copiedAssets = new Set<AssetId>();
    var assetsToCopy = new Queue<AssetId>();
    assetsToCopy.add(id);

    while (assetsToCopy.isNotEmpty) {
      id = assetsToCopy.removeFirst();

      if (!await buildStep.canRead(id)) {
        // Try same asset path except starting the filename with an underscore.
        id = new AssetId(
            id.package, join(dirname(id.path), '_${basename(id.path)}'));
      }

      if (!await buildStep.canRead(id)) {
        // Only copy imports that are found. If there is a problem with a
        // missing file, let sass compilation fail and report it.
        continue;
      }
      var contents = await buildStep.readAsString(id);

      var tempAssetPath = join(tempDir.path, id.package, id.path);
      var fileCopy = await new File(tempAssetPath).create(recursive: true);
      await fileCopy.writeAsString(contents);
      copiedAssets.add(id);

      for (var importId in importedAssets(id, contents)) {
        if (!copiedAssets.contains(importId) &&
            !assetsToCopy.contains(importId)) {
          assetsToCopy.add(importId);
        }
      }
    }
  }

  /// Returns the `AssetId`s of all the transitive imports from `contents`.
  Iterable<AssetId> importedAssets(AssetId id, String contents) {
    // TODO(nshahan) Avoid reading imports in comments.
    // Reading imports in this manner can cause problems when trying to find
    // and break dependency cycles. If the import is commented out but the file
    // still exists this builder will still have a dependency on the asset even
    // though it is not used.
    var importedAssets = new Set<AssetId>();

    for (var importBlock in _importBlockRegExp.allMatches(contents)) {
      var imports = _fileNameRegExp.allMatches(importBlock.group(1));
      for (var import in imports) {
        importedAssets.add(new AssetId(
            _importPackage(import.group(1), id.package),
            _importPath(import.group(1), id.path)));
      }
    }

    return importedAssets;
  }

  // Returns a `SyncPackageResolver` for the packages in the `tempDir`.
  SyncPackageResolver _tempDirPackageResolver(Directory tempDir) {
    var packages = new Map<String, Uri>();
    for (FileSystemEntity dir in tempDir.listSync(followLinks: false)) {
      packages[basename(dir.path)] =
          dir.uri.replace(path: join(dir.path, 'lib'));
    }
    return new SyncPackageResolver.config(packages);
  }

  // Returns the package name parsed from the given `import` or defaults to
  // `currentPackage`.
  String _importPackage(String import, String currentPackage) =>
      import.startsWith('package:')
          ? _packageNameRegExp.firstMatch(import).group(1)
          : currentPackage;

  // Returns the path parsed from the given `import` or defaults to
  // locating the file in the `currentPath`.
  String _importPath(String import, String currentPath) {
    var path = import.startsWith('package:')
        ? join('lib', _packagePathRegExp.firstMatch(import).group(1))
        : join(dirname(currentPath), import);

    return path.endsWith('.scss') ? path : '$path.scss';
  }
}
