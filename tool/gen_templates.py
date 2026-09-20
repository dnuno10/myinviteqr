#!/usr/bin/env python3
"""Generates the colour palettes and the 50 invitation templates.
Outputs: supabase/migrations/004_palettes_templates.sql and tool/templates_data.dart (used by tool/template_preview.dart)."""
import colorsys, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360, max(0, min(1, l)), max(0, min(1, s)))
    return '#%02X%02X%02X' % (round(r * 255), round(g * 255), round(b * 255))

# ---------------------------------------------------------------- palettes
HUES = [('Rose', 350), ('Coral', 12), ('Orange', 30), ('Amber', 46), ('Olive', 90), ('Green', 140),
        ('Teal', 172), ('Sky', 204), ('Blue', 228), ('Violet', 262), ('Orchid', 292), ('Pink', 326)]
MOODS = [
    ('Pastel', 'light', lambda h: dict(bg=hsl(h, .6, .96), ink=hsl(h, .3, .22), accent=hsl(h, .55, .62), accent2=hsl(h + 35, .6, .7), soft=hsl(h, .5, .9))),
    ('Cream', 'light', lambda h: dict(bg='#FBF6EE', ink=hsl(h, .3, .2), accent=hsl(h, .5, .45), accent2=hsl(h + 22, .55, .62), soft=hsl(h, .35, .88))),
    ('Night', 'dark', lambda h: dict(bg=hsl(h, .4, .12), ink=hsl(h, .2, .95), accent=hsl(h, .7, .68), accent2=hsl(h + 40, .75, .72), soft=hsl(h, .32, .22))),
    ('Vivid', 'vivid', lambda h: dict(bg=hsl(h, .78, .52), ink='#FFFFFF', accent=hsl(h + 45, .95, .66), accent2=hsl(h + 180, .8, .68), soft=hsl(h, .65, .42))),
    ('Blush', 'light', lambda h: dict(bg=hsl(h, .7, .92), ink=hsl(h, .45, .25), accent=hsl(h, .6, .5), accent2=hsl(h - 25, .65, .68), soft=hsl(h, .6, .84))),
    ('Muted', 'light', lambda h: dict(bg=hsl(h, .18, .93), ink=hsl(h, .25, .2), accent=hsl(h, .28, .45), accent2=hsl(h + 25, .3, .6), soft=hsl(h, .2, .85))),
    ('Deep', 'dark', lambda h: dict(bg=hsl(h, .5, .22), ink='#F7EFE2', accent=hsl(42, .75, .66), accent2=hsl(h + 30, .5, .68), soft=hsl(h, .42, .3))),
    ('Gold', 'light', lambda h: dict(bg='#FFFDF8', ink=hsl(h, .4, .15), accent=hsl(42, .62, .5), accent2=hsl(h, .4, .4), soft=hsl(h, .3, .92))),
    ('Candy', 'light', lambda h: dict(bg='#FFFFFF', ink=hsl(h, .5, .2), accent=hsl(h, .82, .6), accent2=hsl(h + 120, .75, .62), soft=hsl(h + 60, .7, .92))),
    ('Mono', 'light', lambda h: dict(bg=hsl(h, .08, .95), ink=hsl(h, .1, .12), accent=hsl(h, .5, .5), accent2=hsl(h, .3, .7), soft=hsl(h, .08, .88))),
]
CLASSICS = [
    ('Blush & Sage', 'light', '#FBF3EF', '#3E3A36', '#D98C8C', '#9DB59A', '#EFDDD6'),
    ('Navy & Gold', 'dark', '#101B33', '#F6EFDD', '#D4AF62', '#8FA6D6', '#1C2B4D'),
    ('Ivory & Emerald', 'light', '#FBF8F0', '#1F3B2D', '#2E7D5B', '#C9A55C', '#E7EFE4'),
    ('Terracotta & Cream', 'light', '#FBF4EA', '#4A2C22', '#C8613F', '#E0A96D', '#F3DFC9'),
    ('Lavender & Mint', 'light', '#F7F4FD', '#37305A', '#8E7CC3', '#7BCBB0', '#E8E2F7'),
    ('Black & Gold', 'dark', '#0F0F10', '#F4EBD6', '#C9A24B', '#8A7A55', '#232324'),
    ('Peach & Teal', 'light', '#FFF5EF', '#173F46', '#F08A6B', '#2F8F9D', '#FBE2D6'),
    ('Sunshine & Sky', 'vivid', '#FFD94A', '#1F2A44', '#3AA0FF', '#FF6B6B', '#FFEB9A'),
    ('Berry & Blush', 'light', '#FFF4F6', '#4A1730', '#B5245B', '#F29CB4', '#FBDDE5'),
    ('Forest & Sand', 'dark', '#16281F', '#F1E9D6', '#C9B27C', '#7FA88B', '#22392D'),
    ('Ocean & Coral', 'light', '#F2FAFB', '#0F3B4A', '#FF7F6B', '#1B8FA3', '#D6EEF2'),
    ('Powder Blue & Silver', 'light', '#F1F6FC', '#2C3A52', '#7AA5D9', '#A9B4C2', '#DCE8F6'),
]
PALS = {}
def add_pal(name, tone, c):
    PALS[name] = dict(name=name, tone=tone, colors=c)
for hn, h in HUES:
    for mn, tone, fn in MOODS:
        add_pal(f'{hn} {mn}', tone, fn(h))
for n, tone, bg, ink, a, a2, soft in CLASSICS:
    add_pal(n, tone, dict(bg=bg, ink=ink, accent=a, accent2=a2, soft=soft))
assert len(PALS) >= 100, len(PALS)

def P(name):
    return PALS[name]['colors']

# ---------------------------------------------------------------- layer helpers
def clean(d):
    return {k: (round(v, 4) if isinstance(v, float) else v) for k, v in d.items() if v is not None}

def T(x, y, w, h, tx=None, b=None, f='Inter', s=.05, c='ink', a='center', wt=None, i=None, ls=None, u=None, r=None, o=None, lh=None, va=None, lk=None):
    return clean(dict(t='text', x=x, y=y, w=w, h=h, tx=tx, b=b, f=f, s=s, c=c, a=(None if a == 'center' else a), wt=wt, i=i, ls=ls, u=u, r=r, o=o, lh=lh, va=va, lk=lk))

def PH(x, y, w, h, sh='rect', r=None, bw=None, bc=None, pol=None, rd=None, lk=None, z=None):
    return clean(dict(t='photo', x=x, y=y, w=w, h=h, sh=(None if sh == 'rect' else sh), r=r, bw=bw, bc=bc, pol=pol, rd=rd, lk=lk, z=z))

def SH(sh, x, y, w, h, fl='soft', o=None, r=None, sc=None, sw=None, rd=None, lk=True):
    return clean(dict(t='shape', sh=sh, x=x, y=y, w=w, h=h, fl=fl, o=o, r=r, sc=sc, sw=sw, rd=rd, lk=lk))

def D(k, x, y, w, h, c1='accent', c2='accent2', c3='soft', sd=1, r=None, o=None, lk=True):
    return clean(dict(t='deco', k=k, x=x, y=y, w=w, h=h, c1=c1, c2=c2, c3=c3, sd=sd, r=r, o=o, lk=lk))

def RS(x, y, w, h, lb='Confirm attendance', st='solid', c='accent', f='Inter', s=.036, sh='pill', wt=None):
    return clean(dict(t='rsvp', x=x, y=y, w=w, h=h, lb=lb, st=st, c=c, f=f, s=s, sh=(None if sh == 'pill' else sh), wt=wt))

def QR(x, y, w):
    return clean(dict(t='qr', x=x, y=y, w=w, h=w))

# ---------------------------------------------------------------- shared blocks
def msg(y, v, w=.76, txt='We would love to celebrate with you.', c='ink', h=.09):
    x = (1 - w) / 2
    return T(x, y, w, h, tx=txt, f=v['bf'], s=.034, c=c, o=.85, va='top', lh=1.35)

def info(y, v, style='center', c='ink', qr=True, rs_c='accent'):
    """Details + RSVP. Returns (layers, end_y)."""
    L = []
    bf = v['bf']
    if style == 'center':
        L += [T(.08, y, .84, .06, b='datetime', f=bf, s=.036, c=c, wt=600),
              T(.14, y + .075, .72, .1, b='place', f=bf, s=.032, c=c, o=.85, va='top', lh=1.3),
              RS(.2, y + .21, .6, .085, c=rs_c, f=bf)]
        end = y + .31
    elif style == 'cols':
        for i, (lab, bind) in enumerate([('DATE', 'datesh'), ('TIME', 'time'), ('PLACE', 'venue')]):
            x = .05 + i * .3
            L += [T(x, y, .3, .04, tx=lab, f=bf, s=.022, c='accent', wt=700, ls=.25), T(x, y + .045, .3, .09, b=bind, f=v['hf'], s=.04, c=c, va='top')]
        L += [SH('rect', .06, y - .02, .88, .003, fl=c, o=.3), T(.1, y + .16, .8, .05, b='address', f=bf, s=.028, c=c, o=.75), RS(.2, y + .23, .6, .085, c=rs_c, f=bf)]
        end = y + .33
    elif style == 'bigdate':
        L += [T(.06, y, .4, .04, b='weekday', f=bf, s=.026, c='accent', wt=700, ls=.3, a='right'),
              T(.06, y + .04, .4, .2, b='day', f=v['hf'], s=.2, c=c, a='right', lh=1),
              T(.5, y + .045, .44, .05, b='month', f=bf, s=.036, c=c, a='left', wt=700, ls=.2),
              T(.5, y + .1, .44, .04, b='year', f=bf, s=.03, c=c, a='left', o=.8),
              T(.5, y + .15, .44, .05, b='time', f=bf, s=.03, c=c, a='left', o=.8),
              SH('rect', .485, y + .02, .004, .2, fl='accent', lk=True),
              T(.1, y + .27, .8, .08, b='place', f=bf, s=.03, c=c, o=.85, va='top', lh=1.3),
              RS(.2, y + .38, .6, .085, c=rs_c, f=bf)]
        end = y + .47
    else:  # 'ticket'
        L += [SH('round', .08, y, .84, .34, fl='soft', rd=.1),
              T(.12, y + .03, .76, .05, b='datetime', f=bf, s=.033, c=c, wt=700),
              T(.14, y + .1, .72, .09, b='place', f=bf, s=.03, c=c, o=.85, va='top', lh=1.3),
              RS(.22, y + .22, .56, .08, c=rs_c, f=bf)]
        end = y + .38
    if qr:
        L += [T(.3, end + .03, .4, .035, tx='Scan to open the invitation', f=bf, s=.024, c=c, o=.7), QR(.4, end + .07, .2)]
        end += .3
    return L, end

def deco_corners(v, sd=1, k=None, c1='accent', c2='accent2', c3='soft', y0=.62):
    k = k or v.get('corner', 'flowers')
    return [D(k, -.1, y0, .36, .36, c1, c2, c3, sd=sd, lk=True),
            D(k, .74, y0, .36, .36, c1, c2, c3, sd=sd + 4, r=90, lk=True)]

# ---------------------------------------------------------------- archetypes
def arch_hero(v):
    L = []
    if v.get('corner'): L += deco_corners(v)
    L += [T(.1, .07, .8, .05, tx=v.get('kicker', 'YOU ARE INVITED TO'), f=v['bf'], s=.028, c='accent', wt=600, ls=.3),
          SH('arch', .16, .13, .68, .84, fl='none', sc='accent', sw=.004),
          PH(.2, .16, .6, .78, sh='arch'),
          T(.06, .99, .88, .22, b='title', f=v['sf'], s=v.get('ts', .13), c='ink', lh=1.05),
          D('divider', .3, 1.24, .4, .04, 'accent', 'accent2')]
    I, end = info(1.33, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def polaroid_trio(v):
    L = [D(v.get('deco', 'tape'), .14, .05, .16, .04, 'accent2', sd=3, r=-20, lk=True) if False else None]
    L = []
    if v.get('deco'): L.append(D(v['deco'], 0, 0, 1, 1.1, sd=5))
    L += [PH(.06, .1, .46, .56, pol=True, bw=.03, r=-5), PH(.46, .18, .46, .56, pol=True, bw=.03, r=5),
          PH(.24, .58, .44, .5, pol=True, bw=.03, r=-2),
          D('tape', .2, .08, .14, .035, 'accent2', r=-25), D('tape', .68, .16, .14, .035, 'accent', r=20), D('tape', .42, .56, .14, .035, 'accent2', r=6),
          T(.06, 1.2, .88, .06, tx=v.get('kicker', "LET'S CELEBRATE"), f=v['bf'], s=.03, c='accent', wt=700, ls=.3),
          T(.04, 1.27, .92, .22, b='title', f=v['sf'], s=v.get('ts', .14), c='ink', lh=1.05)]
    I, end = info(1.56, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def full_bleed(v):
    L = [PH(0, 0, 1, 1.3, lk=False), SH('rect', 0, .66, 1, .64, fl='black', o=.42)]
    L += [T(.08, .78, .84, .06, tx=v.get('kicker', 'YOU ARE INVITED TO'), f=v['bf'], s=.03, c='white', wt=600, ls=.3),
          T(.06, .85, .88, .28, b='title', f=v['sf'], s=v.get('ts', .15), c='white', lh=1.05),
          T(.1, 1.15, .8, .06, b='datetime', f=v['bf'], s=.034, c='white', wt=500)]
    if v.get('deco'): L.append(D(v['deco'], 0, 1.24, 1, .18, sd=4))
    I, end = info(1.46, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def circle_duo(v):
    L = []
    if v.get('corner'): L += deco_corners(v)
    L += [SH('circle', .1, .1, .62, .62, fl='none', sc='accent', sw=.004),
          PH(.13, .13, .56, .56, sh='circle', bw=.012, bc='white'),
          PH(.52, .5, .38, .38, sh='circle', bw=.014, bc='bg'),
          T(.06, .98, .88, .06, tx=v.get('kicker', 'SAVE THE DATE'), f=v['bf'], s=.03, c='accent', wt=700, ls=.3),
          T(.06, 1.05, .88, .24, b='title', f=v['sf'], s=v.get('ts', .14), c='ink', lh=1.05),
          D('divider', .3, 1.32, .4, .04)]
    I, end = info(1.42, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def grid4(v):
    L = []
    g = .025
    w = (1 - .12 - g) / 2
    L += [PH(.06, .06, w, .5, sh=v.get('ph', 'round')), PH(.06 + w + g, .06, w, .5, sh=v.get('ph', 'round')),
          PH(.06, .06 + .5 + g, w, .5, sh=v.get('ph', 'round')), PH(.06 + w + g, .06 + .5 + g, w, .5, sh=v.get('ph', 'round')),
          SH('circle', .32, .43, .36, .36, fl='accent'),
          T(.34, .49, .32, .04, b='weekday', f=v['bf'], s=.02, c='white', wt=700, ls=.25),
          T(.34, .53, .32, .12, b='day', f=v['hf'], s=.12, c='white', lh=1),
          T(.34, .66, .32, .05, b='month', f=v['bf'], s=.03, c='white', wt=700, ls=.25),
          T(.06, 1.2, .88, .06, tx=v.get('kicker', "WE'RE CELEBRATING"), f=v['bf'], s=.03, c='accent', wt=700, ls=.3),
          T(.05, 1.27, .9, .22, b='title', f=v['sf'], s=v.get('ts', .13), c='ink', lh=1.05)]
    I, end = info(1.56, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def editorial_split(v):
    L = [PH(0, 0, .48, 1.3, lk=False), PH(.52, .55, .43, .6, sh=v.get('ph', 'rect'))]
    L += [T(.54, .08, .42, .04, tx=v.get('kicker', 'YOU ARE INVITED'), f=v['bf'], s=.022, c='accent', wt=700, ls=.25, a='left'),
          T(.54, .13, .42, .32, b='title', f=v['hf'], s=.1, c='ink', a='left', lh=1.05, va='top'),
          SH('rect', .54, .47, .12, .006, fl='accent'),
          T(.54, .49, .42, .04, b='datesh', f=v['bf'], s=.026, c='ink', wt=600, ls=.1, a='left', o=.75)]
    L += [D(v['deco'], .5, 1.15, .5, .3, sd=2)] if v.get('deco') else []
    L += [T(.06, 1.36, .88, .08, b='datetime', f=v['hf'], s=.05, c='ink', a='left', wt=500),
          T(.06, 1.44, .88, .1, b='place', f=v['bf'], s=.03, c='ink', a='left', o=.8, va='top', lh=1.3),
          RS(.06, 1.58, .5, .08, c='accent', f=v['bf'], sh='rect'), QR(.74, 1.52, .2)]
    return 1.8, L

def film_strip(v):
    L = [T(.06, .07, .88, .05, tx=v.get('kicker', 'A NIGHT TO REMEMBER'), f=v['bf'], s=.03, c='accent', wt=700, ls=.3),
         T(.05, .13, .9, .28, b='title', f=v['hf'], s=v.get('ts', .12), c='ink', lh=1.05),
         SH('rect', 0, .5, 1, .34, fl='ink')]
    for i in range(4):
        L.append(PH(.04 + i * .24, .54, .22, .26, r=(-3, 2, -2, 3)[i], bw=.006, bc='white'))
    L += [T(.06, .9, .88, .06, b='datetime', f=v['bf'], s=.036, c='ink', wt=600)]
    I, end = info(1.0, v, v.get('info', 'cols'), qr=True)
    L += I
    return end + .1, L

def formal_frame(v):
    L = []
    L += [T(.14, .12, .72, .05, tx=v.get('kicker', 'TOGETHER WITH THEIR FAMILIES'), f=v['bf'], s=.024, c='ink', wt=600, ls=.25),
          PH(.24, .22, .52, .62, sh='oval' if v.get('oval') else 'arch', bw=.01, bc='bg'),
          T(.1, .9, .8, .24, b='title', f=v['sf'], s=v.get('ts', .12), c='ink', lh=1.05),
          T(.16, 1.16, .68, .06, tx=v.get('line', 'invite you to celebrate'), f=v['hf'], s=.036, c='ink', i=True, o=.8),
          D('divider', .3, 1.25, .4, .04)]
    I, end = info(1.34, v, v.get('info', 'center'), qr=False)
    L += I
    L.insert(0, D('frame', .03, .03, .94, end + .04, 'accent', 'accent2', lk=True))
    return end + .1, L

def party_confetti(v):
    L = [D('confetti', 0, 0, 1, 1.25, sd=7, lk=True), D('balloons', .0, .0, 1, .55, sd=2), SH('circle', .2, .5, .6, .6, fl='accent'),
         PH(.24, .54, .52, .52, sh='circle', bw=.014, bc='white'),
         T(.06, 1.16, .88, .05, tx=v.get('kicker', "LET'S PARTY!"), f=v['bf'], s=.036, c='accent', wt=700, ls=.2),
         T(.04, 1.23, .92, .26, b='title', f=v['hf'], s=v.get('ts', .14), c='ink', lh=1.05, u=v.get('up', True))]
    I, end = info(1.56, v, v.get('info', 'ticket'), qr=False)
    L += I
    return end + .1, L

def minimal_editorial(v):
    L = [T(.1, .07, .8, .04, tx=v.get('kicker', 'INVITATION'), f=v['bf'], s=.022, c='ink', wt=600, ls=.4, o=.7),
         SH('rect', .46, .12, .08, .003, fl='ink'),
         T(.08, .16, .84, .3, b='title', f=v['hf'], s=v.get('ts', .12), c='ink', lh=1.05, wt=400),
         PH(.08, .5, .84, .56, sh=v.get('ph', 'rect')),
         T(.08, 1.1, .84, .05, b='datetime', f=v['bf'], s=.03, c='ink', wt=600, ls=.1, u=True)]
    I, end = info(1.2, v, v.get('info', 'cols'), qr=False)
    L += I
    return end + .1, L

def scrapbook(v):
    L = [D(v.get('deco', 'hearts'), 0, 0, 1, 1.9, sd=3, o=.35),
         PH(.05, .07, .5, .46, pol=True, bw=.028, r=-6), PH(.5, .04, .44, .4, pol=True, bw=.028, r=5),
         PH(.08, .5, .38, .4, pol=True, bw=.028, r=4), PH(.44, .42, .5, .5, pol=True, bw=.028, r=-4),
         D('tape', .14, .05, .14, .035, 'accent2', r=-18), D('tape', .66, .03, .14, .035, 'accent', r=16),
         D('tape', .2, .49, .14, .035, 'accent', r=8), D('tape', .6, .4, .14, .035, 'accent2', r=-10),
         T(.04, 1.0, .92, .24, b='title', f=v['sf'], s=v.get('ts', .13), c='ink', lh=1.05, r=-2),
         T(.1, 1.24, .8, .05, tx=v.get('kicker', 'save the date'), f=v['sf'], s=.05, c='accent')]
    I, end = info(1.34, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def story_stack(v):
    L = [T(.06, .07, .88, .05, tx=v.get('kicker', 'OUR STORY'), f=v['bf'], s=.028, c='accent', wt=700, ls=.3),
         T(.05, .13, .9, .22, b='title', f=v['sf'], s=v.get('ts', .13), c='ink', lh=1.05),
         PH(.06, .38, .88, .56, sh=v.get('ph', 'round')),
         T(.12, 1.0, .76, .12, tx='Join us for a day filled with love, laughter and the people we care about most.', f=v.get('qf', v['hf']), s=.036, c='ink', i=True, o=.85, va='top', lh=1.35),
         PH(.06, 1.2, .43, .5, sh=v.get('ph', 'round')), PH(.51, 1.2, .43, .5, sh=v.get('ph', 'round')),
         D('divider', .3, 1.77, .4, .04),
         PH(.2, 1.86, .6, .7, sh='arch')]
    I, end = info(2.66, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def bento(v):
    L = [PH(.06, .07, .56, .52, sh='round', rd=.08), PH(.64, .07, .3, .25, sh='round', rd=.12), PH(.64, .34, .3, .25, sh='round', rd=.12),
         PH(.06, .61, .88, .3, sh='round', rd=.06),
         SH('round', .06, .93, .88, .32, fl='accent', rd=.08),
         T(.1, .96, .8, .04, tx=v.get('kicker', "YOU'RE INVITED"), f=v['bf'], s=.024, c='white', wt=700, ls=.3),
         T(.08, 1.0, .84, .2, b='title', f=v['hf'], s=v.get('ts', .11), c='white', lh=1.05)]
    I, end = info(1.36, v, v.get('info', 'cols'))
    L += I
    return end + .1, L

def poster_type(v):
    L = [D(v.get('deco', 'stripes'), 0, 0, 1, .16, 'accent'),
         T(.06, .2, .88, .6, b='title', f=v['hf'], s=v.get('ts', .2), c='ink', lh=.95, u=True, wt=v.get('wt', 700), a='left'),
         PH(.5, .82, .44, .44, sh='circle', bw=.012, bc='bg'),
         SH('circle', .44, .76, .44, .44, fl='accent2', o=.5),
         T(.06, .88, .4, .05, b='weekday', f=v['bf'], s=.026, c='accent', wt=700, ls=.3, a='left'),
         T(.06, .93, .4, .16, b='day', f=v['hf'], s=.16, c='ink', a='left', lh=1),
         T(.06, 1.1, .4, .05, b='month', f=v['bf'], s=.04, c='ink', a='left', wt=700, ls=.2),
         T(.06, 1.16, .4, .05, b='time', f=v['bf'], s=.03, c='ink', a='left', o=.8)]
    I, end = info(1.36, v, v.get('info', 'cols'), qr=False)
    L += I
    return end + .1, L

def night_sky(v):
    L = [D('stars', 0, 0, 1, 1.6, 'accent', 'accent2', 'white', sd=9), D('moon', .62, .04, .3, .3, 'accent2'),
         PH(.2, .28, .6, .6, sh='circle', bw=.014, bc='accent'),
         SH('circle', .17, .25, .66, .66, fl='none', sc='accent', sw=.003),
         T(.06, .98, .88, .05, tx=v.get('kicker', 'A MAGICAL NIGHT'), f=v['bf'], s=.028, c='accent', wt=700, ls=.3),
         T(.04, 1.05, .92, .26, b='title', f=v['sf'], s=v.get('ts', .14), c='ink', lh=1.05)]
    I, end = info(1.4, v, v.get('info', 'center'))
    L += I
    return end + .1, L

def tropical(v):
    L = [D('palm', -.1, -.02, .6, .5, 'accent', 'accent2', sd=1, r=8), D('palm', .5, -.02, .6, .5, 'accent2', 'accent', sd=2, r=-8),
         PH(.24, .3, .52, .62, sh='oval', bw=.012, bc='bg'),
         PH(.06, .6, .22, .3, sh='pill'), PH(.72, .6, .22, .3, sh='pill'),
         T(.06, .98, .88, .05, tx=v.get('kicker', 'PARADISE AWAITS'), f=v['bf'], s=.03, c='accent', wt=700, ls=.3),
         T(.04, 1.05, .92, .24, b='title', f=v['sf'], s=v.get('ts', .13), c='ink', lh=1.05),
         D('waves', 0, 1.3, 1, .22, 'accent', 'accent2', 'soft')]
    I, end = info(1.55, v, v.get('info', 'ticket'), qr=False)
    L += I
    return end + .1, L

ARCH = dict(arch_hero=arch_hero, polaroid_trio=polaroid_trio, full_bleed=full_bleed, circle_duo=circle_duo, grid4=grid4,
            editorial_split=editorial_split, film_strip=film_strip, formal_frame=formal_frame, party_confetti=party_confetti,
            minimal_editorial=minimal_editorial, scrapbook=scrapbook, story_stack=story_stack, bento=bento,
            poster_type=poster_type, night_sky=night_sky, tropical=tropical)

# ---------------------------------------------------------------- the 50 templates
def F(hf, sf, bf): return dict(hf=hf, sf=sf, bf=bf)
PF, CG, DS = 'Playfair Display', 'Cormorant Garamond', 'DM Serif Display'
GV, DC, SA, AL, PA = 'Great Vibes', 'Dancing Script', 'Sacramento', 'Allura', 'Parisienne'
IN, PO, MO, DM, JO, NU, QU, LA, FR, BE = 'Inter', 'Poppins', 'Montserrat', 'DM Sans', 'Josefin Sans', 'Nunito', 'Quicksand', 'Lato', 'Fredoka', 'Bebas Neue'

WED = ['wedding', 'anniversary']
TEMPLATES = [
 # name, style, themes, arch, fonts, palette, extra
 ('Garden Romance', 'romantic', ['wedding', 'anniversary', 'quinceanera'], 'arch_hero', F(PF, GV, LA), 'Blush & Sage', dict(corner='flowers', kicker='TOGETHER WITH THEIR FAMILIES')),
 ('Golden Arch', 'elegant', ['wedding', 'anniversary'], 'arch_hero', F(CG, AL, JO), 'Ivory & Emerald', dict(info='bigdate', ts=.14)),
 ('Boho Arch', 'boho', ['wedding', 'baby_shower', 'baptism_communion'], 'arch_hero', F(DS, SA, DM), 'Terracotta & Cream', dict(corner='leaves', kicker='JOIN US FOR')),
 ('Celestial Arch', 'elegant', ['wedding', 'quinceanera', 'gender_reveal'], 'arch_hero', F(CG, PA, JO), 'Navy & Gold', dict(corner='stars', info='ticket')),
 ('Rose Polaroids', 'playful', ['birthday', 'anniversary', 'graduation', 'farewell'], 'polaroid_trio', F(PF, DC, QU), 'Rose Pastel', dict(deco='hearts', kicker='MEMORIES IN THE MAKING')),
 ('Summer Polaroids', 'playful', ['birthday', 'trip', 'farewell', 'dinner_gathering'], 'polaroid_trio', F(PO, PA, PO), 'Sunshine & Sky', dict(deco='sprinkles', kicker="SUMMER'S HERE", info='cols')),
 ('Film Roll', 'modern', ['birthday', 'graduation', 'corporate', 'trip'], 'film_strip', F(BE, DC, MO), 'Black & Gold', dict(ts=.16)),
 ('Full Bleed Love', 'romantic', ['wedding', 'anniversary', 'farewell'], 'full_bleed', F(CG, GV, LA), 'Rose Deep', dict(kicker='A LOVE STORY')),
 ('Sunset Hero', 'modern', ['trip', 'birthday', 'dinner_gathering', 'year_end_party'], 'full_bleed', F(PO, PA, PO), 'Orange Deep', dict(deco='waves', info='bigdate')),
 ('Modern Hero', 'minimalist', ['corporate', 'graduation', 'baptism_communion'], 'full_bleed', F(MO, DM, MO), 'Blue Mono', dict(kicker='YOU ARE INVITED', ts=.11, info='cols')),
 ('Twin Moons', 'romantic', ['wedding', 'baby_shower', 'gender_reveal', 'anniversary'], 'circle_duo', F(PF, GV, LA), 'Pink Blush', dict(corner='flowers')),
 ('Sage Circles', 'botanical', ['wedding', 'baby_shower', 'dinner_gathering', 'baptism_communion'], 'circle_duo', F(CG, SA, JO), 'Green Muted', dict(corner='leaves', kicker='WITH JOY')),
 ('Ocean Circles', 'modern', ['trip', 'birthday', 'graduation', 'farewell'], 'circle_duo', F(DS, DC, DM), 'Ocean & Coral', dict(kicker="LET'S GO", info='ticket')),
 ('Photo Grid Party', 'playful', ['birthday', 'graduation', 'year_end_party', 'farewell'], 'grid4', F(FR, DC, NU), 'Pink Candy', dict(ph='round')),
 ('Grid & Gold', 'elegant', ['wedding', 'anniversary', 'corporate', 'year_end_party'], 'grid4', F(PF, AL, LA), 'Blue Gold', dict(ph='rect', info='cols')),
 ('Little Grid', 'kids', ['baby_shower', 'birthday', 'gender_reveal', 'baptism_communion'], 'grid4', F(FR, DC, QU), 'Sky Pastel', dict(ph='circle', kicker='A NEW ADVENTURE')),
 ('Magazine', 'editorial', ['wedding', 'anniversary', 'corporate', 'graduation'], 'editorial_split', F(PF, GV, JO), 'Rose Cream', dict()),
 ('Studio Split', 'modern', ['corporate', 'graduation', 'year_end_party', 'birthday'], 'editorial_split', F(BE, DC, MO), 'Blue Mono', dict(ph='round', deco='dots')),
 ('Botanical Journal', 'botanical', ['baby_shower', 'wedding', 'baptism_communion', 'dinner_gathering'], 'editorial_split', F(CG, SA, LA), 'Olive Cream', dict(deco='leaves')),
 ('Ceremony Frame', 'classic', ['wedding', 'anniversary', 'baptism_communion', 'quinceanera'], 'formal_frame', F(CG, PA, JO), 'Black & Gold', dict(oval=True)),
 ('Royal Frame', 'classic', ['quinceanera', 'wedding', 'anniversary'], 'formal_frame', F(PF, GV, LA), 'Berry & Blush', dict(kicker='SHE IS TURNING FIFTEEN', line='request the pleasure of your company')),
 ('Ivory Frame', 'classic', ['baptism_communion', 'wedding', 'anniversary', 'corporate'], 'formal_frame', F(DS, AL, DM), 'Amber Gold', dict(kicker='WITH GRATEFUL HEARTS', line='invite you to join them')),
 ('Balloon Bash', 'kids', ['birthday', 'baby_shower', 'gender_reveal'], 'party_confetti', F(FR, DC, NU), 'Sunshine & Sky', dict(kicker="IT'S A PARTY!")),
 ('Confetti Night', 'playful', ['birthday', 'year_end_party', 'graduation', 'farewell'], 'party_confetti', F(BE, DC, PO), 'Violet Night', dict(up=True)),
 ('Candy Party', 'kids', ['birthday', 'baby_shower', 'quinceanera'], 'party_confetti', F(FR, DC, QU), 'Pink Candy', dict(info='cols')),
 ('Neon Vivid', 'modern', ['birthday', 'year_end_party', 'graduation'], 'party_confetti', F(PO, DC, PO), 'Violet Vivid', dict(kicker='TURN IT UP')),
 ('Quiet Edit', 'minimalist', ['wedding', 'corporate', 'dinner_gathering', 'anniversary'], 'minimal_editorial', F(CG, PA, JO), 'Amber Mono', dict(kicker='SAVE THE DATE')),
 ('Sand Minimal', 'minimalist', ['wedding', 'baby_shower', 'baptism_communion', 'trip'], 'minimal_editorial', F(PF, SA, DM), 'Amber Muted', dict(ph='round')),
 ('Scrapbook Love', 'playful', ['wedding', 'anniversary', 'birthday', 'farewell'], 'scrapbook', F(PF, PA, QU), 'Coral Pastel', dict(deco='hearts', kicker='our favorite moments')),
 ('Memory Board', 'playful', ['graduation', 'farewell', 'trip', 'birthday'], 'scrapbook', F(FR, DC, NU), 'Amber Candy', dict(deco='stars', kicker='the best is yet to come', info='cols')),
 ('Garden Scrapbook', 'botanical', ['baby_shower', 'baptism_communion', 'dinner_gathering'], 'scrapbook', F(LA, SA, LA), 'Green Pastel', dict(deco='stars', kicker='a little celebration')),
 ('Love Story', 'romantic', ['wedding', 'anniversary', 'quinceanera'], 'story_stack', F(PF, GV, LA), 'Rose Cream', dict(kicker='OUR STORY')),
 ('Family Album', 'warm', ['baby_shower', 'baptism_communion', 'birthday', 'anniversary'], 'story_stack', F(DS, DC, NU), 'Coral Cream', dict(kicker='A FAMILY CELEBRATION', ph='arch')),
 ('Adventure Journal', 'modern', ['trip', 'birthday', 'graduation'], 'story_stack', F(BE, DC, MO), 'Forest & Sand', dict(kicker='THE ADVENTURE BEGINS', ph='rect', info='cols', qf=MO)),
 ('Bento Bloom', 'modern', ['birthday', 'baby_shower', 'graduation', 'corporate'], 'bento', F(DS, DC, DM), 'Pink Gold', dict()),
 ('Bento Kids', 'kids', ['birthday', 'baby_shower', 'gender_reveal'], 'bento', F(FR, DC, QU), 'Teal Candy', dict(kicker="IT'S A CELEBRATION")),
 ('Poster Bold', 'modern', ['corporate', 'year_end_party', 'graduation', 'birthday'], 'poster_type', F(BE, DC, MO), 'Sunshine & Sky', dict(deco='stripes')),
 ('Poster Sunset', 'modern', ['birthday', 'trip', 'year_end_party', 'farewell'], 'poster_type', F(BE, DC, PO), 'Coral Vivid', dict(deco='dots', info='center')),
 ('Poster Noir', 'modern', ['corporate', 'year_end_party', 'dinner_gathering'], 'poster_type', F(BE, DC, JO), 'Black & Gold', dict(deco='stripes', wt=400)),
 ('Starry Night', 'magical', ['gender_reveal', 'baby_shower', 'wedding', 'quinceanera'], 'night_sky', F(CG, GV, JO), 'Blue Night', dict(kicker='ONCE UPON A STAR')),
 ('Moonlight Dinner', 'magical', ['dinner_gathering', 'anniversary', 'year_end_party', 'corporate'], 'night_sky', F(PF, PA, DM), 'Black & Gold', dict(kicker='AN EVENING TOGETHER', info='ticket')),
 ('Little Star', 'kids', ['baby_shower', 'birthday', 'gender_reveal', 'baptism_communion'], 'night_sky', F(FR, DC, QU), 'Violet Night', dict(kicker='TWINKLE TWINKLE')),
 ('Palm Paradise', 'tropical', ['trip', 'birthday', 'dinner_gathering', 'farewell'], 'tropical', F(PA, PA, PO), 'Teal Candy', dict(kicker='PARADISE AWAITS')),
 ('Tropical Bloom', 'tropical', ['wedding', 'trip', 'birthday', 'baby_shower'], 'tropical', F(PF, SA, QU), 'Peach & Teal', dict(kicker='ALOHA', info='center')),
 ('Island Luau', 'tropical', ['birthday', 'year_end_party', 'graduation', 'trip'], 'tropical', F(FR, DC, NU), 'Green Vivid', dict(kicker="LET'S LUAU", info='cols')),
 ('Lavender Dream', 'romantic', ['quinceanera', 'baby_shower', 'wedding', 'baptism_communion'], 'arch_hero', F(PF, AL, LA), 'Lavender & Mint', dict(corner='flowers', kicker='SWEET FIFTEEN')),
 ('Peach Polaroids', 'warm', ['baby_shower', 'birthday', 'baptism_communion', 'dinner_gathering'], 'polaroid_trio', F(DS, SA, NU), 'Peach & Teal', dict(deco='confetti', kicker='WITH LOVE')),
 ('Emerald Night', 'elegant', ['wedding', 'corporate', 'year_end_party', 'anniversary'], 'formal_frame', F(PF, GV, JO), 'Green Deep', dict(kicker='YOU ARE CORDIALLY INVITED', line='to an unforgettable evening')),
 ('Year in Review', 'modern', ['year_end_party', 'corporate', 'farewell', 'dinner_gathering'], 'film_strip', F(DS, SA, DM), 'Navy & Gold', dict(kicker='CELEBRATE THE YEAR', ts=.13)),
 ('Cherry Blossom', 'romantic', ['wedding', 'quinceanera', 'baby_shower', 'anniversary'], 'circle_duo', F(CG, PA, JO), 'Pink Cream', dict(corner='flowers', kicker='A SPRING CELEBRATION')),
]
assert len(TEMPLATES) == 50, len(TEMPLATES)

def build():
    out = []
    for name, style, themes, arch, fonts, palname, extra in TEMPLATES:
        v = dict(fonts); v.update(extra)
        h, layers = ARCH[arch](v)
        layers = [l for l in layers if l]
        pal = P(palname)
        grad = pal['bg'] != '#FFFFFF' and PALS[palname]['tone'] == 'light'
        out.append(dict(name=name, style=style, themes=themes, languages=['en', 'es'], arch=arch,
                        layout=dict(height=round(h, 3), grad=False, palette=pal, layers=layers)))
    return out

def sql_str(s): return "'" + s.replace("'", "''") + "'"

def main():
    tpls = build()
    with open(os.path.join(ROOT, 'tool', 'templates_data.dart'), 'w') as f:
        f.write("// Generated by tool/gen_templates.py (used only by tool/template_preview.dart).\nconst kTemplatesJson = r'''" + json.dumps(tpls, separators=(',', ':')) + "''';\nconst kPalettesJson = r'''" + json.dumps(list(PALS.values()), separators=(',', ':')) + "''';\n")
    lines = ['-- Generated by tool/gen_templates.py. Do not edit by hand.',
             '-- 130+ colour combinations and 50 invitation templates.', '',
             'delete from color_palettes;']
    rows = [f"({sql_str(p['name'])}, {sql_str(p['tone'])}, {sql_str(json.dumps(p['colors']))}::jsonb)" for p in PALS.values()]
    lines.append('insert into color_palettes (name, tone, colors) values\n  ' + ',\n  '.join(rows) + ';')
    lines += ['', '-- Retire the first generation of templates and start fresh (events keep working: their layers live in event_blocks).',
              "update templates set status = 'retired' where not (layout ? 'layers');",
              "update events set template_id = null where template_id in (select id from templates where status = 'retired');", '']
    for t in tpls:
        arr = "'{" + ','.join(t['themes']) + "}'::text[]"
        lay = sql_str(json.dumps(t['layout'], separators=(',', ':')))
        lines.append(f"insert into templates (category_id, name, style, languages, themes, min_plan, palette, layout, status) select null, {sql_str(t['name'])}, {sql_str(t['style'])}, '{{en,es}}', {arr}, 'essential', '[]'::jsonb, {lay}::jsonb, 'published' where not exists (select 1 from templates where name = {sql_str(t['name'])} and layout ? 'layers');")
    with open(os.path.join(ROOT, 'supabase', 'migrations', '004_palettes_templates.sql'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    size = os.path.getsize(os.path.join(ROOT, 'supabase', 'migrations', '004_palettes_templates.sql'))
    print(len(PALS), 'palettes,', len(tpls), 'templates,', size // 1024, 'KB sql')

if __name__ == '__main__':
    main()
