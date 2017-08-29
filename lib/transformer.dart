import 'package:build_barback/build_barback.dart';
import 'sass_builder.dart';

/// A pub transformer simply wrapping the [SassBuilder].
class SassBuilderTransform extends BuilderTransformer {
  // TODO(nshahan) Support barback modes to consume the .scss files when not in
  // DEBUG mode.
  SassBuilderTransform.asPlugin(_) : super(new SassBuilder());
}
