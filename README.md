A Builder to compile .css files from .scss sources using the Dart implementation
of Sass.

## Work in Progress
This package is work in progress and is not published to 
https://pub.dartlang.org.

1. Add the dependency to your package's pubspec.yaml file:

```yaml
dependencies:
  sass_builder: ^0.0.1
  
dependency_overrides:
  sass_builder:
    git: git@github.com:nshahan/sass_builder.git
```

2. Add the transformer to your package's pubspec.yaml file:

```yaml

dependencies:
  sass_builder: ^0.0.1

dependency_overrides:
  sass_builder:
    git: git@github.com:nshahan/sass_builder.git

transformers:
- sass_builder
```

> Note: If you are using the angular transformer and your angular components
> depend on the .css files output from sass_builder be sure to list the
> sass_builder transformer on a line above the angular transformer.
