# AGENTS.md

> 给在本项目上工作的 AI 编码 Agent 阅读的指南。
> 描述项目结构、约定、关键命令和常见坑点。

---

## 项目概述

跨端文件浏览/管理 App，技术栈是 **Flutter**，单仓多端：

- **Flutter 移动端**（`lib/`）：浏览/播放后端文件服务器上的文件（视频、音频、图片、其他文件），支持设置主题、排序、播放方式等
- **配套 Web 端**（`网页项目/`）：Vue 3 实现，独立的网页版文件浏览器，与 Flutter 端功能镜像
- **后端服务**（不在本仓内，地址默认 `http://localhost:3000`）：提供 `list / getFile / getVideoPreview / delFile / restartServer` 等接口

Flutter 端不是单例状态管理（没有用 Provider/Riverpod），直接 `setState` + `Navigator.push`，代码风格偏简单直接。

---

## 技术栈

| 维度 | 选型 |
|---|---|
| 框架 | Flutter（SDK `^3.12.0`） |
| 路由 | `go_router ^14.6.2` |
| 网络 | `dio ^5.7.0` |
| 持久化 | `shared_preferences ^2.3.4` |
| 视频播放 | `video_player ^2.9.2` + `chewie ^1.8.5` |
| 音频播放 | `audioplayers ^6.1.0` |
| 外部唤起 | `url_launcher ^6.3.1`（VLC）、`share_plus ^10.1.4`（分享） |
| 图片缓存 | `cached_network_image ^3.4.1` |
| 主题色 | `flutter_colorpicker ^1.1.0` |
| Lint | `flutter_lints ^6.0.0` |

平台覆盖：Android / iOS / Windows / macOS / Linux / Web。

---

## 目录结构

```
flutter_application_1/
├── lib/
│   ├── main.dart                       # 入口，初始化 StorageService
│   ├── models/
│   │   └── file_info.dart              # 文件元数据模型，fromJson 内含 URL 拼接
│   ├── pages/
│   │   ├── home_page.dart              # 主页（文件列表 + 列表/网格切换 + 各种弹窗）
│   │   ├── settings_page.dart          # 设置页（显示/服务/系统操作）
│   │   ├── video_player_page.dart      # 视频播放器（chewie + 上下集）
│   │   └── audio_player_page.dart      # 音频播放器
│   ├── router/
│   │   └── app_router.dart             # GoRouter 配置（/ /settings /audio-play /video-play）
│   ├── services/
│   │   ├── api_service.dart            # 单例，Dio 封装 + 网络日志拦截器
│   │   ├── storage_service.dart        # 单例，SharedPreferences 封装
│   │   └── network_log_service.dart    # 单例 ChangeNotifier，记录网络请求
│   ├── utils/
│   │   ├── date_utils.dart
│   │   └── file_type_utils.dart
│   └── widgets/
│       ├── file_icon.dart
│       └── network_log_dialog.dart     # 网络日志弹窗
├── web/                                # Flutter Web 入口
│   ├── index.html
│   └── manifest.json
├── android/                            # Android 原生壳
│   └── app/src/main/AndroidManifest.xml
├── ios/  macos/  linux/  windows/      # 其他平台
├── 网页项目/                           # 独立 Vue 3 Web 项目（不在 Flutter 编译范围内）
└── pubspec.yaml
```

---

## 关键文件 & 职责

### `main.dart`

唯一入口。**启动顺序**：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();   // 必须先初始化，后续服务才能用
  runApp(const MyApp());
}
```

`StorageService.init()` 完成前，**不要**触发任何 `ApiService` 调用。

### `services/storage_service.dart`

- 整个 App 的"设置中心"：所有用户偏好 + 服务器地址都存在 `SharedPreferences` 里
- 单例（`factory` 模式 + `_internal()`），**不能改 init 流程**
- 加新设置项：写一个 `get/set` 对，写法参考已有条目

### `services/api_service.dart`

- **单例 Dio 封装**（`factory ApiService() => _instance`）
- 持有一个 Dio 实例 + 网络日志拦截器
- `_serverBaseUrl` **不要**用硬编码默认值，必须从 `StorageService().serverBaseUrl` 读
- `setServerUrl(url)` 同步更新内存字段和持久化（**两个都要写**）
- 加新接口：在类里加一个 `Future` 方法，URL 用 `'$_serverBaseUrl/xxx'`

### `services/network_log_service.dart`

- 网络日志单例（`ChangeNotifier`），最多缓存 500 条
- 弹窗 `NetworkLogDialog` 通过监听它实现实时刷新
- 加新日志维度：扩展 `NetworkLogEntry` 字段 + 修改 `_NetworkLogInterceptor` 里的 `_record`

### `pages/home_page.dart`

- 主页的 `ApiService` 实例字段（`final ApiService _apiService = ApiService();`）—— 因为是单例，写法上 `new` 多少次都返回同一个，**不要改成构造参数注入**
- 视图模式（`list` / `img`）、排序、过滤、文件点击/长按动作、播放方式选择都集中在这一个文件
- 添加新弹窗时注意 `_hasDialogOpen` 状态（控制返回键拦截）

### `pages/settings_page.dart`

- 三个区块：**服务设置 / 显示设置 / 系统操作**
- 保存按钮是 AppBar 上的 `TextButton`（不是 ListTile）
- 加新设置项：在对应区块里加一行，状态变量在 `initState` 读、`_saveSettings` 写

---

## 开发约定

### 强制要求

1. **必须用 PowerShell 7 执行命令**（项目要求的运行环境）
2. **前后端修改好后通知用户即可，不要自动运行/构建**——这是用户的硬性规矩

##  Thinking Process | 思考规范

*Apply strictly during reasoning/thinking phases. 仅在思考过程中严格执行。*

- **Telegraphic Style | 电报风格：** Keywords, short lists, or arrows (`->`) only. Zero complete or lengthy sentences. 仅使用关键词、短列表或箭头，严禁完整长句。
- **High Density | 高信息密度：** Log ONLY critical logical turns, intermediate calculations, or assumptions needing validation. Skip obvious facts. 仅记录关键逻辑转折、中间计算值或待校验假设。跳过常识。
- **Efficiency | 高效收敛：** Output the final result immediately once derivation is verified. 验证推导无误后立刻终止反思并输出结果。

### 命名 / 结构

- 服务类用 `factory + _internal` 模式做单例
- 私有变量 `_` 前缀
- 模型类用 `fromJson` 命名工厂
- 弹窗类放在 `widgets/` 或 `pages/`，单独文件

### 持久化设置

新增一个设置项的标准模板（参考 `serverBaseUrl`）：

```dart
// storage_service.dart
String get xxx => _prefs.getString('xxx') ?? '默认值';
set xxx(String value) => _prefs.setString('xxx', value);
```

```dart
// settings_page.dart
late String _xxx;

@override
void initState() {
  super.initState();
  _xxx = _storage.xxx;
}

void _saveSettings() {
  _storage.xxx = _xxx;
  // ...
}
```

---

## 常用命令（PowerShell 7）

| 用途 | 命令 |
|---|---|
| 安装依赖 | `flutter pub get` |
| 静态分析 | `flutter analyze` |
| 运行 Chrome（推荐，国内环境） | `flutter run -d chrome --no-web-resources-cdn` |
| 运行 Chrome（默认） | `flutter run -d chrome` |
| 打 release APK | `flutter build apk --release` |
| 打 Web release | `flutter build web` |
| 指定端口 | `flutter run -d chrome --web-port=8080` |

---

## 常见坑点

### 1. Android HTTP 明文流量（必须配置）

`android/app/src/main/AndroidManifest.xml` **必须**包含：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
...
<application
    ...
    android:usesCleartextTraffic="true">
```

否则 release APK 装上后会所有网络请求 `Connection failed`（debug 变体有 Flutter 自动塞的 `INTERNET`，但 release 没有）。

### 2. Flutter Web 国内访问 gstatic.com

构建/运行 Web 时加 `--no-web-resources-cdn`，把 canvaskit 资源打包进 `build/web/`，否则会报 `Failed to fetch canvaskit.js`。

### 3. 服务器地址变更

- `ApiService` **是单例**，但**每个 widget 还是写 `final ApiService _apiService = ApiService();`**（因为是单例所以这没问题，不要改成注入）
- `setServerUrl` 内部必须**同时**更新内存字段和 `StorageService`，否则只改一个会有同步问题

### 4. Web 端没有 Flutter 入口

`web/` 目录是 Flutter Web 的入口（`index.html` + `flutter_bootstrap.js`），**不是** Vue 那个 `网页项目/`。两个 web 项目相互独立，不要混用。

### 5. `NetworkLogService` 在生产环境

- 当前 `enabled` 默认 `true`，会记录所有 Dio 请求/响应
- 大响应体（图片二进制）会占内存，必要时调小 `_maxEntries` 或加大小限制
- 弹窗里没做"按 URL 过滤"功能，目前只展示全部

### 6. 文件 URL 在 `FileInfo.fromJson` 时就拼死了

`FileInfo` 对象的 `url` 字段在加载列表时确定，**改服务器地址后需要重新加载列表**。所以 `home_page.dart` 在设置页返回后会调 `_loadFileList()` 刷新。

---

## 配套 Web 项目（`网页项目/`）

独立目录，独立 `package.json`（Vue 3 + Vite），跟 Flutter 端**没有共享代码**。改的时候注意不要把 Vue 组件路径写到 Flutter 那边去。

主要技术栈：
- Vue 3 + Vue Router
- Vite
- axios
- 各种 `*.vue` 单文件组件

---

## 最近一次重大变更（Agent 应该知道的历史）

1. **网络日志功能**：通过 `Dio Interceptor` + 单例 `NetworkLogService` + `NetworkLogDialog` 实现，主页 AppBar 有 `bug_report` 按钮
2. **可配置服务器地址**：默认 `http://localhost:3000`，存储在 `SharedPreferences`，设置页"服务设置"区块可改
3. **AndroidManifest 补全**：补了 `INTERNET` 权限和 `usesCleartextTraffic="true"`，修了 release APK 网络不通的问题
4. **网络日志 URL 完整显示**：列表项的 URL 从 `maxLines: 1 + ellipsis` 改成 `SelectableText` 不限行

---

## 提问 / 求助时该提供的信息

如果 Agent 在改代码时遇到不确定的问题，向用户报告时带上：

1. **改动了哪些文件**（绝对路径）
2. **关键 diff**（不要全文，只贴改的部分）
3. **是否需要用户自己跑命令验证**（默认是需要的）
4. **如果你想让我跑命令就明确说**，否则我不会主动跑
