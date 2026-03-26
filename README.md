# 付费启动器 (NSIS Pay-to-Run Launcher)

基于 NSIS 的付费启动程序：用户扫码支付后才允许执行目标程序 `run.exe`。

## 架构

```
┌─────────────────┐      POST /create_order       ┌──────────────────┐
│  NSIS 安装器     │ ────────────────────────────→  │  后端验证服务     │
│  (PayLauncher)   │                               │  (Express/Node)  │
│                  │ ←── 二维码 URL ────────────── │                  │
│  [微信支付]       │                               │  ├─ Demo 模式     │
│  [支付宝]        │  GET /check_status?order_id=  │  ├─ 微信支付      │
│  [扫码→支付]     │ ────────────────────────────→  │  ├─ 支付宝       │
│                  │ ←── {"status":"paid"} ─────── │  └─ 聚合支付      │
│  验证通过 →      │                               │                  │
│  执行 run.exe    │                               │  支付回调通知      │
└─────────────────┘                               └──────────────────┘
```

## 目录结构

```
nsis-payment/
├── PayLauncher.nsi       # NSIS 主脚本
├── build.bat             # Windows 编译脚本
├── assets/               # 资源文件
│   ├── wechat_icon.bmp   # 微信图标 (需自备, 48x48)
│   ├── alipay_icon.bmp   # 支付宝图标 (需自备, 48x48)
│   └── curl.exe          # HTTP 请求工具
├── backend/
│   ├── server.js         # 后端验证服务
│   └── package.json
└── README.md
```

## 快速开始

### 1. 启动后端服务

```bash
cd backend
npm install
# Demo 模式（测试用）
PAYMENT_MODE=demo node server.js
```

### 2. 修改 NSIS 脚本

编辑 `PayLauncher.nsi`，找到这行并替换为你的服务器地址：

```nsis
StrCpy $PayApiUrl "https://your-server.com/api/payment"
```

Demo 模式下改为：
```nsis
StrCpy $PayApiUrl "http://localhost:3000/api/payment"
```

### 3. 准备文件

将你的目标程序放到项目根目录，命名为 `run.exe`。

### 4. 编译

Windows 上运行：
```cmd
build.bat
```

生成的 `PayLauncher.exe` 即为最终付费启动器。

### 5. 测试流程

1. 运行 `PayLauncher.exe`
2. 点击「微信支付」或「支付宝」
3. 扫码（Demo 模式会打开一个网页，点击即可模拟支付）
4. 点击「我已完成支付，点击验证」
5. 验证通过 → 自动执行 `run.exe`

## 支付模式

| 模式 | PAYMENT_MODE | 说明 |
|------|-------------|------|
| Demo | `demo` | 测试模式，扫码后点击网页模拟支付 |
| 微信支付 | `real_wxpay` | 需要微信商户号 + API v3 密钥 |
| 支付宝 | `real_alipay` | 需要支付宝开放平台应用 |
| 第三方聚合 | `third_party` | Payjs / 虎皮椒 / XorPay 等 |

## 生产环境部署

### 环境变量

```bash
# 微信支付
export WXPAY_MCHID=你的商户号
export WXPAY_APPID=你的AppID
export WXPAY_APIKEY=你的API密钥
export WXPAY_NOTIFY_URL=https://your-domain.com/api/payment/wxpay_notify

# 支付宝
export ALIPAY_APPID=你的应用ID
export ALIPAY_PRIVATE_KEY=你的私钥
export ALIPAY_PUBLIC_KEY=支付宝公钥
export ALIPAY_NOTIFY_URL=https://your-domain.com/api/payment/alipay_notify

# 选择支付模式
export PAYMENT_MODE=real_wxpay   # 或 real_alipay / third_party
```

### 用 PM2 运行

```bash
npm install -g pm2
pm2 start server.js --name pay-api -- PAYMENT_MODE=real_wxpay
pm2 save
pm2 startup
```

### Nginx 反向代理

```nginx
server {
    listen 443 ssl;
    server_name pay.your-domain.com;

    location /api/payment/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 安全注意事项

1. **生产环境必须验证支付回调签名**，防止伪造支付通知
2. 订单存储请用 Redis/MySQL，不要用内存 Map
3. 后端 API 建议加限流防止恶意刷单
4. `curl.exe` 建议用最新版，或改用 Windows 内置的 PowerShell `Invoke-WebRequest`
5. 支付金额不要硬编码在客户端，应在服务端控制

## 自定义

- **修改金额**：NSIS 脚本中 `StrCpy $ProductAmount "1.00"`
- **修改超时**：`StrCpy $MaxRetryCount "120"`（单位：次，每次间隔 2 秒）
- **修改 UI 文案**：`PaymentPage` 函数中的 `NSD_CreateLabel` 内容
