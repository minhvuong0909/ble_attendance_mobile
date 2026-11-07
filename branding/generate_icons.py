"""Sinh logo và toàn bộ biểu tượng của ứng dụng từ một hình học duy nhất.

Biểu tượng: dấu tích (điểm danh) phát ra hai cung sóng (BLE) trên nền xanh lá.
Chạy: python branding/generate_icons.py  (cần Pillow)
Kết quả: branding/logo.svg, web/public/{logo,favicon}.svg, biểu tượng Android và logo trong app Flutter.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "mobile" / "ble_attendance_mobile"
RES = APP / "android" / "app" / "src" / "main" / "res"

GREEN = (11, 110, 79)  # #0B6E4F, trùng màu chủ đạo của app
WHITE = (255, 255, 255)
SIZE = 1024  # hệ tọa độ gốc

CHECK = [(268, 566), (428, 722), (686, 388)]  # dấu tích
CHECK_WIDTH = 96
ARC_CENTER = (686, 388)  # các cung tỏa ra từ đỉnh dấu tích
ARCS = [(128, 38), (232, 38)]  # (bán kính, độ dày)
ARC_FROM, ARC_TO = -78, 12  # độ, 0 = hướng đông, âm = lên trên


def _arc_points(radius: float, steps: int = 40):
    cx, cy = ARC_CENTER
    for i in range(steps + 1):
        angle = math.radians(ARC_FROM + (ARC_TO - ARC_FROM) * i / steps)
        yield cx + radius * math.cos(angle), cy + radius * math.sin(angle)


def svg(background: bool = True) -> str:
    check = " ".join(f"{x},{y}" for x, y in CHECK)
    arcs = []
    for radius, width in ARCS:
        pts = list(_arc_points(radius))
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        arcs.append(
            f'<path d="M{x0:.1f},{y0:.1f} A{radius},{radius} 0 0 1 {x1:.1f},{y1:.1f}" '
            f'fill="none" stroke="#fff" stroke-width="{width}" stroke-linecap="round"/>'
        )
    bg = f'<rect width="{SIZE}" height="{SIZE}" rx="232" fill="#0B6E4F"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" role="img" '
        f'aria-label="Điểm danh BLE">{bg}'
        f'<polyline points="{check}" fill="none" stroke="#fff" stroke-width="{CHECK_WIDTH}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>{"".join(arcs)}</svg>\n'
    )


def render(size: int, background: str, mark_scale: float = 1.0) -> Image.Image:
    """background: 'rounded' (nền bo góc), 'full' (nền tràn), 'none' (trong suốt)."""
    scale = 4  # siêu lấy mẫu để mép mịn
    big = size * scale
    k = big / SIZE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if background == "rounded":
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=232 * k, fill=GREEN)
    elif background == "full":
        draw.rectangle([0, 0, big, big], fill=GREEN)

    def tx(p):  # thu nhỏ quanh tâm khi cần vùng an toàn
        return (SIZE / 2 + (p[0] - SIZE / 2) * mark_scale) * k, (SIZE / 2 + (p[1] - SIZE / 2) * mark_scale) * k

    def stroke_line(points, width):
        pts = [tx(p) for p in points]
        w = width * mark_scale * k
        draw.line(pts, fill=WHITE, width=round(w), joint="curve")
        for x, y in (pts[0], pts[-1]):
            draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)

    stroke_line(CHECK, CHECK_WIDTH)
    for radius, width in ARCS:
        cx, cy = tx(ARC_CENTER)
        r = radius * mark_scale * k
        w = width * mark_scale * k
        draw.arc([cx - r, cy - r, cx + r, cy + r], ARC_FROM, ARC_TO, fill=WHITE, width=round(w))
        for angle in (ARC_FROM, ARC_TO):  # đầu cung bo tròn
            ex = cx + (r - w / 2) * math.cos(math.radians(angle))
            ey = cy + (r - w / 2) * math.sin(math.radians(angle))
            draw.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=WHITE)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    (ROOT / "branding" / "logo.svg").write_text(svg(), encoding="utf-8")
    web_public = ROOT / "web" / "public"
    (web_public / "logo.svg").write_text(svg(), encoding="utf-8")
    (web_public / "favicon.svg").write_text(svg(), encoding="utf-8")

    # Android: biểu tượng thích ứng (nền + hình) và bản cũ cho máy dưới Android 8.
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, factor in densities.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        render(round(48 * factor), "rounded").save(folder / "ic_launcher.png")
        # Vùng an toàn của icon thích ứng là 66% ở giữa.
        render(round(108 * factor), "none", mark_scale=0.62).save(folder / "ic_launcher_foreground.png")
    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#0B6E4F</color>\n</resources>\n',
        encoding="utf-8",
    )
    # Màn hình chờ khi mở app.
    render(288, "rounded").save(RES / "drawable" / "splash_logo.png")

    # Logo trong app Flutter (màn hình đăng nhập).
    assets = APP / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)
    render(512, "rounded").save(assets / "logo.png")
    print("Đã sinh logo và biểu tượng.")


if __name__ == "__main__":
    main()
