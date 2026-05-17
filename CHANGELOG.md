# XinReader 开发日志

## 2026-05-10 — 初始版本 (MobiReader)

### 创建项目
- 使用 Swift Package Manager 创建 macOS 原生应用
- 目标平台: macOS 14+

### MOBI 解析器
- 实现完整的 MOBI 文件格式解析链:
  - `BinaryReader` — 大端序二进制读取工具
  - `PDBHeader` — PDB 头解析 (78字节 + 记录偏移表)
  - `PalmDOCHeader` — 压缩类型检测 (None/PalmDOC/HUFF)
  - `MOBIHeader` — 编码/偏移/EXTH标志解析
  - `EXTHHeader` — 元数据提取 (作者/标题/封面索引)
  - `PalmDOCDecompressor` — LZ77 解压算法实现
  - `RecordExtractor` — PDB 记录按偏移切片
  - `ContentAssembler` — 文本记录合并 + trailing bytes 剥离
  - `ImageExtractor` — 图片记录识别 (JPEG/PNG/GIF/BMP magic bytes)
  - `TOCExtractor` — HTML 标题扫描提取目录
  - `MOBIParser` — 顶层协调器

### UI 基础
- `MobiReaderApp` + `AppDelegate` (解决 swift run 窗口不显示问题)
- `NavigationSplitView` 双栏布局 (目录 + 正文)
- `WKWebView` + `HTMLCleaner` 渲染 HTML 内容
- `ImageSchemeHandler` — 自定义 URL scheme 为 WKWebView 提供图片
- `ReaderStyleSheet` — 动态 CSS 生成
- `LibraryView` / `BookCard` — 书库网格
- `AppearanceSheet` — 字体/字号/行距/主题设置面板
- `SettingsStore` (UserDefaults) / `ProgressStore` (JSON) / `BookLibrary`

---

## 2026-05-10 — 重命名 + 多格式支持

### 重命名 MobiReader → XinReader
- 目录/文件/类名/UI字符串全面替换
- URL scheme: `mobimage://` → `bookimage://`
- 存储路径: `MobiReader/` → `XinReader/` (含自动迁移)

### Parser 抽象层
- 新增 `ParsedBook` + `BookContent` 枚举 (`.html` / `.pdf`)
- 新增 `BookParser` — 按文件扩展名路由到对应解析器
- 新增 `BookFormat` 枚举 (mobi/epub/pdf)
- `AppState` 改用 `ParsedBook` 替代 `MOBIParser.ParsedBook`
- `ReaderView` 按 `BookContent` 切换 WKWebView / PDFView

### PDF 支持
- 新增 `PDFBookParser` — PDFKit 封装 + PDF Outline 递归提取 + 首页封面渲染
- 新增 `PDFContentView` — NSViewRepresentable 包装 PDFView
- `Chapter` 新增 `pageIndex: Int?` 字段
- `ReadingProgress` 新增 `currentPage: Int?` 字段

### EPUB 支持
- 添加 ZIPFoundation 依赖
- 新增 EPUB 解析子系统 (6个文件):
  - `ContainerParser` — META-INF/container.xml → OPF路径
  - `OPFParser` — metadata/manifest/spine 解析
  - `EPUBTOCParser` — EPUB3 nav.xhtml + EPUB2 NCX 双策略
  - `EPUBContentAssembler` — spine XHTML 按顺序拼接 + 图片路径重写
  - `EPUBParser` — 顶层协调器
  - `EPUBError` — 错误类型
- 编码自动检测: UTF-8 → XML声明 → GB18030/GBK → Big5 → Latin1
- `MainView` fileImporter 支持 .mobi/.prc/.epub/.pdf

### bug 修复
- `SettingsStore.objectWillChange` 转发到 `AppState`，修复设置变更不刷新UI
- `ImageSchemeHandler` 修复 EPUB 图片路径解析 (host+path 组合)
- `EPUBContentAssembler` 的 data-href/data-filename/data-basename 属性，配合 JS 目录跳转

---

## 2026-05-17 — 双页翻页布局

### 分页式双栏渲染 (类 NeatReader)
- 彻底重写 `ReaderStyleSheet` 和 `HTMLCleaner` 模板
- CSS: `#book-content` 使用 `column-count: 2` + `column-fill: auto` + `overflow: hidden`
- 外层 `#book-container` 绝对定位填满视口

### 翻页机制: scrollLeft 方案
- 放弃 `translateX` 方案 (与元素位置测量冲突导致白屏)
- 使用 `container.scrollLeft = page * stepWidth` 原生水平滚动
- `stepWidth = clientWidth + columnGap` (从 computed style 精确读取 gap)
- 解决了"显示3页/首尾各半页"的对齐问题

### 输入处理
- 鼠标滚轮: 累积 deltaY + 60ms 防抖，兼容 trackpad
- 键盘: ← → Space Backspace PageUp PageDown Home End
- 页码指示器: 底部居中显示 "当前页 / 总页数"

### 目录跳转
- `pageOfElement()`: 临时 scrollLeft=0 → offsetLeft 测量 → 算页码 → 恢复 → goTo
- `findEPUBElement()`: data-href → data-filename → data-basename → fragment → fuzzy scan

### 样式热更新
- `updateStyles()`: 注入新CSS → 80ms后保持百分比位置重算页码
- 窗口 resize: 同步重算并保持位置

### 健壮性
- JS 用 Swift raw string (`#"""..."""#`) 避免转义问题
- `recalc()` 中 gap/width 安全检查
- 初始化轮询 (最多20次 × 100ms) 等待容器渲染
- `fixMalformedHTML` 清理内容中的 `<script>` 标签防止模板破坏
