/**
 * 支付验证后端服务 (Node.js + Express)
 * 
 * 职责：
 *   1. /api/payment/create_order — 创建支付订单，返回二维码 URL
 *   2. /api/payment/check_status — 轮询支付状态
 * 
 * 支付对接方式（三选一）：
 *   方案A：接入真实微信/支付宝官方接口（需要商户资质）
 *   方案B：接入第三方聚合支付（如 Payjs、XorPay、虎皮椒）
 *   方案C：演示模式 — 直接模拟支付成功（用于测试）
 * 
 * 本文件同时实现了三种方案，通过环境变量 PAYMENT_MODE 切换。
 */

const express = require('express');
const crypto = require('crypto');
const axios = require('axios');
const app = express();

app.use(express.json());

// ========== 配置 ==========
const PORT = process.env.PORT || 3000;
const PAYMENT_MODE = process.env.PAYMENT_MODE || 'demo'; // demo | real_wxpay | real_alipay | third_party

// 微信支付商户配置（真实模式需要）
const WXPAY_CONFIG = {
  mchId: process.env.WXPAY_MCHID || '',
  appId: process.env.WXPAY_APPID || '',
  apiKey: process.env.WXPAY_APIKEY || '',
  notifyUrl: process.env.WXPAY_NOTIFY_URL || 'https://your-server.com/api/payment/wxpay_notify',
};

// 支付宝配置（真实模式需要）
const ALIPAY_CONFIG = {
  appId: process.env.ALIPAY_APPID || '',
  privateKey: process.env.ALIPAY_PRIVATE_KEY || '',
  alipayPublicKey: process.env.ALIPAY_PUBLIC_KEY || '',
  notifyUrl: process.env.ALIPAY_NOTIFY_URL || 'https://your-server.com/api/payment/alipay_notify',
};

// 第三方聚合支付配置
const THIRD_PARTY_CONFIG = {
  // 以 Payjs 为例，虎皮椒/XorPay 同理
  baseUrl: process.env.THIRD_PARTY_URL || 'https://payjs.cn/api',
  mchId: process.env.THIRD_PARTY_MCHID || '',
  key: process.env.THIRD_PARTY_KEY || '',
};

// ========== 内存订单存储（生产环境请用 Redis/MySQL）==========
const orders = new Map();

// ========== 通用接口 ==========

/**
 * 创建订单
 * POST /api/payment/create_order
 * Body: { order_id, amount, payment_type, product }
 * 返回: { code: 0, qr_url: "...", order_id: "..." }
 */
app.post('/api/payment/create_order', async (req, res) => {
  const { order_id, amount, payment_type, product } = req.body;

  if (!order_id || !amount || !payment_type) {
    return res.json({ code: -1, msg: '缺少必要参数' });
  }

  // 存储订单
  const order = {
    id: order_id,
    amount: parseFloat(amount),
    payment_type,
    product: product || 'default',
    status: 'pending',
    created_at: Date.now(),
    expire_at: Date.now() + 5 * 60 * 1000, // 5 分钟过期
  };
  orders.set(order_id, order);

  try {
    let qrUrl = '';

    switch (PAYMENT_MODE) {
      case 'demo':
        qrUrl = await createDemoOrder(order);
        break;
      case 'real_wxpay':
        qrUrl = await createWxpayOrder(order);
        break;
      case 'real_alipay':
        qrUrl = await createAlipayOrder(order);
        break;
      case 'third_party':
        qrUrl = await createThirdPartyOrder(order);
        break;
      default:
        qrUrl = await createDemoOrder(order);
    }

    return res.json({ code: 0, qr_url: qrUrl, pay_url: qrUrl, order_id });
  } catch (err) {
    console.error('创建订单失败:', err.message);
    return res.json({ code: -1, msg: '创建订单失败: ' + err.message });
  }
});

/**
 * 查询支付状态
 * GET /api/payment/check_status?order_id=xxx
 * 返回: { code: 0, status: "pending" | "paid" | "expired" }
 */
app.get('/api/payment/check_status', (req, res) => {
  const { order_id } = req.query;

  if (!order_id) {
    return res.json({ code: -1, msg: '缺少 order_id' });
  }

  const order = orders.get(order_id);

  if (!order) {
    return res.json({ code: 0, status: 'not_found' });
  }

  // 检查过期
  if (Date.now() > order.expire_at && order.status === 'pending') {
    order.status = 'expired';
    return res.json({ code: 0, status: 'expired' });
  }

  return res.json({ code: 0, status: order.status });
});

/**
 * 微信支付回调
 */
app.post('/api/payment/wxpay_notify', (req, res) => {
  try {
    const data = req.body;
    // 验签（真实环境必须验证签名）
    const orderId = data.out_trade_no;
    const tradeState = data.result_code;

    if (tradeState === 'SUCCESS') {
      const order = orders.get(orderId);
      if (order) {
        order.status = 'paid';
        order.paid_at = Date.now();
        console.log(`[WXPay] 订单 ${orderId} 支付成功`);
      }
    }

    res.send('<xml><return_code><![CDATA[SUCCESS]]></return_code></xml>');
  } catch (err) {
    console.error('微信支付回调处理失败:', err);
    res.send('<xml><return_code><![CDATA[FAIL]]></return_code></xml>');
  }
});

/**
 * 支付宝回调
 */
app.post('/api/payment/alipay_notify', (req, res) => {
  try {
    const data = req.body;
    const orderId = data.out_trade_no;
    const tradeStatus = data.trade_status;

    if (tradeStatus === 'TRADE_SUCCESS' || tradeStatus === 'TRADE_FINISHED') {
      const order = orders.get(orderId);
      if (order) {
        order.status = 'paid';
        order.paid_at = Date.now();
        console.log(`[Alipay] 订单 ${orderId} 支付成功`);
      }
    }

    res.send('success');
  } catch (err) {
    console.error('支付宝回调处理失败:', err);
    res.send('fail');
  }
});

// ========== Web 支付页面（链接支付模式）==========
// 手机扫码后打开此页面，页面内显示二维码 + 自动轮询状态
app.get('/api/payment/pay', (req, res) => {
  const { order_id } = req.query;
  const order = orders.get(order_id);

  if (!order) {
    return res.status(404).send('<html><body style="text-align:center;padding:50px;font-family:sans-serif"><h2>订单不存在</h2><p>请返回安装器重新创建订单</p></body></html>');
  }

  // 在 demo 模式下，生成模拟二维码（指向 demo_pay）
  const qrContent = PAYMENT_MODE === 'demo'
    ? `${req.protocol}://${req.get('host')}/api/payment/demo_pay?order_id=${order_id}`
    : (order.qr_url || '');

  const payTypeName = order.payment_type === 'wechat' ? '微信支付' : order.payment_type === 'alipay' ? '支付宝' : '扫码支付';

  res.send(`
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>支付 - ${order.product}</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: -apple-system, "微软雅黑", sans-serif; background:#f5f5f5; display:flex; justify-content:center; align-items:center; min-height:100vh; }
  .card { background:#fff; border-radius:16px; padding:32px 24px; width:340px; box-shadow:0 4px 24px rgba(0,0,0,0.08); text-align:center; }
  .title { font-size:18px; font-weight:700; color:#333; margin-bottom:4px; }
  .product { font-size:13px; color:#999; margin-bottom:20px; }
  .amount { font-size:32px; font-weight:700; color:#4361EE; margin-bottom:24px; }
  .amount span { font-size:18px; }
  .qr-box { background:#fafafa; border:1px solid #eee; border-radius:12px; padding:16px; margin-bottom:20px; display:inline-block; }
  .qr-box img { width:200px; height:200px; }
  .hint { font-size:12px; color:#999; margin-bottom:16px; }
  .status { font-size:13px; color:#4361EE; padding:10px; background:#f0f4ff; border-radius:8px; }
  .status.success { color:#00A854; background:#f0fff4; }
  .status.expired { color:#F5222D; background:#fff0f0; }
  .demo-btn { display:inline-block; margin-top:16px; padding:10px 24px; background:#4361EE; color:#fff; border-radius:8px; text-decoration:none; font-size:14px; }
</style>
</head>
<body>
<div class="card">
  <div class="title">软件激活</div>
  <div class="product">${order.product}</div>
  <div class="amount"><span>¥</span>${order.amount.toFixed(2)}</div>
  <div class="qr-box">
    <img id="qr" src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(qrContent)}" alt="QR Code">
  </div>
  <div class="hint">请使用${payTypeName}扫描上方二维码</div>
  <div class="status" id="status">等待支付...</div>
  ${PAYMENT_MODE === 'demo' ? '<a class="demo-btn" href="/api/payment/demo_pay?order_id=' + order_id + '">[Demo] 模拟支付成功</a>' : ''}
</div>
<script>
  const orderId = '${order_id}';
  function check() {
    fetch('/api/payment/check_status?order_id=' + orderId)
      .then(r => r.json())
      .then(d => {
        const el = document.getElementById('status');
        if (d.status === 'paid') {
          el.className = 'status success';
          el.textContent = '✅ 支付成功！请返回安装器继续';
        } else if (d.status === 'expired') {
          el.className = 'status expired';
          el.textContent = '⏰ 订单已过期，请返回安装器重新创建';
        }
      })
      .catch(() => {});
  }
  setInterval(check, 3000);
  check();
</script>
</body>
</html>
  `);
});

// ========== Demo 模式 ==========
// 用于开发测试，访问 /api/payment/demo_pay?order_id=xxx 手动模拟支付

app.get('/api/payment/demo_pay', (req, res) => {
  const { order_id } = req.query;
  const order = orders.get(order_id);

  if (!order) {
    return res.status(404).send('订单不存在');
  }

  order.status = 'paid';
  order.paid_at = Date.now();

  res.send(`
    <html><body style="text-align:center;padding:50px;font-family:sans-serif">
      <h2>✅ 模拟支付成功</h2>
      <p>订单号: ${order_id}</p>
      <p>金额: ¥${order.amount}</p>
      <p>支付方式: ${order.payment_type}</p>
      <p>现在可以关闭此页面，安装器会自动检测到支付状态。</p>
    </body></html>
  `);
});

// ========== 具体支付方案实现 ==========

/**
 * 方案A-Demo：返回一个指向模拟支付页面的 URL（用作二维码内容）
 */
async function createDemoOrder(order) {
  // 返回支付网页 URL（展示二维码 + 自动轮询状态）
  const url = `http://localhost:${PORT}/api/payment/pay?order_id=${order.id}`;
  console.log(`[Demo] 订单 ${order.id} 创建成功，金额 ¥${order.amount}`);
  console.log(`[Demo] 支付页面: ${url}`);
  return url;
}

/**
 * 方案B-微信支付：统一下单获取二维码链接
 * 需要微信支付商户号 + API v3 密钥
 */
async function createWxpayOrder(order) {
  const nonceStr = crypto.randomBytes(16).toString('hex');
  const timestamp = Math.floor(Date.now() / 1000).toString();

  const body = {
    appid: WXPAY_CONFIG.appId,
    mchid: WXPAY_CONFIG.mchId,
    description: `软件激活 - ${order.product}`,
    out_trade_no: order.id,
    notify_url: WXPAY_CONFIG.notifyUrl,
    amount: {
      total: Math.round(order.amount * 100), // 转为分
      currency: 'CNY',
    },
  };

  // 微信支付 API v3 签名
  const signStr = `POST\n/v3/native\n${timestamp}\n${nonceStr}\n${JSON.stringify(body)}\n`;
  const sign = crypto
    .createHmac('sha256', WXPAY_CONFIG.apiKey)
    .update(signStr)
    .digest('base64');

  const authorization = `WECHATPAY2-SHA256-RSA2048 mchid="${WXPAY_CONFIG.mchId}",nonce_str="${nonceStr}",timestamp="${timestamp}",signature="${sign}"`;

  const resp = await axios.post(
    'https://api.mch.weixin.qq.com/v3/pay/transactions/native',
    body,
    { headers: { Authorization: authorization } }
  );

  // 返回二维码链接
  return resp.data.code_url;
}

/**
 * 方案C-支付宝：预创建获取二维码链接
 * 需要支付宝开放平台应用
 */
async function createAlipayOrder(order) {
  // 使用 alipay-sdk-nodejs 或手动构造
  // 这里给出简化的调用示例
  const bizContent = JSON.stringify({
    out_trade_no: order.id,
    total_amount: order.amount.toFixed(2),
    subject: `软件激活 - ${order.product}`,
    qr_code_mode: '2', // 返回二维码链接
  });

  const params = {
    app_id: ALIPAY_CONFIG.appId,
    method: 'alipay.trade.precreate',
    charset: 'utf-8',
    sign_type: 'RSA2',
    timestamp: new Date().toISOString().replace('T', ' ').substring(0, 19),
    version: '1.0',
    notify_url: ALIPAY_CONFIG.notifyUrl,
    biz_content: bizContent,
  };

  // 生成签名（简化版，生产环境用 alipay-sdk）
  const signStr = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');

  params.sign = crypto
    .createSign('RSA-SHA256')
    .update(signStr)
    .sign(ALIPAY_CONFIG.privateKey, 'base64');

  const resp = await axios.get('https://openapi.alipay.com/gateway.do', { params });
  return resp.data.alipay_trade_precreate_response.qr_code;
}

/**
 * 方案D-第三方聚合支付（以 Payjs 为例）
 */
async function createThirdPartyOrder(order) {
  const params = {
    mchid: THIRD_PARTY_CONFIG.mchId,
    total_fee: Math.round(order.amount * 100),
    out_trade_no: order.id,
    body: `软件激活`,
    notify_url: `https://your-server.com/api/payment/third_party_notify`,
  };

  // Payjs 签名
  const signStr = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&') + `&key=${THIRD_PARTY_CONFIG.key}`;
  params.sign = crypto.createHash('md5').update(signStr).digest('hex').toUpperCase();

  const resp = await axios.post(`${THIRD_PARTY_CONFIG.baseUrl}/native`, params);
  return resp.data.code_url;
}

// ========== 清理过期订单（定时任务）==========
setInterval(() => {
  const now = Date.now();
  for (const [id, order] of orders) {
    if (now > order.expire_at + 60000) { // 过期后 1 分钟清理
      orders.delete(id);
      console.log(`[清理] 删除过期订单: ${id}`);
    }
  }
}, 60000);

// ========== 启动 ==========
app.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`  支付验证服务启动`);
  console.log(`  端口: ${PORT}`);
  console.log(`  模式: ${PAYMENT_MODE}`);
  console.log(`========================================`);
  console.log('');
  console.log('接口:');
  console.log(`  POST /api/payment/create_order  — 创建订单`);
  console.log(`  GET  /api/payment/check_status  — 查询状态`);
  console.log(`  GET  /api/payment/demo_pay      — [Demo] 模拟支付`);
  console.log('');
});
