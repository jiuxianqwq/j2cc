# j2cc

现在公开了！

（我已经大概 4 个月没维护了）

一个把 Java 转成 C++ 的转译器

## What does this do?

这个项目的目标是把现有的、有效的、可运行的 Java 字节码通过 JNI 转译成 C++，从效果上看就是用 native 版本替换原始字节码。
主要用途是混淆敏感代码，让别人更难绕过（例如许可证校验）。

## DISCLAIMER

**任何混淆都能被破解**。**这条规则没有例外**，本项目也**不声称自己是例外**。

用本项目混淆后的代码或许能挡住新手，但**有足够经验的人依然可以逆向这个程序的输出**。

任何宣称“100% 不可逆”的项目都是在卖假药。**一个既能正常运行、又能完全防逆向的程序，是不可能存在的**。

## What this program can and cannot do

This program can:

- 把现有的 Java 字节码（在标准、符合 JVMS 的 JVM 上、且不需要 `-noverify` 就能运行的那种）通过 JNI 转译成 C++ 代码
	- 用 Zig 的 C++ drop-in 编译器把生成的 C++ 编译到多个目标平台（x86_64 linux、x86_64 windows 等）
- 自动检测当前运行平台，并从转译后的 jar 的资源中加载匹配的 native 库（前提是该库存在并且由作者编译进去）
- 支持现代 JVM 规范里几乎所有内容（包括 ConstantDynamic）
- 能处理已经被混淆过的 Java 字节码
- 即使不进行 native 编译，也会对输入代码做一些轻量混淆和优化

This program CANNOT:

- 生成完全不可逆的 native 库（这玩意不存在，也不可能存在）
- 处理更老版本的 JVM 规范
	- 例如：不支持 JSR 和 RET

## Limitations

本程序转译后的方法通常会比原来的 Java 版本更慢。原因是 Java 调用 native 的开销（出乎意料地）很大，而且生成的 C++ 代码整体也更慢。
请谨慎使用转译，不要滥用。

转译后的方法在 JVM 侧的语义也不一定与原始 Java 代码完全一致。例如：某些异常消息可能会略有不同。
原因很多，主要是因为这个程序必须为所有 JVMS 字节码指令实现自己的处理逻辑，而做到 100% 完全一致几乎不可能。
不过这些处理逻辑仍然是 JVMS compliant 的，只是一些小细节可能与常见实现不同（基本上算 UB）。

如果你通过 agent 等机制去 redefine 被 native 代码**直接**引用的类，很可能会触发未定义行为，因为类会被缓存。
这只影响“直接引用”，不影响通过 `Class.forName` 或类似方式的引用。**这点没有经过验证**，但大概率如此。

Invokedynamic 的实现也与 JVM 略有不同，并且在某些地方比 JVM 的行为更严格，因此会有一些小坑。

- 如果你使用 invokedynamic，并且 BSM args 的基本类型与 BSM 方法对应参数槽位的基本类型不完全一致，运行时可能会抛出 ClassCastException。
	- 例如：期望 boolean 的地方提供了 int，会导致 ClassCastException
	- 额外说明：这个问题在一定程度上是 JVM 规范间接导致的，从严格意义上讲不算转译器的锅

## Usage

### Preparing the environment
编译器需要访问 util 库里的某些运行时函数。生成这些内容的方法见 `util/build_comptime_library.sh`。

你可以用下面的命令获取你的 target triple：`zig targets | jq -r '[.native.cpu.name,.native.os,.native.abi] | join("-")'`

你可以用下面的命令查看所有支持的目标：`zig targets | jq '.libc'`

用下面的方法生成对应的 native 库：
- `build_comptime_library.sh your_target_triple libraryNameFornativeUtils.extension`
- amd64 windows 示例：`build_comptime_library.sh x86_64-windows-gnu nativeUtils.dll`
- amd64 macos 示例：`build_comptime_library x86_64-macos-gnu libnativeUtils.dylib`

到这里，j2cc 应该就能找到对应的 native 了。

### Building a release
1. Generate natives as shown above
2. `mvn clean package`
3. `./createDist.sh`
4. You can now run `./dist_package/start.sh` or `./dist_package/start.ps1`

### Preparing the build environment
你需要下载 zig。最终的构建环境目录结构应如下所示：
```
dist_package
	libs
	natives
	util
	core-...jar
	start.ps1
	start.sh
zig_compiler
	zig.exe / zig
config.toml
input.jar
```

然后配置 `config.toml`：把 zig 编译器路径指向 `zig_compiler` 目录所在位置；`util` 目录同理。

如果这些路径不是绝对路径，它们会被当作“名称”来处理，并按以下顺序搜索：
1. If the `J2CC_HOME` env var is set, it's interpreted as directory and searched
2. Current directory is searched
3. Parent folder of core.jar is searched

如果在这三个位置都找不到，就会抛出错误。

Example for the above scenario:
#### config.toml
```toml
# ...
[paths]
	inputPath = "input.jar"
	outputPath = "output.jar"

	utilPath = "util"
	zigPath = "zig_compiler"
# ...
```

#### Invocation
`./dist_package/start.sh obfuscate config.toml`

### Preparing the jar

在应用混淆之前，你需要先准备好要被转译的 jar。
首先，把 `me.x150.j2cc:annotations` 依赖加到你的项目里，这样你才能使用 `@j2cc.Nativeify` 注解。
然后，用 `@j2cc.Nativeify` 标注你想要被转译的方法。或者，你也可以在类上标注 `@j2cc.Nativeify`，这样类里的方法（包括 synthetic 方法）都会被转译。

### Configuring

配置通过 toml 文件完成，你可以用 `j2cc getSchema` 生成一个示例模板。
