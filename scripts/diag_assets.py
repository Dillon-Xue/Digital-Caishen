#!/usr/bin/env python3
"""诊断去水印区域：量化原始图 vs 当前图的右下角水印区颜色分布。

判断盲填色是否安全的核心指标：
- 原始图水印区 std 低（<~15/通道）→ 平坦背景，填色安全自然
- 原始图水印区 std 高（>~30）→ 有真实纹理/细节，盲填会留下纯色矩形露馅
- 当前图水印区 std≈0 → 确认是纯色平填（即存在露馅风险）
"""
from pathlib import Path
from PIL import Image

repo = Path("/home/dillon/Digital-Caishen")
backup = repo / "assets" / "source" / "clean_backup"
images = repo / "assets" / "images"

# (mask_x0, mask_y0, sample_y0, sample_y1)
repairs = {
    "caishen_shrine.png": (700, 960, 940, 960),
    "caishen_shrine_idle.png": (700, 960, 940, 960),
    "gold_ingot.png": (700, 900, 860, 900),
}


def stats(pixels, x0, y0, x1, y1):
    rs = gs = bs = rs2 = gs2 = bs2 = n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = pixels[x, y]
            rs += r; gs += g; bs += b
            rs2 += r * r; gs2 += g * g; bs2 += b * b
            n += 1
    if n == 0:
        return (0, 0, 0), (0, 0, 0)
    mr, mg, mb = rs / n, gs / n, bs / n
    sr = (max(0.0, rs2 / n - mr * mr)) ** 0.5
    sg = (max(0.0, gs2 / n - mg * mg)) ** 0.5
    sb = (max(0.0, bs2 / n - mb * mb)) ** 0.5
    return (mr, mg, mb), (sr, sg, sb)


def fmt(c):
    return "/".join(f"{v:.1f}" for v in c)


for name, (mx, my, sy0, sy1) in repairs.items():
    orig = Image.open(backup / name).convert("RGB")
    cur = Image.open(images / name).convert("RGB")
    op, cp = orig.load(), cur.load()
    w, h = orig.size

    omean, ostd = stats(op, mx, my, w, h)
    cmean, cstd = stats(cp, mx, my, w, h)
    smean, sstd = stats(op, mx, sy0, w, sy1)  # 水印上方干净背景样本

    print(f"== {name} ({w}x{h}) ==")
    print(f"  原始 水印区 : mean={fmt(omean)}  std={fmt(ostd)}")
    print(f"  原始 上方样本: mean={fmt(smean)}  std={fmt(sstd)}")
    print(f"  当前 水印区 : mean={fmt(cmean)}  std={fmt(cstd)}")
    # 判定
    verdict = "安全(平坦背景)" if ostd[0] < 15 and ostd[1] < 15 and ostd[2] < 15 else "危险(有细节纹理)"
    print(f"  盲填判定   : {verdict}  | 当前已平填(std~0={cstd[0]<2})")
    print()
