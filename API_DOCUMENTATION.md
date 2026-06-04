# File Serve API 文档

## 基础信息

- **HTTP 服务端口**: 3000
- **HTTPS 服务端口**: 3001
- **根路径**: 由 config.json 中的 rootPath 配置

---

## API 端点

### 1. 获取文件列表

**端点**: `GET /list/:filePath(*)`

**描述**: 获取指定目录下的文件列表

**URL 参数**:
| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| filePath | string | 是 | 文件路径，使用 `$` 代替 `/`，`$$` 表示根路径 |

**查询参数**:
| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| sta | number | 否 | 起始索引（分页） |
| end | number | 否 | 结束索引（分页） |

**响应示例**:
```json
{
  "listNum": 10,
  "list": [
    {
      "name": "example.jpg",
      "size": 102400,
      "isDirectory": false,
      "isFile": true,
      "suffix": ".jpg",
      "mtime": "2024-01-15T10:30:00.000Z"
    },
    {
      "name": "folder",
      "size": 0,
      "isDirectory": true,
      "isFile": false,
      "suffix": "",
      "mtime": "2024-01-15T09:00:00.000Z"
    }
  ]
}
```

**使用示例**:
- 获取根目录列表: `GET /list/$`
- 获取子目录列表: `GET /list$images$`
- 分页获取: `GET /list/$$?sta=0&end=10`

**错误响应**:
- 403: 非法路径访问（路径遍历攻击）
- 404: 文件夹不存在
- 500: 文件夹读取错误

---

### 2. 删除文件或文件夹

**端点**: `POST /delFile`

**描述**: 删除指定文件或文件夹（支持递归删除文件夹）

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "filePath": "images/photo.jpg"
}
```

或者删除文件夹：
```json
{
  "filePath": "images/folder"
}
```

| 字段 | 类型 | 必填 | 描述 |
|------|------|------|------|
| filePath | string | 是 | 要删除的文件或文件夹路径（相对于根路径） |

**响应示例**:
```json
{
  "msg": "删除成功"
}
```

**功能说明**:
- 支持删除文件
- 支持删除文件夹（包含文件夹内所有文件和子文件夹）
- 使用递归删除，删除文件夹时会同时删除其内容

**错误响应**:
- 400: 缺少文件路径
- 403: 非法路径访问（路径遍历攻击）
- 404: 文件或文件夹不存在
- 500: 删除失败

---

### 3. 重命名文件或文件夹

**端点**: `POST /renameFile`

**描述**: 重命名指定的文件或文件夹

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "oldPath": "images/old_name.jpg",
  "newPath": "images/new_name.jpg"
}
```

| 字段 | 类型 | 必填 | 描述 |
|------|------|------|------|
| oldPath | string | 是 | 原文件或文件夹路径（相对于根路径） |
| newPath | string | 是 | 新文件或文件夹路径（相对于根路径） |

**响应示例**:
```json
{
  "msg": "重命名成功"
}
```

**功能说明**:
- 支持重命名文件
- 支持重命名文件夹
- 新名称不能与同目录下已有文件/文件夹重名

**错误响应**:
- 400: 缺少旧路径或新路径
- 403: 非法路径访问（路径遍历攻击）
- 404: 原文件或文件夹不存在
- 409: 目标名称已存在
- 500: 重命名失败

---

### 4. 重启服务器

**端点**: `POST /restartServer`

**描述**: 重启服务器（需要密码验证）

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "pwd": "your_password"
}
```

| 字段 | 类型 | 必填 | 描述 |
|------|------|------|------|
| pwd | string | 是 | 重启密码（配置在 config.json 中的 restartPwd） |

**响应示例**:
```json
{
  "msg": "开始重启"
}
```

**错误响应**:
- 401: 密码错误

---

### 5. 清理旧缓存数据

**端点**: `GET /cleanOldData/:day`

**描述**: 清理指定天数之前的缓存数据

**URL 参数**:
| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| day | number | 是 | 天数，清理此天数之前的数据 |

**响应示例**:
```
清理旧文件成功
```

**使用示例**:
- 清理 7 天前的缓存: `GET /cleanOldData/7`

---

### 6. 获取视频预览缩略图

**端点**: `GET /getVideoPreview/:path(*)`

**描述**: 获取视频文件的缩略图（自动生成并缓存）

**URL 参数**:
| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| path | string | 是 | 视频文件路径（URL 编码） |

**响应**:
- **Content-Type**: `image/jpeg`
- **Content-Disposition**: `attachment; filename=video_preview.jpg`

**响应体**: 二进制图片数据

**功能说明**:
- 自动在视频的 00:00:01 时间点截取一帧
- 截图尺寸: 320x240
- 支持缓存，相同视频路径不会重复生成
- 缓存存储在配置的 imgCache 目录

**使用示例**:
```
GET /getVideoPreview/videos/movie.mp4
```

---

### 7. 获取文件（支持图片处理 + Range 请求）

**端点**: `GET /getFile/*`

**描述**: 获取服务器上的文件，支持图片实时缩放和 Range 断点续传

**URL 路径**: `/getFile/文件路径[!宽x高]`

| 参数 | 类型 | 必填 | 描述 |
|------|------|------|------|
| 文件路径 | string | 是 | 要获取的文件路径（相对于根路径） |
| 宽高 | string | 否 | 图片缩放尺寸，格式 `宽x高`（如 `800x600`） |

**支持的图片格式**: jpg, jpeg, png, gif, svg

#### Range 请求支持

该端点支持 HTTP Range 请求（RFC 7233），适用于视频播放拖动进度条和大文件断点续传。

**请求头**（可选）:
| Header | 格式 | 示例 |
|--------|------|------|
| Range | `bytes=start-end` | `Range: bytes=0-1023` |

- `start` 和 `end` 为字节偏移量（从 0 开始）
- `end` 可省略：`Range: bytes=1024-` 表示从 1024 到文件末尾

**响应（Range 请求）**:
- **状态码**: `206 Partial Content`
- **Content-Range**: `bytes start-end/total`（如 `bytes 0-1023/5242880`）
- **Accept-Ranges**: `bytes`
- **Content-Length**: 请求的字节区间长度
- **Content-Type**: 根据文件扩展名自动设置（基于 mime.json）

**响应（无效 Range 请求）**:
- **状态码**: `416 Range Not Satisfiable`
- **Content-Range**: `bytes */total`

#### 普通文件响应

**响应**:
- **Content-Type**: `application/octet-stream`
- **Content-Disposition**: `attachment; filename=0.jpg`

**图片处理功能**:
- 实时缩放：使用 sharp 库进行高质量图片缩放
- 缩放模式：`inside`（不放大，只缩小）
- 输出格式：渐进式 JPEG
- 自动缓存：处理后的图片会缓存到 imgCache 目录

**使用示例**:
- 获取原图: `GET /getFile/images/photo.jpg`
- 获取缩放图: `GET /getFile/images/photo.jpg!800x600`
- URL 编码路径: `GET /getFile/images/photo%20name.jpg!1024x768`
- Range 请求（前1024字节）: `Range: bytes=0-1023`
- Range 请求（跳转到指定位置）: `Range: bytes=1048576-`

**错误响应**:
- 403: 非法路径访问（路径遍历攻击）
- 416: 无效的Range请求范围
- 500: 图片处理失败

---

## 静态资源

### Web 前端
- **路径**: `/` (根路径)
- **目录**: `web/` 目录下的静态文件

### 文件服务
- **路径**: `/getFile/*`
- **根目录**: config.json 中配置的 rootPath

---

## 错误处理

所有 API 端点都包含以下安全措施：

1. **路径验证**: 防止路径遍历攻击（Path Traversal）
2. **路径规范化**: 使用 `path.normalize()` 处理路径
3. **访问控制**: 所有文件操作都限制在配置的根目录内

**常见错误码**:
| 状态码 | 描述 |
|--------|------|
| 400 | 请求参数错误 |
| 401 | 未授权（密码错误） |
| 403 | 禁止访问（路径遍历攻击拦截） |
| 404 | 资源不存在 |
| 409 | 冲突（目标名称已存在） |
| 416 | Range Not Satisfiable（请求的字节范围无效） |
| 500 | 服务器内部错误 |

---

## 配置说明

配置文件 `config.json` 包含以下配置项：

```json
{
  "rootPath": "/path/to/files",
  "imgCache": "./imgCache",
  "restartPwd": "your_password"
}
```

| 配置项 | 描述 |
|--------|------|
| rootPath | 服务器根目录路径 |
| imgCache | 图片缓存目录路径 |
| restartPwd | 重启服务器密码 |

---

## 图片缓存机制

### 缓存策略
1. **图片缩放**: 根据文件路径和尺寸生成 SHA256 哈希作为缓存键
2. **视频缩略图**: 根据视频路径生成 SHA256 哈希作为缓存键
3. **缓存更新**: 访问已缓存的文件时会更新其时间戳

### 缓存清理
- 使用 `/cleanOldData/:day` 端点清理指定天数前的缓存
- 缓存数据存储在 SQLite 数据库中（sqllite.js）

---

## 使用示例

### JavaScript 示例

```javascript
// 获取文件列表
const response = await fetch('http://localhost:3000/list/$');
const data = await response.json();
console.log(data.list);

// 删除文件
await fetch('http://localhost:3000/delFile', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ filePath: 'images/photo.jpg' })
});

// 删除文件夹（包含所有子文件和子文件夹）
await fetch('http://localhost:3000/delFile', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ filePath: 'images/folder' })
});

// 获取视频缩略图
const videoPreview = await fetch('http://localhost:3000/getVideoPreview/videos/movie.mp4');
const blob = await videoPreview.blob();

// 显示缩放后的图片
const img = document.createElement('img');
img.src = 'http://localhost:3000/getFile/images/photo.jpg!800x600';
document.body.appendChild(img);
```

### cURL 示例

```bash
# 获取文件列表
curl http://localhost:3000/list/$

# 删除文件
curl -X POST http://localhost:3000/delFile \
  -H "Content-Type: application/json" \
  -d '{"filePath":"images/photo.jpg"}'

# 删除文件夹（包含所有子文件和子文件夹）
curl -X POST http://localhost:3000/delFile \
  -H "Content-Type: application/json" \
  -d '{"filePath":"images/folder"}'

# 获取视频缩略图
curl -o video_preview.jpg http://localhost:3000/getVideoPreview/videos/movie.mp4

# 获取缩放图片
curl -o resized.jpg "http://localhost:3000/getFile/images/photo.jpg!800x600"

# Range 请求（获取前1024字节）
curl -H "Range: bytes=0-1023" -o partial.dat http://localhost:3000/getFile/videos/movie.mp4

# Range 请求（断点续传，从上次中断位置继续）
curl -H "Range: bytes=1048576-" -o resume.dat http://localhost:3000/getFile/videos/movie.mp4
```
