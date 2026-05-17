# XinReader

一款原生 macOS 电子书阅读器，支持 EPUB、MOBI、PDF 三种格式。使用 Swift/SwiftUI 构建。

## 功能特性

| 功能 | 说明 |
|------|------|
| 多格式支持 | EPUB (.epub)、MOBI (.mobi/.prc)、PDF (.pdf) |
| 双页翻页 | 类 NeatReader 分页式双栏布局，滚轮/键盘翻页 |
| 目录导航 | 左侧边栏显示书籍目录，点击跳转，每章显示页码和百分比 |
| 标签分类 | 书库左侧标签栏，支持创建/删除标签，按标签筛选书籍 |
| 自定义外观 | 字体、字号 (14-32px)、行距 (1.0-2.5) |
| 四种主题 | 浅色 / 暖纸 / 深色 / 护眼 |
| 阅读进度 | 自动保存/恢复每本书的阅读位置，目录栏显示当前页码和百分比 |
| 书库管理 | 书籍网格展示，封面/标题/作者，右键设置标签或删除 |
| 键盘快捷键 | ← → ↑ ↓ 翻页、Space/PageUp/PageDown、⌘+/⌘- 字号、⌘O 打开文件 |

## 安装

### DMG 安装（推荐）

```bash
# 编译 Universal Binary (arm64 + x86_64)
cd /path/to/XinReader
swift build -c release --arch arm64 --arch x86_64

# 生成 DMG（见 dist/ 目录下的打包脚本）
```

或直接使用预编译的 `dist/XinReader.dmg`：
1. 双击 DMG 挂载
2. 拖动 `XinReader.app` 到 `Applications`
3. 从 Launchpad 打开

### 源码运行

```bash
# 前提：macOS 14+, Xcode Command Line Tools
cd /path/to/XinReader

swift build    # 编译
swift run      # 运行

# 或用 Xcode 打开
open Package.swift
```

### 打包 DMG

```bash
cd /path/to/XinReader

# 1. 编译 Release Universal Binary (arm64 + x86_64)
swift build -c release --arch arm64 --arch x86_64

# 2. 创建 .app bundle 目录结构
mkdir -p dist/XinReader.app/Contents/MacOS
mkdir -p dist/XinReader.app/Contents/Resources

# 3. 复制二进制到 .app
cp .build/apple/Products/Release/XinReader dist/XinReader.app/Contents/MacOS/

# 4. 创建 Info.plist (如果 dist/XinReader.app/Contents/Info.plist 不存在)
#    参考项目中已有的 dist/XinReader.app/Contents/Info.plist

# 5. (可选) 生成应用图标
#    将 1024x1024 的 PNG 图片按要求缩放为 iconset，再用 iconutil 转换：
#    iconutil -c icns /path/to/XinReader.iconset -o dist/XinReader.app/Contents/Resources/AppIcon.icns

# 6. 打包 DMG
rm -rf /tmp/dmg_content && mkdir -p /tmp/dmg_content
cp -R dist/XinReader.app /tmp/dmg_content/
ln -sf /Applications /tmp/dmg_content/Applications
hdiutil create -volname "XinReader" -srcfolder /tmp/dmg_content -ov -format UDZO dist/XinReader.dmg

# 产出：dist/XinReader.dmg
```

安装时双击 DMG → 拖动 XinReader.app 到 Applications → 完成。

> **注意**：未签名的应用首次打开需右键 → "Open" → 确认，或在 System Settings → Privacy & Security 中允许。

## 技术架构

```
XinReader/
├── App/                          # 应用入口和全局状态
│   ├── XinReaderApp.swift        # @main 入口 + AppDelegate
│   └── AppState.swift            # 全局状态管理 (ObservableObject)
│
├── Models/                       # 数据模型
│   ├── Book.swift                # 书籍元数据 (Codable, 含 tags)
│   ├── Chapter.swift             # 目录章节节点 (树形结构)
│   ├── ReaderSettings.swift      # 阅读器外观设置 + 主题定义
│   └── ReadingProgress.swift     # 阅读进度 (滚动百分比/页码)
│
├── Parser/                       # 文件解析层
│   ├── ParsedBook.swift          # 统一解析结果 + BookContent 枚举
│   ├── BookParser.swift          # 格式检测路由 (MOBI/EPUB/PDF)
│   ├── BinaryReader.swift        # 二进制数据读取工具 (大端序)
│   ├── PDBHeader.swift           # PDB 头解析
│   ├── PalmDOCHeader.swift       # PalmDOC 头 (压缩类型)
│   ├── MOBIHeader.swift          # MOBI 头 (编码/偏移)
│   ├── EXTHHeader.swift          # EXTH 元数据 (作者/标题)
│   ├── PalmDOCDecompressor.swift # LZ77 解压算法
│   ├── RecordExtractor.swift     # PDB 记录切片
│   ├── ContentAssembler.swift    # 文本记录合并为 HTML
│   ├── ImageExtractor.swift      # 图片记录提取
│   ├── TOCExtractor.swift        # MOBI 目录提取 (HTML标题扫描)
│   ├── MOBIParser.swift          # MOBI 顶层解析入口
│   ├── MOBIError.swift           # MOBI 错误类型
│   │
│   ├── EPUB/                     # EPUB 解析子系统
│   │   ├── EPUBParser.swift      # EPUB 顶层入口
│   │   ├── EPUBError.swift       # EPUB 错误类型
│   │   ├── ContainerParser.swift # META-INF/container.xml 解析
│   │   ├── OPFParser.swift       # OPF 元数据/manifest/spine
│   │   ├── EPUBTOCParser.swift   # NCX (EPUB2) + nav.xhtml (EPUB3)
│   │   └── EPUBContentAssembler.swift # XHTML 拼接 + 图片提取
│   │
│   └── PDF/                      # PDF 解析
│       └── PDFBookParser.swift   # PDFKit 封装 + 大纲提取
│
├── Services/                     # 持久化服务
│   ├── SettingsStore.swift       # 设置读写 (UserDefaults)
│   ├── ProgressStore.swift       # 阅读进度 (JSON, per-book files)
│   └── BookLibrary.swift         # 书库目录 + 标签管理
│
├── Utilities/                    # 工具类
│   ├── HTMLCleaner.swift         # HTML 清理 + 分页式双栏 HTML/JS 模板
│   └── ReaderStyleSheet.swift    # 动态 CSS 生成 (主题/字体/行距)
│
├── Views/                        # SwiftUI 视图层
│   ├── MainView.swift            # 顶层视图 (书库 ↔ 阅读器切换)
│   ├── LibraryView.swift         # 书库：标签侧栏 + 书籍网格
│   ├── BookCard.swift            # 单本书卡片 + 添加书卡片
│   ├── ReaderContentView.swift   # 阅读器主布局 (NavigationSplitView)
│   ├── SidebarView.swift         # 左侧目录树 + 阅读进度显示
│   ├── ReaderView.swift          # 渲染引擎切换 (HTML ↔ PDF)
│   ├── WebContentView.swift      # WKWebView 封装 + ImageSchemeHandler
│   ├── PDFContentView.swift      # PDFView 封装 (PDFKit)
│   ├── ReaderToolbar.swift       # 工具栏按钮
│   └── AppearanceSheet.swift     # 外观设置面板
│
└── dist/                         # 打包产物
    └── XinReader.app/            # macOS .app bundle (Universal Binary)
```

## 格式支持详情

### EPUB
- 解析：ZIPFoundation 解压 → container.xml → OPF (manifest/spine) → XHTML 拼接
- 目录：EPUB3 nav.xhtml + EPUB2 NCX 双策略，降级到 spine 生成
- 图片：从 ZIP 提取，通过 `bookimage://` 自定义 URL scheme 提供给 WKWebView
- 编码：自动检测 UTF-8 / GBK / GB18030 / Big5 / Latin1
- 渲染：WKWebView，分页式双栏布局

### MOBI
- 解析：自写解析器，PDB → PalmDOC/MOBI/EXTH 头 → LZ77 解压 → HTML
- 目录：HTML 标题扫描 (h1-h3) + pagebreak 标记
- 图片：从 PDB 记录提取 (JPEG/PNG/GIF/BMP)
- 压缩：支持 PalmDOC LZ77，HUFF/CDIC 暂不支持
- DRM：检测并友好提示，不尝试破解

### PDF
- 解析：Apple PDFKit (PDFDocument)
- 目录：PDF Outline 递归提取
- 渲染：PDFView (原生 NSView)，支持缩放、连续滚动
- 封面：首页渲染为 JPEG 缩略图

## 双页翻页实现

核心方案：CSS columns + `scrollLeft` 水平分页。

```
┌─────────────────────────────────────────────┐
│  #book-container (overflow: hidden)         │
│  ┌─────────────────────────────────────┐    │
│  │  #book-content                      │    │
│  │  column-count: 2, column-fill: auto │    │
│  │  height: 100%, overflow: hidden     │    │
│  │                                     │    │
│  │  ┌─────┐ gap ┌─────┐               │    │
│  │  │ 左页 │     │ 右页 │  ← 当前可见   │    │
│  │  └─────┘     └─────┘               │    │
│  └─────────────────────────────────────┘    │
│          [1 / 42]                           │
└─────────────────────────────────────────────┘

翻页步长: stepWidth = clientWidth + columnGap
翻页方式: container.scrollLeft = page * stepWidth
```

- **鼠标滚轮**：单次 wheel 事件直接翻页，250ms 冷却防连发
- **键盘**：← → ↑ ↓ Space Backspace PageUp PageDown Home End
- **目录跳转**：临时归零 scrollLeft → 测量 offsetLeft → 算出页码 → 跳转
- **窗口缩放/字体变化**：保存百分比 → 重算页数 → 恢复到对应页

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | 0.9.19+ | EPUB ZIP 解压 |
| Apple PDFKit | 系统框架 | PDF 渲染 |
| Apple WebKit | 系统框架 | EPUB/MOBI 内容渲染 (WKWebView) |

## 数据存储

| 数据 | 位置 | 格式 |
|------|------|------|
| 阅读器设置 | UserDefaults (`readerSettings`) | JSON |
| 书库目录 | `~/Library/Application Support/XinReader/library.json` | JSON |
| 标签列表 | `~/Library/Application Support/XinReader/tags.json` | JSON |
| 阅读进度 | `~/Library/Application Support/XinReader/progress/<uuid>.json` | JSON (每书一个文件) |

## 统计

- **源文件**: 43 个 Swift 文件
- **代码量**: ~4700 行
- **外部依赖**: 1 个 (ZIPFoundation)
- **二进制**: Universal Binary (arm64 + x86_64), ~1.5MB

## License

Apache License 2.0
