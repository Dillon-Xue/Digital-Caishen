#!/usr/bin/env python3
"""把 AI 生成图的假棋盘格背景转成真正的 alpha 透明。

策略：
1. 从图片左上角采样棋盘格的两种颜色（浅灰 + 白）。
2. 从四周边缘做洪水填充，把连通的、颜色接近棋盘格（含中间过渡色）的像素设为 alpha=0。
3. 主体（财神、金元宝）不接触边缘，因此保留不透明。
4. 右下角水印落在背景区，随背景一起透明，无需单独处理。

输出直接覆盖 assets/images/ 下的目标文件；源文件取自 clean_backup/。
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image


# 默认参数 tolerance=30, dilate_radius=4；可按图覆盖
TARGETS = {
    "caishen_shrine.png": {},
    "caishen_shrine_idle.png": {},
    "gold_ingot.png": {"tolerance": 65, "dilate_radius": 8},
}


def color_dist(c1, c2):
    """RGB/RGBA 的欧氏距离（忽略 alpha）。"""
    return ((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2) ** 0.5


def find_bg_colors(px, w, h, strip=24, max_colors=5):
    """从图片边缘条带采样背景色并聚类。

    主体不接触边缘，因此边缘像素一定是背景棋盘格。聚类后可同时覆盖：
    - 神台图的浅灰/白棋盘格
    - 金元宝图的深灰阴影棋盘格
    - 各色调之间的抗锯齿过渡色
    """
    colors = []
    coords = []
    # 上下边缘条带
    for x in range(w):
        for y in range(strip):
            coords.append((x, y))
            coords.append((x, h - 1 - y))
    # 左右边缘条带（不含已采的角）
    for y in range(strip, h - strip):
        for x in range(strip):
            coords.append((x, y))
            coords.append((w - 1 - x, y))

    for x, y in coords:
        c = px[x, y][:3]
        found = False
        for i, (cc, cnt) in enumerate(colors):
            if color_dist(c, cc) < 12:
                nc = (
                    (cc[0] * cnt + c[0]) // (cnt + 1),
                    (cc[1] * cnt + c[1]) // (cnt + 1),
                    (cc[2] * cnt + c[2]) // (cnt + 1),
                )
                colors[i] = (nc, cnt + 1)
                found = True
                break
        if not found:
            colors.append((c, 1))

    colors.sort(key=lambda x: -x[1])
    # 合并过于接近的颜色，取前 N 个
    merged = []
    for c, cnt in colors:
        if any(color_dist(c, mc) < 20 for mc in merged):
            continue
        merged.append(c)
        if len(merged) >= max_colors:
            break
    return merged


def is_bg(c, bg_colors, tolerance):
    """判断颜色是否接近任意背景主色。"""
    return any(color_dist(c, bc) <= tolerance for bc in bg_colors)


def _dilate(mask: bytearray, w: int, h: int, radius: int):
    """圆形膨胀掩码，用于吃掉主体边缘残留的棋盘格像素。"""
    if radius <= 0:
        return mask
    out = bytearray(mask)
    rr = radius * radius
    coords = [(dy, dx) for dy in range(-radius, radius + 1)
              for dx in range(-radius, radius + 1) if dy * dy + dx * dx <= rr]
    for y in range(h):
        base = y * w
        for x in range(w):
            if mask[base + x] == 0:
                continue
            for dy, dx in coords:
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w:
                    out[ny * w + nx] = 1
    return out


def process(src: Path, dst: Path, tolerance: int = 30, dilate_radius: int = 4):
    """纯 Pillow 实现，用扁平数组加速。"""
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    bg_colors = find_bg_colors(px, w, h)
    print(f"  背景色板: {bg_colors}, tolerance={tolerance}, dilate={dilate_radius}")

    data = list(im.getdata())  # 扁平元组序列
    n = w * h

    # 背景掩码
    bg = bytearray(n)
    for i, (r, g, b, a) in enumerate(data):
        if a == 0 or is_bg((r, g, b), bg_colors, tolerance):
            bg[i] = 1

    # 边缘种子
    visited = bytearray(n)
    q = deque()
    for x in range(w):
        q.append(x)              # 上边缘
        q.append((h - 1) * w + x)  # 下边缘
    for y in range(h):
        q.append(y * w)          # 左边缘
        q.append(y * w + w - 1)  # 右边缘

    # BFS（用索引而非坐标，减少开销）
    while q:
        i = q.popleft()
        if visited[i] or not bg[i]:
            continue
        visited[i] = 1
        x = i % w
        if x > 0 and not visited[i - 1]:
            q.append(i - 1)
        if x < w - 1 and not visited[i + 1]:
            q.append(i + 1)
        if i >= w and not visited[i - w]:
            q.append(i - w)
        if i < n - w and not visited[i + w]:
            q.append(i + w)

    # 膨胀：吃掉光环/阴影边缘残留的棋盘格
    visited = _dilate(visited, w, h, dilate_radius)

    # 应用透明
    out = [(0, 0, 0, 0) if visited[i] else data[i] for i in range(n)]
    im.putdata(out)
    im.save(dst, "PNG")


def main():
    repo = Path(__file__).resolve().parent.parent
    src_dir = repo / "assets" / "source" / "clean_backup"
    dst_dir = repo / "assets" / "images"
    dst_dir.mkdir(parents=True, exist_ok=True)

    for name, overrides in TARGETS.items():
        src = src_dir / name
        dst = dst_dir / name
        if not src.exists():
            print(f"跳过缺失: {src}", file=sys.stderr)
            continue
        print(f"处理 {name} ...")
        process(src, dst, **overrides)
        print(f"  已保存 {dst}")


if __name__ == "__main__":
    main()
