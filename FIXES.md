# 修复日志

## v2 - 2026-04-09

### PayLauncher.nsi（美化 UI 版）— 11 处修复

| # | 原始问题 | 修复 |
|---|---------|------|
| 1 | 缺少 GDI 句柄变量，图片加载后无法跟踪/释放 | 新增 `$hBitmap_QR`、`$hBitmap_Placeholder` 两个句柄变量 |
| 2 | 不创建目录，`$TEMP\PayLauncher\assets` 可能不存在 | 加 `CreateDirectory "$INSTDIR"` + `"$INSTDIR\assets"` |
| 3 | 硬编码 `$TEMP\PayLauncher` 路径 | 全部改用 `$INSTDIR`（由 `InstallDir` 统一管理） |
| 4 | 占位图从未加载 — `${NSD_CreateBitmap}` 创建了控件但没塞图片 | 创建后立即 `${NSD_SetImage}` 加载 `qr_placeholder.bmp` |
| 5 | GDI 对象泄漏 — 字体/图片句柄从未释放 | `nsDialogs::Show` 后用 `System::Call "gdi32::DeleteObject"` 清理 |
| 6 | curl.exe 未存在检查 | `IfFileExists` 检查，不存在时报错并 Return |
| 7 | curl 无超时，服务器无响应时永久阻塞 | 全部加 `--connect-timeout 10 --max-time 15` |
| 8 | `${NSD_SetImage}` 句柄用错变量 | 改用专用变量，加载前先释放旧句柄 |
| 9 | 二维码下载失败后继续加载 | 加 `IfFileExists` 检查 |
| 10 | 二次验证无超时 | 加 `--connect-timeout 5 --max-time 10` |
| 11 | 清理路径硬编码 | `RMDir /r` 改用 `$INSTDIR` |

### PayLauncher_fixed.nsi（浏览器轮询版）— 7 处修复

| # | 原始问题 | 修复 |
|---|---------|------|
| 1 | `SetTimer` 回调不工作 — 函数名字符串不能作回调参数 | 改用 `PeekMessage` 手动消息循环 + `SetTimer` 发 `WM_TIMER` 消息 |
| 2 | 路径不一致 | 全部统一为 `$INSTDIR`，加 `CreateDirectory` |
| 3 | curl.exe 不存在时报错信息不明 | 错误提示包含完整路径 |
| 4 | curl 无超时 | 全部加 `--connect-timeout` + `--max-time` |
| 5 | `last_response.txt` 路径硬编码 | 改用 `$INSTDIR\last_response.txt` |
| 6 | GDI 字体未清理 | 改用 `System::Call "gdi32::DeleteObject"` |
| 7 | `run.exe` 不存在时崩溃 | 加 `${If} ${FileExists}` 检查 |

## v3 - 2026-04-09

### 两个文件通用改动

| # | 改动 | 说明 |
|---|------|------|
| 1 | 窗口放大至 750x620 | 新增 `.onGUIInit`，通过 `GetSystemMetrics` + `SetWindowPos` 将 NSIS 安装器窗口放大并居中显示 |
| 2 | 路径统一到 `$TEMP\PayLauncher` | 移除 `$PLUGINSDIR` 依赖，所有文件（curl.exe、资源、请求体、响应诊断）统一释放/读写于 `$TEMP\PayLauncher` |
| 3 | 删除 `InitPluginsDir` | 不再使用 `$PLUGINSDIR`，改为直接 `CreateDirectory "$TEMP\PayLauncher"` |
| 4 | `$CurlPath` 直接赋值 | 预释放区段直接 `StrCpy $CurlPath "$TEMP\PayLauncher\curl.exe"`，页面函数不再需要 fallback 逻辑 |

## v1 - 初始版本

- 基础功能：NSIS 付费启动器 + 后端验证服务
- 支持微信支付/支付宝扫码
- Demo 模式测试
