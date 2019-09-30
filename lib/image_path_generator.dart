import 'dart:io';

import 'package:analyzer/dart/element/element.dart';

import 'package:image_path_helper/image_path_set.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

class ImagePathGenerator extends GeneratorForAnnotation<ImagePathSet> {
  String _codeContent = '';
  String _pubspecContent = '';

  @override
  generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    final explanation = '// **************************************************************************\n'
        '// 如果存在新文件需要更新，建议先执行清除命令：\n'
        '// flutter packages pub run build_runner clean \n'
        '// \n'
        '// 然后执行下列命令重新生成相应文件：\n'
        '// flutter packages pub run build_runner build --delete-conflicting-outputs \n'
        '// **************************************************************************';

    var pubspecFile = File('pubspec.yaml');

    for (String imageName in pubspecFile.readAsLinesSync()) {
      if (imageName.trim() == 'assets:') continue;
      if (imageName.trim().toUpperCase().endsWith('.PNG')) continue;
      if (imageName.trim().toUpperCase().endsWith('.JPEG')) continue;
      if (imageName.trim().toUpperCase().endsWith('.SVG')) continue;
      if (imageName.trim().toUpperCase().endsWith('.JPG')) continue;
      _pubspecContent = "$_pubspecContent\n$imageName";
    }
    _pubspecContent = '${_pubspecContent.trim()}\n\n  assets:';

    /// 图片文件路径
    var imagePath = annotation.peek('pathName').stringValue;
    if (!imagePath.endsWith('/')) {
      imagePath = '$imagePath/';
    }

    /// 生成新的Dart文件名称
    var newClassName = annotation.peek('newClassName').stringValue;

    /// 遍历处理图片资源路径
    handleFile(imagePath);

    /// 添加图片路径到pubspec.yaml文件中
    pubspecFile.writeAsString(_pubspecContent);

    /// 返回生成的代码文件
    return '$explanation\n\n'
        'class $newClassName{\n'
        '    $newClassName._();\n'
        '    $_codeContent\n'
        '}';
  }

  void handleFile(String path) {
    var directory = Directory(path);
    if (directory == null) {
      throw '$path is not a directory.';
    }

    for (var file in directory.listSync()) {
      var type = file.statSync().type;
      if (type == FileSystemEntityType.directory) {
        handleFile('${file.path}/');
      } else if (type == FileSystemEntityType.file) {
        var filePath = file.path;
        var keyName = filePath.trim().toUpperCase();

        if (!keyName.endsWith('.PNG') &&
            !keyName.endsWith('.JPEG') &&
            !keyName.endsWith('.SVG') &&
            !keyName.endsWith('.JPG')) continue;
        var key = keyName
            .replaceAll(RegExp(path.toUpperCase()), '')
            .replaceAll(RegExp('.PNG'), '')
            .replaceAll(RegExp('.JPEG'), '')
            .replaceAll(RegExp('.SVG'), '')
            .replaceAll(RegExp('.JPG'), '');

        _codeContent = '$_codeContent\n\t\t\t\tstatic const $key = \'$filePath\';';

        /// 此处用 \t 符号代替空格在读取的时候会报错，不知道什么情况。。。
        _pubspecContent = '$_pubspecContent\n    - $filePath';
      }
    }
  }
}
