"""Dump glyph outlines as luaotfload's loadshapes would (for previews without TeX).
   python glyphs.py FONT LETTERS > glyphs.lua"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen

class P(BasePen):
    def __init__(s, gs): super().__init__(gs); s.seg = []
    def _moveTo(s, p): s.seg.append((p[0], p[1], "m"))
    def _lineTo(s, p): s.seg.append((p[0], p[1], "l"))
    def _curveToOne(s, a, b, c): s.seg.append((a[0], a[1], b[0], b[1], c[0], c[1], "c"))
    def _qCurveToOne(s, a, b): s.seg.append((a[0], a[1], b[0], b[1], "q"))
    def _closePath(s): pass

f = TTFont(sys.argv[1], fontNumber=0)
gs, cmap = f.getGlyphSet(), f.getBestCmap()
out = ["return { units = %d, glyphs = {" % f["head"].unitsPerEm]
for ch in sys.argv[2]:
    name = cmap[ord(ch)]
    pen = P(gs); gs[name].draw(pen)
    xs = [v for s in pen.seg for v in s[0:-1:2]]; ys = [v for s in pen.seg for v in s[1:-1:2]]
    segs = ", ".join("{" + ", ".join(repr(v) if isinstance(v, str) and False else (('"%s"' % v) if isinstance(v, str) else "%g" % v) for v in s) + "}" for s in pen.seg)
    out.append("  { unicode = %d, boundingbox = { %g, %g, %g, %g }, segments = { %s } }," % (ord(ch), min(xs), min(ys), max(xs), max(ys), segs))
out.append("} }")
print("\n".join(out))
