"""生成 NSIS 支付界面所需的 BMP 资源文件"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = "/root/.openclaw/workspace/nsis-payment/assets"
os.makedirs(OUT, exist_ok=True)

# 颜色定义
HEADER_BG    = (43, 45, 66)      # #2B2D42 深蓝灰
WECHAT_GREEN = (7, 193, 96)      # #07C160
ALIPAY_BLUE  = (22, 119, 255)    # #1677FF
ACCENT_BLUE  = (67, 97, 238)     # #4361EE
WHITE        = (255, 255, 255)
LIGHT_GRAY   = (240, 240, 240)
BORDER_GRAY  = (220, 220, 220)

def create_header_bg():
    """顶部横幅背景 - 渐变深色"""
    w, h = 318, 55  # NSIS dialog units → roughly 318px wide
    img = Image.new("RGB", (w, h), HEADER_BG)
    draw = ImageDraw.Draw(img)
    # 底部高光线
    for i in range(3):
        y = h - 3 + i
        alpha = 20 - i * 6
        color = (HEADER_BG[0]+alpha, HEADER_BG[1]+alpha, HEADER_BG[2]+alpha)
        draw.line([(0, y), (w, y)], fill=color)
    img.save(os.path.join(OUT, "header_bg.bmp"), "BMP")
    print("✓ header_bg.bmp")

def create_btn(text, color, filename):
    """创建彩色按钮 BMP"""
    w, h = 135, 30
    img = Image.new("RGB", (w, h), color)
    draw = ImageDraw.Draw(img)
    # 底部深色条（立体感）
    darker = tuple(max(0, c - 30) for c in color)
    draw.rectangle([(0, h-2), (w, h)], fill=darker)
    # 文字
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) // 2, (h - th) // 2 - 1), text, fill=WHITE, font=font)
    img.save(os.path.join(OUT, filename), "BMP")
    print(f"✓ {filename}")

def create_qr_placeholder():
    """二维码占位图"""
    w, h = 164, 164
    img = Image.new("RGB", (w, h), WHITE)
    draw = ImageDraw.Draw(img)
    # 边框
    draw.rectangle([(0, 0), (w-1, h-1)], outline=BORDER_GRAY, width=2)
    # 虚线网格效果
    for x in range(20, w-20, 20):
        draw.line([(x, 20), (x, h-20)], fill=LIGHT_GRAY, width=1)
    for y in range(20, h-20, 20):
        draw.line([(20, y), (w-20, y)], fill=LIGHT_GRAY, width=1)
    # 中间二维码图标
    cx, cy = w // 2, h // 2
    # 外框
    draw.rectangle([(cx-30, cy-30), (cx+30, cy+30)], outline=ACCENT_BLUE, width=3)
    # 内框
    draw.rectangle([(cx-15, cy-15), (cx+15, cy+15)], outline=ACCENT_BLUE, width=2)
    # 角落方块
    for dx, dy in [(-22, -22), (22, -22), (-22, 22), (22, 22)]:
        draw.rectangle([(cx+dx-5, cy+dy-5), (cx+dx+5, cy+dy+5)], fill=ACCENT_BLUE)
    # 提示文字
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 9)
    except:
        font = ImageFont.load_default()
    text = "Select payment"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((w - tw) // 2, cy + 40), text, fill=(136, 136, 136), font=font)
    img.save(os.path.join(OUT, "qr_placeholder.bmp"), "BMP")
    print("✓ qr_placeholder.bmp")

def create_step_done():
    """步骤完成标记"""
    w, h = 20, 20
    img = Image.new("RGB", (w, h), ACCENT_BLUE)
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
    except:
        font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), "✓", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w-tw)//2, (h-th)//2-1), "✓", fill=WHITE, font=font)
    img.save(os.path.join(OUT, "step_done.bmp"), "BMP")
    print("✓ step_done.bmp")

if __name__ == "__main__":
    create_header_bg()
    create_btn("  WeChat Pay", WECHAT_GREEN, "wechat_btn.bmp")
    create_btn("  Alipay", ALIPAY_BLUE, "alipay_btn.bmp")
    create_qr_placeholder()
    create_step_done()
    print(f"\n所有资源已生成到 {OUT}/")
