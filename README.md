
# 使用Dart注解一行代码生成图片资源配置文件

### 背景
在使用Flutter开发的时候，有时候会存在很多资源图片问题，按照规定，使用的图片资源需要在 `pubspec.yaml` 文件中配置路径才可以正常使用，如果存在很多50个以上或者更多图片资源，难道需要一个一个配置？显然是不可能的！

其实，Flutter是支持直接在 `pubspec.yaml` 中配置图片资源文件夹路径即可，没必要每个图片资源路径都详细配置的，但是不管怎么样，在实际调用的时候，还是得老老实实写完整的图片路径，显然是很不方便的，那该如何解决？

不同的开发有不同的思路，这里我采取的是使用Dart注解的方式，只需要执行一行注解即可完成资源文件配置。

先看效果：
比如我们有以下资源文件：<br>
![图片资源](https://s2.ax1x.com/2019/09/29/u3Kgc6.png)

我们只需要配置一行注释：
```Dart
@ImagePathSet('assets/', 'ImagePathTest')
void main() => runApp(MyApp());
```
然后运行一行命令：
```
flutter packages pub run build_runner build
```
执行完毕即可生成一个 `.dart` 文件内容如下：
```Dart
class ImagePathTest {
  ImagePathTest._();

  static const BANNER = 'assets/image/banner.png';
  static const PLAY_STOP = 'assets/image/play_stop.png';
  static const SAVE_BUTTON = 'assets/image/save_button.png';
  static const MINE_HEADER_IMAGE = 'assets/image/test/mine_header_image.png';
  static const VERIFY = 'assets/image/verify.png';
  static const VERIFY_ERROR = 'assets/image/verify_error.png';
}
```

同时在 `pubspec.yaml` 文件夹下自动配置好我们的资源文件：
```yaml
assets:
- assets/image/banner.png
- assets/image/play_stop.png
- assets/image/save_button.png
- assets/image/test/mine_header_image.png
- assets/image/verify.png
- assets/image/verify_error.png
```
使用时即可直接以代码形式直接引用图片资源：
```Dart
Image.asset(ImagePathTest.xxx)
```
即可以防止手误出差，又可以提高效率~
下面重点介绍我们的开发思路。

---

### 实战利用一行注解生成资源配置文件
关于Dart注解使用，可以参考这篇文章，写的比较细：[Flutter 注解处理及代码生成](https://juejin.im/post/5d1ac884f265da1bad571f3a)，也可以参考官方说明：[source_gen](https://github.com/dart-lang/source_gen)

这里简单说明，在 `source_gen`官方文档说明里有这么一句话：
> source_gen is based on the [build](https://pub.dev/packages/build) package and exposes options for using your Generator in a Builder. <br>
省略部分文档内容 ......<br>
In order to get the Builder used with build_runner it must be configured in a build.yaml file. 

翻译成中文即：<br>
> <font color=#ff0000>`source_gen` 是基于 `build` 包的，同时提供暴露了一些选项以方便在一个 `Builder` 中使用你自己的生成器 `Generator`。<br>...<br>为了能够使 `Builder` 和 `build_runner` 一块使用，必须要配置一个 `build.yaml` 文件。</font>

因此想要使用Dart注解，我们需要做这几件事：
- 依赖注解库 `source_gen`
- 依赖构建运行库 `build_runner`
- 创建注解代码生成器 `Generator`
- 创建 `Build`
- 创建 `build.yaml` 文件
- 在需要使用的地方引入相关注解
- 运行编译命令进行构建

下面一个一个说。

#### 依赖注解库 `source_gen`
这个没什么好说的，只要你是要Dart注解就必须依赖该库：
```yaml
dependencies:
  source_gen: ^0.9.4+5
```
具体版本可到这里查看[source_gen](https://pub.dev/packages/source_gen#-installing-tab-)

#### 依赖构建运行库 `build_runner`
同上，直接依赖就是，一般依赖在 `dev_dependencies` 节点下：
```yaml
dev_dependencies:
  build_runner: ^1.7.1
```
具体版本可到这查看[build_runner](https://pub.dev/packages/build_runner#-installing-tab-)

该库中内置了编译运行的命令：`pub run build_runner <command>`，主要为下面四种编译类型：
- `build`
- `watch`
- `serve`
- `test`

其中在flutter中一般只需要第一种构建方式，同上以上四个命令都可以附加一些命令，例如：`--delete-conflicting-outputs`。详细说明可参考这里：[build_runner相关说明](https://pub.dev/packages/build_runner#-readme-tab-)

#### 创建注解代码生成器 `Generator`
从字面意思理解为 `生成器`，官方说明为：
> A tool to generate Dart code based on a Dart library source.

一种基于Dart库源代码生成Dart代码的工具。类图如下：<br>
![Generator](https://s2.ax1x.com/2019/09/30/uJQNUU.png)

两个类都是抽象类，通常创建一个类继承自 `GeneratorForAnnoration` 并实现抽象方法，在该抽象方法中完整我们需要的逻辑功能开发；这里我们需要搞一个图片资源文件配置功能，该功能具有以下两个要点：
- 需要使用者指定资源文件夹路径
- 需要使用者指定生成的资源配置类名称

因此我们先创建一个实例类包含这两个信息：
```Dart
class ImagePathSet{
  /// 资源文件夹路径
  final String pathName;
  
  /// 需要生成的资源配置类名
  final String newClassName;

   const ImagePathSet(this.pathName, this.newClassName);
}
```
最终我们在使用的第一引用就需要这样引用：
```Dart
@ImagePathSet('assets/', 'ImagePathTest')
```
此处需要注意的是，这个类的构造方法必须是 `const` 的。创建好了最终需要使用的注解类之后，我们创建生成器：
```Dart
class ImagePathGenerator extends GeneratorForAnnotation<ImagePathSet> {
  @override
  generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    
    return null;
  }
}
```

在 `generateForAnnotatedElement()` 方法中，我们即可完成我们的逻辑部分开发了，这里涉及到三个参数：
- element：这个是被注解的类/方法等的详细信息，比如被修饰的部分代码这样：
    ```Dart
    /// path_test.dart
    
    @ImagePathSet('assets/', 'ImagePathTest')
    class PathTest{}
    ```
    则一些相关的element信息如下：
    ```
    element.name                /// PathTest
    element.displayName         /// PathTest
    element.toString()          /// class PathTest
    element.enclosingElement    /// /example/lib/path_test.dart
    element.kind                /// CLASS
    element.metadata            /// [@ImagePathSet ImagePathSet(String pathName, String newClassName)]
    ```
- annotation：注解的详细信息<br>其中最常用的两个方法分别是：
    - `read(String field)` 
    - `peek(String field)`
    
    两个都是读取给定的注解参数信息，前者如果没读取到或抛出 `FormatException` 异常，后者则会返回 `null`。
    <br> 需要注意的是，这两个方法返回的结果是 `ConstantReader` 类型，如果需要获取到具体注解元素的值，需要调用对应的 `xxxValue`方法，`xxx`表示具体类型，比如上面的注解，我们需要获取 `pathName`信息，可以写成这样：
    ```Dart
    String pathName= annotation.peek('pathName').stringValue
    ```
    当然，我们假如我们不知道注解参数的类型，可以根据 `isXxx` 来判断是否是对应的类型，比如：
    ```Dart
    annotation.peek('pathName').isString    ///true
    annotation.peek('pathName').isInt       ///false
    ```
- buildStep：构建的输入输出信息
<br>本想着修改这个类来修改生成文件名称信息，无奈Dart不支持反射，未找到相关的修改方法，这里最主要的一个信息为：
    - inputId：包含了构建时候输入的相关信息

完整的根据根据生成资源文件的生成器代码如下：
```
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

```

#### 创建Build
`Build` 的作用主要是让生成器执行起来，我们这里创建的 `Build` 如下：
```Dart
Builder imagePathBuilder(BuilderOptions options) =>
    LibraryBuilder(ImagePathGenerator());
```
主要引用的包为：
```Dart
import 'package:build/build.dart';
```

#### 创建 build.yaml 文件
在这里我们的 `build.yaml` 文件配置如下：
```yaml
builders:
  image_builder:
    import: 'package:image_path_helper/builder.dart'
    builder_factories: ['imagePathBuilder']
    build_extensions: { '.dart': ['.g.dart'] }
    auto_apply: root_package
    build_to: source
```
`build.yaml` 配置的信息，最终都会被 `build_config.dart` 中的 `BuildConfig` 类读取到。<br>
关于参数说明，这里推荐官方说明[build_config](https://pub.dev/packages/build_config)。<br>

一个完整的 `build.yaml` 结构图如下：
![build.yaml文件结构图](https://s2.ax1x.com/2019/10/12/uO0c1H.png)
一个 `build.yaml` 文件最终被一个 `BuildConfig` 对象所描述，也就是说 `build.yaml` 文件最终被 `BuildConfig` 所解析。而 `BuildConfig` 包含了四个关键的信息：
key | value |default
--| --| --
`targets`               | `Map<String, BuildTarget>`                    | 单个的target应该所对应的package名一致
`builders`              | `Map<String, BuilderDefinition>`              | /
`post_process_builders` | `Map<String, PostProcessBuilderDefinition>`   | /
`global_options`        | `Map<String, GlobalBuilderOptions>`           | /

四个关键信息正是对应了 `build.yaml` 文件中的四个根节点，其中又以 `builders` 节点最为常用。

##### builders说明

builders配置的是你的包中的所有 `Builder` 的配置信息，每个信息格式是 `Map<String, BuilderDefinition>` 的，比如我们存在一个这样的 `Builder`：
```Dart
/// builder.dart
Builder imagePathBuilder(BuilderOptions options) =>
    LibraryBuilder(ImagePathGenerator());
```
 我们就可以在 `build.yaml` 文件中配置成这样：
```yaml
builders:
  image_builder:
    import: 'package:image_path_helper/builder.dart'
    builder_factories: ['imagePathBuilder']
    build_extensions: { '.dart': ['.g.dart'] }
    auto_apply: root_package
    build_to: source
```

`image_builder` 对应的就是 `Map<String, BuilderDefinition>` 中的 `String` 部分，`:` 后面的即 `BuilderDefinition` 信息，对应上面的结构图。下面我们细说 `BuilderDefinition` 中的每个参数的信息：
参数 | 参数类型 | 说明
--   | --       | --
`builder_factories`   | `List<String>`                  | 必填参数，返回的 `Builder` 的方法名称的列表，例如上面的 `Builder` 方法名为 `imagePathBuilder`，则写成 `['imagePathBuilder']`
`import`              | `String`                        | 必填参数，导入`Builder`所在的包路径，格式为 `package：uri` 的字符串               
`build_extensions`    | `Map<String, List<String>>`     | 必填参数，从输入扩展名到输出扩展名的映射。举个例子：比如注解使用的位置的文件对应的格式为 `.dart`，指定输出的文件格式可由 `.dart` 转换成 `.g.dart` 或 `.zip` 等等其他格式
`auto_apply`          | `String`                        | 可选参数，默认值为 `none`，对应源码中的 `AutoApply` 枚举类，有四种可选配置：<li>`none`：除非手动配置了此生成器，否则请不要应用它</li><li>`dependents`：将此Builder应用于包，直接依赖于暴露构建器的包</li><li>`all_packages`：将此构建器应用于传递依赖关系图中的所有包</li><li>`root_package`：仅将此生成器应用于顶级软件包</li><br>是不是感觉一脸懵逼？没关系，后面单独解释~~~
`required_inputs`     | `List`                          | 可选参数，用于调整构建顺序的，指定一个或一系列文件扩展名，表示在任何可能产生该类型输出的Builder之后运行
`runs_before`         | `List<BuilderKey>`              | 可选参数，用于调整构建循序的，更上面的刚好相反，表示在指定的Builder之前运行 <li>`BuilderKey`：表示一个 `target` 的身份标志，主要由对应 `Builder` 的包名和方法名构成，例如这样 `image_path_helper|imagePathBuilder`</li>
`applies_builders`    | `List<BuilderKey>`              | 可选参数，`Builder` 键列表，也就是身份标志，跟 `builder_factories` 参数配置应该是一一对应的
`is_optional`         | `bool`                          | 可选参数，默认值 `false`，指定是否可以延迟运行 `Builder` ，通常不需要配置
`build_to`            | `String`                        | 可选参数，默认值为 `cache`，主要为 `BuildTo` 枚举类的两个参数：<li>`cache`：输出将进入隐藏的构建缓存，并且不会发布<li/>`source`：输出进入其主要输入旁边的源树 <br>直白点就是如果你需要编译后生成相应的可在自己编写的源码中看到见的文件，就将这个参数设置成 `source`，如果指定的生成器返回的是 `null` 不需要生成文件，则可以设置为 `cache`
`defaults`            | `TargetBuilderConfigDefaults`   | 可选参数：用户未在其`builders`【此处指的是 `targets` 节点下的`builders`，别搞混淆了！】部分中指定相应键时应用的默认值


关于 `auto_apply` 参数的详细说明：
![auto_apply](https://s2.ax1x.com/2019/10/15/K9v0RH.png)
<br>如上图所示，一个应用Package依赖了三个子包，此时我们有一个 `注解package` 包含了一些注解功能：
- 当我们将`auto_apply`设置成 `dependents`时:
    - 如果 `注解package` 是直接依赖在 `sub_package02` 上的，那么只能在 `sub_package02` 上正常使用注解，虽然 `Package` 包依赖了 `sub_package02`，但是依然无法正常使用该注解
- 当我们将`auto_apply`设置成 `all_packages`时:
    - 如果 `注解package` 是直接依赖在 `sub_package02` 上的，那么在 `sub_package02` 和 `Package`上都能正常使用注解
- 当我们将`auto_apply`设置成 `root_package` 时:
    - 如果 `注解package` 是直接依赖在 `sub_package02` 上的，那么只能在 `Package` 上正常使用注解，虽然是 `sub_package02` 上做的依赖，但是就是不给用
- 因此，假如 `注解package` 是直接依赖在 `Package` 上的时候，不管 `auto_apply` 设置的是 `dependents`、`all_packages` 或者是 `root_package` 时，其实都是能正常使用的！


至于 `build.yaml` 其他的三个节点参数，说实话，因为目前用到的不多，只了解一部分，有很多细节尚未理清，只能在这里略过了。
    
#### 在需要使用的地方引入相关注解 & 运行编译命令进行构建
上面的工作完成之后，我们就需要引用注解了，比如我们在 `main()` 方法上引用：
```Dart
@ImagePathSet('assets/', 'ImagePathTest')
void main() => runApp(MyApp());
```
引用完注解之后，然后我们在Terminal命令行中执行下面这个命令完成编译：
```
flutter packages pub run build_runner build
```
编译完成之后会生成对应的文件，比如我们上面配置的是在 `main.dart` 文件中的 `main` 方法上配置的，最终生成的文件为 `main.g.dart` ，关于文件是如何生成的，你可以参考 `run_builder.dart` 下的 `runBuilder` 方法和 `expected_outputs.dart` 下的 `expectedOutputs` 方法。

注意：如果需要重新构建建议先进行清除操作：
```
flutter packages pub run build_runner clean
```

除此之外，建议在构建的时候执行下面的这个命令进行构建：
```
flutter packages pub run build_runner build --delete-conflicting-outputs
```

至此，一个完整的利用注解一行代码+一行命令完成图片文件配置的功能就做完啦~~~

---
### 总结时刻
在Flutter中想要注解，只需要遵循一定的步骤加上自己的逻辑即可轻松完成相关功能开发，主要的流程步骤总结如下：
- 依赖 `source_gen` 和 `build_runner` 库
- 注解类创建以及创建生成器 `Generator`
- 创建 `Builder` 
- 创建并配置 `build.yaml` 文件
- 引用创建好的注解并运行相关命令完成相关操作

**Tips**：本文源码位置：[image_path_helper](https://github.com/Reign9201/image_path_helper)