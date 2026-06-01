# File Server Flutter

跨端文件浏览/管理 App，基于 Flutter 实现，用于浏览和播放后端文件服务器上的文件（视频、音频、图片、其他文件）。

## 功能特性

- 远程浏览后端文件服务器上的目录与文件
- 视频/音频/图片在线播放
- 列表/网格视图切换，文件排序与过滤
- 主题色自定义（深色/浅色 + 取色器）
- 网络请求日志查看器
- 外置播放器唤起（VLC）、系统分享
- 可配置后端服务器地址

## 技术栈

| 维度 | 选型 |
|---|---|
| 框架 | Flutter（SDK `^3.12.0`） |
| 路由 | `go_router ^14.6.2` |
| HTTP | `dio ^5.7.0` |
| 持久化 | `shared_preferences ^2.3.4` |
| 视频播放 | `video_player ^2.9.2` + `chewie ^1.8.5` |
| 音频播放 | `audioplayers ^6.1.0` |
| 图片缓存 | `cached_network_image ^3.4.1` |
| 主题色 | `flutter_colorpicker ^1.1.0` |
| 外部唤起 | `url_launcher ^6.3.1`、`share_plus ^10.1.4` |

## 支持平台

Android · iOS · Windows · macOS · Linux · Web

## 快速开始

### 前置条件

- Flutter SDK `^3.12.0`
- 后端文件服务器（默认 `http://localhost:3000`）

### 安装与运行

```bash
flutter pub get
flutter run -d chrome --no-web-resources-cdn   # 国内环境推荐
```

其他目标：

```bash
flutter run -d <device-id>
flutter build apk --release
flutter build web
```

### 后端地址配置

默认 `http://localhost:3000`。可在 App 内 **设置 → 服务设置** 中修改，改完返回主页会自动刷新文件列表。

## 项目结构

```
lib/
├── main.dart                       # 入口，初始化 StorageService
├── models/
│   └── file_info.dart              # 文件元数据模型
├── pages/
│   ├── home_page.dart              # 主页（文件列表 + 视图切换 + 各种弹窗）
│   ├── settings_page.dart          # 设置页
│   ├── video_player_page.dart      # 视频播放器（chewie + 上下集）
│   └── audio_player_page.dart      # 音频播放器
├── router/
│   └── app_router.dart             # GoRouter 配置
├── services/
│   ├── api_service.dart            # Dio 客户端（单例）
│   ├── storage_service.dart        # SharedPreferences 封装（单例）
│   └── network_log_service.dart    # 网络日志（ChangeNotifier）
├── utils/
│   ├── date_utils.dart
│   └── file_type_utils.dart
└── widgets/
    ├── file_icon.dart
    └── network_log_dialog.dart
```

## 后端 API

App 依赖后端服务提供以下接口：

| 接口 | 用途 |
|---|---|
| `GET  /list` | 列出目录文件 |
| `GET  /getFile` | 下载文件 |
| `GET  /getVideoPreview` | 视频预览流 |
| `POST /delFile` | 删除文件 |
| `POST /restartServer` | 重启服务 |

## 配套 Web 项目

本仓库仅包含 Flutter 端。配套的 Vue 3 网页版客户端在独立项目维护（已通过 `.gitignore` 排除）。

## 注意事项

- **Android Release**：确保 `android/app/src/main/AndroidManifest.xml` 已开启 `android:usesCleartextTraffic="true"`，否则 release 包所有 HTTP 请求会 `Connection failed`（debug 变体由 Flutter 自动塞 `INTERNET` 权限，但 release 没有）
- **Flutter Web 国内环境**：构建/运行时加 `--no-web-resources-cdn`，把 canvaskit 资源打包进 `build/web/`，避免 `Failed to fetch canvaskit.js`
- **后端地址变更后**：必须重新加载文件列表（`FileInfo.url` 在 `fromJson` 时就已拼接完成），设置页返回时已自动触发刷新

## 许可

MIT
