import 'package:image_path_helper/image_path_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

Builder imagePathBuilder(BuilderOptions options) =>
    LibraryBuilder(ImagePathGenerator());
