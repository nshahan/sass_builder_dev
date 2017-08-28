import 'dart:async';
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
class SassBuilder extends Builder {

  @override
  Future build(BuildStep buildStep) async {
    var inputId = buildStep.inputId;

    // Do not produce any output for .scss partials.
    if (!basename(inputId.path).startsWith('_')) {
      var dependencies = new List<AssetId>();

      var tempDir = await Directory.systemTemp.createTemp();

      // Copy all this asset and all imported assets to the temp directory.
      var tempAssetPath =
          await readAndCopyImports(inputId, dependencies, buildStep, tempDir);

      if (tempAssetPath == null) {
        print('sass_builder Error. Unable to read: ${inputId.path}');
        throw new InvalidInputException(inputId);
      }

      // Compile the css.
      var tempPackageResolver = _tempDirPackgeResolver(tempDir);
      buildStep.writeAsString(inputId.addExtension('.css'),
          compile(tempAssetPath, packageResolver: tempPackageResolver));

      await tempDir.delete(recursive: true);
    }
  }

  @override
  final buildExtensions = const {
    '.scss': const ['.scss.css']
  };

  Future<String> readAndCopyImports(AssetId id, List<AssetId> dependencies,
      BuildStep buildStep, Directory tempDir) async {

    if (! await buildStep.canRead(id)) {
      // Try same asset path except starting the filename with an underscore.
      id = new AssetId(id.package, join(dirname(id.path), '_${basename(id.path)}'));
    }

    if (!dependencies.contains(id) && await buildStep.canRead(id)) {
      // Read the contents of the import with the Builder.
      var contents = await buildStep.readAsString(id);

      // Copy the file to the temp directory.
      var fileCopyName = join(tempDir.path, id.package, id.path);
      var fileCopy = await new File(join(tempDir.path, fileCopyName))
          .create(recursive: true);
      await fileCopy.writeAsString(contents);

      // Remember this file in case it is imported again.
      dependencies.add(id);

      // Recurse on all imports.
      for (var importId in importedAssets(id, contents)) {
        await readAndCopyImports(importId, dependencies, buildStep, tempDir);
      }

      return fileCopy.path;
    }

    // Was not able to read the root asset of the .scss imports
    return null;
  }

  /// Returns the `AssetId`s of all the transitive imports from `contents`.
  Iterable<AssetId> importedAssets(AssetId id, String contents) {
    // TODO(nshahan) Avoid reading imports in comments.
    // Reading imports in this manner can cause problems when trying to find
    // and break dependency cycles. If the import is commented out but the file
    // still exists this builder will still have a dependency on the asset even
    // though it is not used.
    var importedAssets = new List<AssetId>();

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
  SyncPackageResolver _tempDirPackgeResolver(Directory tempDir) {
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
