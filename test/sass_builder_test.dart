import 'package:build/build.dart';
import 'package:sass_builder/sass_builder.dart';
import 'package:test/test.dart';

void main() {
  group('File import parsing tests', () {
    SassBuilder sassBuilder;

    setUp(() {
      sassBuilder = new SassBuilder();
    });

    test('Single import, no extension, same folder test', () {
      var contents = """
          // Imports incoming!
          @import 'mixins';
          
          body {
            color: red;
          }
          """;
      var id = new AssetId('test_package', 'dir/test_file.scss');
      var importIds = sassBuilder.importedAssets(id, contents);

      expect(importIds.length, equals(1));
      expect(importIds, contains(new AssetId('test_package', 'dir/mixins.scss')));
    });

    test('Single import, with extension, same folder test', () {
      var contents = """
          // Imports incoming!
          @import 'mixins.scss';
          
          body {
            color: red;
          }
          """;
      var id = new AssetId('test_package', 'dir1/dir2/test_file.scss');
      var importIds = sassBuilder.importedAssets(id, contents);
      expect(importIds.length, equals(1));
      expect(importIds, contains(new AssetId('test_package', 'dir1/dir2/mixins.scss')));
    });

    test('Single package import test', () {
      var contents = """
          // Imports incoming!
          @import 'package:other_package/dir2/mixins.scss';
          
          body {
            color: red;
          }
          """;
      var id = new AssetId('test_package', 'dir1/test_file.scss');
      var importIds = sassBuilder.importedAssets(id, contents);
      expect(importIds.length, equals(1));
      expect(importIds, contains(new AssetId('other_package', 'lib/dir2/mixins.scss')));
    });

    test('Multiple imports test', () {
      var contents = """
          // Imports incoming!
          @import 'package:other_package/dir2/mixins.scss',
                  'mixins',
                  'other_dir/styles.scss';
          
          body {
            color: red;
          }
          """;
      var id = new AssetId('test_package', 'dir/test_file.scss');
      var importIds = sassBuilder.importedAssets(id, contents);
      expect(importIds.length, equals(3));
      expect(importIds, contains(new AssetId('other_package', 'lib/dir2/mixins.scss')));
      expect(importIds, contains(new AssetId('test_package', 'dir/mixins.scss')));
      expect(importIds, contains(new AssetId('test_package', 'dir/other_dir/styles.scss')));
    });

    test('Multiple import lines test', () {
      var contents = """
          // Imports incoming!
          @import 'package:other_package/dir2/mixins.scss',
          @import 'mixins',
          // some comment.
          @import 'other_dir/styles.scss';
          
          body {
            color: red;
          }
          """;
      var id = new AssetId('test_package', 'dir/test_file.scss');
      var importIds = sassBuilder.importedAssets(id, contents);
      expect(importIds.length, equals(3));
      expect(importIds, contains(new AssetId('other_package', 'lib/dir2/mixins.scss')));
      expect(importIds, contains(new AssetId('test_package', 'dir/mixins.scss')));
      expect(importIds, contains(new AssetId('test_package', 'dir/other_dir/styles.scss')));
    });
  });
}
