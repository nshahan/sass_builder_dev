## 0.0.1

Initial version exposes two classes. 

`SassBuilder` is a `Builder` that outputs .css files from .scss sources using
the Dart implementation of Sass. This implementation supports package imports 
in .scss source files to other .scss files in the same package or a dependency. 

`SassBuilderTransform` wraps a `SassBuilder` in a pub transformer.
