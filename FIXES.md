# 修复版 — PayLauncher_fixed.nsi

## 修复的问题

### 1. 布局溢出（按钮不可见/不可点）— 核心问题

**原问题**：所有控件布局延伸到 510u，但 nsDialogs 默认可用区域只有 ~335u 高。底部的「验证支付」按钮(440u)、退出按钮(474u)、版权文字(500u)全部被裁剪。

**修复**：
- 整体重排布局，所有控件压缩到 430u 以内
- 步骤指示器从 100u → 88u，高度缩减
- 支付按钮从 166u → 136u，高度缩减
- 二维码区域从 205u→168u 到 340u→334u
- 操作按钮从 440u/474u → 365u/393u
- 版权文字从 500u → 418u

### 2. 按钮背景色不生效（按钮显示为灰色）

**原问题**：`SetCtlColors $Button_Wechat ${COLOR_TEXT_LIGHT} ${COLOR_WECHAT}` 对标准按钮无效，NSIS 标准按钮不支持背景色修改。

**修复**：
- 改用 `${NSD_SetImage}` 将彩色 BMP 图片加载到按钮上
- 按钮文本为空 `""`，完全由 BMP 图片决定外观
- 移除所有无效的 `SetCtlColors` 按钮背景色调用

### 3. `calc()` 语法无效

**原问题**：`${NSD_CreateLabel} 12u 60u calc(100%-24u) 35u ""` — NSIS 不支持 CSS calc()。

**修复**：改为具体数值 `286u`。

### 4. `nsDialogs::Create /NOUNLOAD 1018` 标志废弃

**修复**：改为 `nsDialogs::Create 1018`。

### 5. GDI 资源泄漏

**原问题**：
- `${NSD_SetImage}` 返回的 HBITMAP 句柄未保存，无法释放
- 多个字体句柄从未调用 `DeleteFontObject`
- CreateStepIndicator 中创建的 `$0` 临时字体从未释放

**修复**：
- 新增 `$hQRBitmap` 变量保存二维码位图句柄
- 更新二维码前先调用 `${NSD_FreeImage} $hQRBitmap`
- 新增 `!macro CleanUpFonts` 统一释放所有字体和位图句柄
- 使用 `System::Call 'gdi32::DeleteObject'` 释放字体

### 6. 无边框容器

**原问题**：`${NSD_CreateLabel} 68u 222u 174u 174u ""` 只是空白 Label，无边框效果。

**修复**：改为 `${NSD_CreateGroupBox}`，自带边框绘制。

### 7. 无法关闭窗口

**原问题**：`PaymentPageLeave` 中 `$OrderId == ""` 时直接 `Abort`，用户在未创建订单时无法关闭窗口。

**修复**：`$OrderId == ""` 时改为 `Return`（允许正常退出）。

### 8. 未使用的变量

**清理**：移除声明但未使用的 `$Label_AmountUnit`、`$Icon_Header`、`$GroupBox_Pay` 等变量。

## 布局对比（Y 坐标）

| 控件 | 原始 | 修复后 |
|------|------|--------|
| 顶部横幅 | 0~55u | 0~50u |
| 金额区域 | 60~95u | 54~84u |
| 步骤指示器 | 100~140u | 88~115u |
| 支付方式 | 148~200u | 120~162u |
| 二维码区域 | 205~400u | 168~334u |
| 状态文字 | 418u | 348u |
| 验证按钮 | 440u | 365u |
| 退出按钮 | 474u | 393u |
| 版权文字 | 500u | 418u |
| **总高度** | **510u ❌** | **428u ✅** |

## 注意事项

1. **BMP 格式**：nsDialogs 要求 24-bit BMP（非 RLE 压缩），PIL 默认输出即为 24-bit，无需修改 `gen_assets.py`
2. **按钮 BMP 尺寸**：wechat_btn.bmp / alipay_btn.bmp 应为 130x26 像素以匹配按钮尺寸（原脚本为 135x30，需重新生成）
3. **测试**：编译后在 Windows 上运行验证所有按钮可点击、所有区域可见
