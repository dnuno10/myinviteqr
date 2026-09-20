"""Generates the sample photography used until a host uploads their own photo.
Run: python3 tool/gen_samples.py  (writes assets/samples/p{style}_{hue}.jpg)"""
import colorsys, math, random, os
from PIL import Image, ImageDraw, ImageFilter

W, H = 640, 800
HUES = [345, 10, 35, 105, 150, 190, 250, 285]  # must match _PhotoPlaceholder._variantHues

def col(h, s, l, a=255):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, l, s)
    return (int(r * 255), int(g * 255), int(b * 255), a)

def layer():
    return Image.new('RGBA', (W, H), (0, 0, 0, 0))

def gradient(top, bottom):
    im = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return im

def bokeh(base, h, n, seed, sizes=(20, 90), blur=2, alpha=(40, 110)):
    rnd = random.Random(seed)
    im = layer()
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x, y = rnd.randint(0, W), rnd.randint(0, H)
        r = rnd.randint(*sizes)
        c = col(h + rnd.randint(-25, 25), .75, rnd.uniform(.72, .9), rnd.randint(*alpha))
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    return Image.alpha_composite(base, im.filter(ImageFilter.GaussianBlur(blur)))

def petal(im, cx, cy, length, width, ang, c):
    p = Image.new('RGBA', (int(length * 2.4), int(length * 2.4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    ox, oy = p.width / 2, p.height / 2
    d.ellipse([ox - width, oy - length, ox + width, oy], fill=c)
    p = p.rotate(-ang, resample=Image.BICUBIC, center=(ox, oy))
    im.alpha_composite(p, (int(cx - ox), int(cy - oy)))

def rose(base, cx, cy, R, h, seed, blur=0.7):
    rnd = random.Random(seed)
    im = layer()
    # back shadow
    sh = layer(); ImageDraw.Draw(sh).ellipse([cx - R, cy - R * .9, cx + R, cy + R * 1.1], fill=col(h, .6, .25, 90))
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(R * .18)))
    rings = [(9, 1.0, .62), (8, .82, .68), (7, .64, .74), (6, .46, .80), (5, .3, .86), (4, .17, .9)]
    for k, (n, rr, l) in enumerate(rings):
        for i in range(n):
            a = i * 360 / n + rnd.uniform(-14, 14) + k * 21
            rad = math.radians(a)
            px, py = cx + math.sin(rad) * R * rr * .42, cy - math.cos(rad) * R * rr * .42
            c = col(h + rnd.uniform(-6, 6), .68, l + rnd.uniform(-.04, .05))
            petal(im, px, py, R * rr * .62, R * rr * .34, a, c)
            # soft rim highlight
            petal(im, px, py, R * rr * .5, R * rr * .2, a, col(h, .55, min(.95, l + .1), 90))
    ImageDraw.Draw(im).ellipse([cx - R * .16, cy - R * .16, cx + R * .16, cy + R * .16], fill=col(h + 8, .7, .78))
    ImageDraw.Draw(im).ellipse([cx - R * .08, cy - R * .08, cx + R * .08, cy + R * .08], fill=col(h + 20, .8, .68))
    return Image.alpha_composite(base, im.filter(ImageFilter.GaussianBlur(blur)))

def leaf(base, cx, cy, size, ang, h, l=.32):
    im = layer()
    petal(im, cx, cy, size, size * .32, ang, col(h, .45, l))
    petal(im, cx, cy, size * .8, size * .12, ang, col(h, .4, l + .1, 120))
    return Image.alpha_composite(base, im.filter(ImageFilter.GaussianBlur(.8)))

def make(style, h, seed):
    rnd = random.Random(seed * 100 + int(h))
    soft = col(h, .8, .93)
    deep = col(h, .55, .8)
    im = gradient(soft, deep)
    green = h + 120 if h < 200 else h + 60
    if style == 0:  # bouquet
        im = bokeh(im, h, 40, seed, (25, 80), 10)
        for x, y, a in [(90, 520, 40), (560, 470, -50), (330, 720, 5), (120, 200, 125), (540, 230, -120), (330, 130, 180)]:
            im = leaf(im, x, y, 190, a, 130)
        im = rose(im, 190, 300, 150, h, seed + 1, 1.0)
        im = rose(im, 460, 250, 120, h + 12, seed + 2, 1.2)
        im = rose(im, 330, 540, 190, h - 6, seed + 3, 0.6)
        im = rose(im, 520, 640, 100, h + 6, seed + 4, 1.4)
        im = rose(im, 110, 660, 90, h + 10, seed + 5, 1.4)
        im = bokeh(im, h + 15, 14, seed + 9, (14, 40), 3, (50, 120))
    elif style == 1:  # golden bokeh lights
        im = gradient(col(h, .5, .32), col(h + 18, .6, .55))
        im = bokeh(im, h + 30, 70, seed, (18, 70), 6, (60, 150))
        im = bokeh(im, h + 5, 30, seed + 4, (60, 130), 14, (35, 80))
        im = bokeh(im, h + 40, 25, seed + 5, (8, 24), 1, (120, 220))
    elif style == 2:  # scattered petals
        im = gradient(col(h, .7, .95), col(h, .6, .82))
        im = bokeh(im, h, 20, seed, (40, 110), 18, (40, 90))
        for _ in range(38):
            x, y = rnd.randint(0, W), rnd.randint(0, H)
            s = rnd.randint(50, 120)
            pl = layer()
            petal(pl, x, y, s, s * .5, rnd.randint(0, 359), col(h + rnd.randint(-10, 10), .7, rnd.uniform(.6, .85), rnd.randint(150, 235)))
            im = Image.alpha_composite(im, pl.filter(ImageFilter.GaussianBlur(rnd.choice([0.5, 1, 4, 9]))))
    else:  # botanical arrangement
        im = gradient(col(h, .55, .9), col(h + 10, .5, .78))
        im = bokeh(im, h + 20, 30, seed, (30, 90), 12, (40, 90))
        for _ in range(16):
            im = leaf(im, rnd.randint(0, W), rnd.randint(0, H), rnd.randint(120, 240), rnd.randint(0, 359), 125 + rnd.randint(-15, 15), rnd.uniform(.28, .42))
        im = rose(im, 320, 400, 210, h, seed + 1, 0.7)
        for _ in range(9):
            x, y = rnd.randint(40, 600), rnd.randint(40, 760)
            im = rose(im, x, y, rnd.randint(40, 70), h + rnd.randint(-14, 14), seed + rnd.randint(2, 99), 1.6)
    # vignette + light grain for a photographic feel
    vig = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(vig)
    d.ellipse([-W * .25, -H * .2, W * 1.25, H * 1.2], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(120))
    dark = Image.new('RGBA', (W, H), (40, 20, 30, 70))
    im = Image.composite(im, Image.alpha_composite(im, dark), vig)
    return im.convert('RGB')

os.makedirs('assets/samples', exist_ok=True)
for f in os.listdir('assets/samples'):
    os.remove(os.path.join('assets/samples', f))
for s in range(4):
    for i, h in enumerate(HUES):
        make(s, h, s + 3).save(f'assets/samples/p{s}_{i}.jpg', quality=84)
print('ok')
