#!/usr/bin/env python3
"""The two showcase PDFs as HTML (then pdf.mjs prints them): every drawing is inline SVG, so it stays
vector, and the text is real text."""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
SVG = ROOT / 'build/showcase/svg'
EXTRA = {'specimen-1': ROOT / 'build/cattree/specimen-1.svg', 'specimen-2': ROOT / 'build/cattree/specimen-2.svg',
         'specimen-4': ROOT / 'build/cattree/specimen-4.svg', 'initials': ROOT / 'build/cattree/initials.svg',
         'oak-parts': ROOT / 'build/trees/oak-green.svg'}
n = [0]
def art(name, style='position:absolute;inset:0;width:100%;height:100%', viewbox=None):
    """a drawing, inline, its ids made unique to this use"""
    s = (EXTRA.get(name) or SVG / f'{name}.svg').read_text()
    n[0] += 1
    pre = f'u{n[0]}_'
    s = re.sub(r'id="([^"]+)"', lambda m: f'id="{pre}{m[1]}"', s)
    s = re.sub(r'url\(#([^)]+)\)', lambda m: f'url(#{pre}{m[1]})', s)
    s = re.sub(r'<rect width="[^"]*" height="[^"]*" fill="#f[^"]*"/>', '', s, count=1)
    s = re.sub(r'<svg ([^>]*?)width="[^"]*" height="[^"]*"', r'<svg \1', s, count=1)
    if viewbox:
        s = re.sub(r'viewBox="[^"]*"', f'viewBox="{viewbox}"', s, count=1)
    return s.replace('<svg ', f'<svg style="{style}" preserveAspectRatio="xMidYMid meet" ', 1)
def tile(letter): return art(f'tile-{letter}', 'float:left;width:2.5cm;height:2.5cm;margin:0.1cm 0.35cm 0.05cm 0')
def page(*parts, cls=''): return f'<section class="page {cls}">' + ''.join(parts) + '</section>'
def textbox(left, top, width, height, html, cls=''):
    return f'<div class="text {cls}" data-check style="left:{left}cm;top:{top}cm;width:{width}cm;height:{height}cm">{html}</div>'
# margin pages: 32 mm from the top, 30 at the foot, side margins as drawn
def body(left, right, html, end=None):
    h = 21.74 if end is None else end
    return f'<div class="text" data-check style="left:{left}mm;right:{right}mm;top:32mm;height:{h}cm">{html}</div>'
def caption(t, left=1.2, bottom=0.55): return f'<div class="cap" style="left:{left}cm;bottom:{bottom}cm">{t}</div>'

GYM_1 = """<h2>Every page gets its own gym</h2>
<p>{tile}ats climb to see, and to be seen. A shelf by the window is good; a route from the floor to the top of the room, with somewhere to rest on the way, is better. Everything in the margin of this page was worked out by a program while the page was being made, and no two pages get the same one.</p>
<p>It starts on the floor, where a cat gym is heaviest: a tower of posts wound with sisal, standing in whole levels about fifty centimeters apart. Where two posts meet, the shorter one holds up a platform and the taller one carries on through it. Crossbeams tie the posts together low down. Hammocks hang under the high platforms. Condos, baskets and rings take what room is left.</p>
<p>Then it goes up the wall. The program plans a route first, the way a cat would climb, and only then draws what the route needs: one long ladder with shelves stepping off it, floating steps on a slant, a run of identical shelves zigzagging up, a rope bridge across a gap. Every step goes somewhere. The climb ends at one perch, at the top, with nothing above it.</p>
<p>Everything is drawn at one twentieth of its real size, from real measurements: a post nine centimeters thick, a hexagon sixty across, the door of a condo twenty. A hexagon here really would hold a cat. The cats themselves come last, one or two to a page, so that most of the gym stands ready for them, and they settle wherever there is room: on a platform, in a basket, in a hexagon, or partway across a bridge.</p>
<p>The picture is computed rather than stored. There are no image files anywhere in it, only shapes described by numbers, so you can zoom in as far as you like and it stays sharp. Look closely at a post and you will find the sisal wound on it line by line. Look at a condo and you will find the mottled wash of plush, painted in layers of a single blue ink, the way a single pigment thins with water, with copper for the ropes, the brackets and the eyes of the cats.</p>
<p>Change one number, the seed, and you get another gym, every time, down to the toys that hang from it.</p>"""
GYM_2 = """<h2>On the other side of the page</h2>
<p>{tile}book has left pages and right pages, and the gym grows in whichever margin is the wider, so here it has moved across and turned around. Nothing about it is simply flipped by hand: the page is measured first, and the gym is built to fit what it finds.</p>
<p>A cat gym is a good thing to get a program to draw, because it has to make sense. Plants forgive almost anything: a flower can sprout at any angle wherever there is room. Furniture does not. Posts have to stand on something, a shelf has to be held up by something, and a ladder that leads nowhere looks wrong at once, even to someone who has never thought about it.</p>
<p>So the rules here came from looking at real ones, and from a good deal of being told what was wrong. Ladders hang flat against the wall and run straight up. Two ladders never follow one another; one long ladder with shelves to step off onto is what a person would actually build. Rope bridges never hang at floor level. Dots and pegs are for going sideways or on a slant, because nothing climbs a line of pegs straight up. A cat is allowed to jump, but only now and then, and only as far as a cat can.</p>
<p>Toys are the last thing added, and they follow the same logic. They hang beneath a platform or a bridge, clear of any path: pom-poms, little mice on strings, bells, knotted ropes, feathers. A ball of yarn sits on a shelf with its loose end hanging over the edge. A fishing-pole toy leans out from the end of a perch, its feathers on a line. Swings and baskets hang on ropes from the top of the page, within a jump of something a cat can stand on.</p>
<p>None of this was placed by hand. Every one of these decisions is made again for each page, by the same rules, so the rules are the design, and any single picture is only one of the things they can produce.</p>"""
SHORT_A = """<h2>Where the text stops</h2>
<p>{tile}nd when a page ends early, the gym notices. It reads where the last line falls and takes the room that is left, spreading along the floor underneath the text on posts of its own.</p>
<p>Often it turns into a U, tall at both ends, with a long rope bridge across the top so that a cat can walk from one tower to the other.</p>"""
SHORT_B = """<h2>Very little text</h2><p>The less text there is, the more gym there is.</p>"""
WIDE = """<h2>A wider margin</h2>
<p>The same program, given more room to work in. It draws more posts, and more of everything else, without being told to; it only knows how wide the margin is.</p>
<p>Almost nothing has to change to go from one page shape to another. The rules stay as they are and the room they have to work with grows.</p>
<p>That is also why it can leave a space for words anywhere on a page, as the next pages show, or fill a page completely.</p>
<p>Margins can be measured in millimeters or in cat lengths. A cat is about forty-five centimeters without its tail, which at this scale is a little over two centimeters on the page, and that is the unit everything else was checked against.</p>"""

def gym_pdf():
    P = []
    P.append(page(art('cover'), textbox(4, 9.6, 13.6, 5.6, '<h1>Cat Trees</h1><p class="sub">Generated by a program, one page at a time.<br>No two alike.</p>', 'center')))
    P.append(page(art('full-left'), body(68, 22, GYM_1.format(tile=tile('C')))))
    P.append(page(art('full-right'), body(22, 68, GYM_2.format(tile=tile('A')))))
    P.append(page(art('short-a'), body(68, 22, SHORT_A.format(tile=tile('A')), 9.6)))
    P.append(page(art('short-b'), body(68, 22, SHORT_B, 5.6)))
    P.append(page(art('wide'), body(90, 20, WIDE)))
    P.append(page(art('box-mid'), textbox(3.2, 8, 15.2, 8.6, '<h2>A space left for words</h2><p>Draw a box anywhere on a page and the gym grows around it. Posts stop short of it, platforms give it room, and nothing crosses it. In the page-making tool this happens as you let go of the mouse.</p><p>These pages were laid out that way: the box first, then whatever the rules could build around it.</p>', 'center')))
    P.append(page(art('box-top'), textbox(2.4, 1.8, 16.8, 9.6, '<h2>Text on top, a gym below</h2><p>A cat gym grows up from the floor, so it is happiest when the words are at the top of the page and it has the bottom to itself. The pieces on this page are drawn a little larger than on the pages before: one setting makes them bigger, and fewer.</p><p>Whatever falls within reach still has to make sense. A shelf that would have stood in the text is simply not built, and whatever depended on it finds another way up.</p>')))
    P.append(page(art('box-two'), textbox(1.6, 2, 9.4, 8.6, '<h2>Two boxes</h2><p>Text can go in more than one place. It runs from the first box into the second, and whatever does not fit carries on to a new page.</p>'), textbox(10.2, 17.4, 9.8, 8.6, '<p>This second box sits low on the page, so the towers on this side stop short and the climbing happens around it. Nobody told it to do that. It just looks for room.</p>')))
    P.append(page(art('gym-full'), cls='plain'))
    P.append(page(art('gym-full2'), cls='plain'))
    # a carousel: one wide gym, cut into three slides
    vb = [f'{i * 21 * 72 / 2.54:.2f} 0 {21 * 72 / 2.54:.2f} {26.25 * 72 / 2.54:.2f}' for i in range(3)]
    rows = ''.join('<div class="row">' + ''.join(f'<div class="slide">{art(nm, viewbox=v)}</div>' for v in vb) + '</div>' for nm in ('pano', 'pano2'))
    P.append(page(f'<div class="landscape"><h2>Carousels</h2><p>One wide gym, cut into three slides, so that the floor and the platforms carry on from one to the next as you swipe. Here are two of them, each three slides long.</p>{rows}</div>'))
    four = ''.join(f'<div class="slide4">{art(f"slide{i}")}<div class="slidetext"><b>Slide {i}</b><br>Your words go here, in a box the gym leaves clear.</div></div>' for i in range(1, 5))
    P.append(page(f'<div class="landscape"><h2>Slides with words</h2><div class="row4">{four}</div></div>'))
    grid = ''.join(f'<div class="thumb">{art(f"grid{i}")}</div>' for i in range(1, 10))
    P.append(page(f'<div class="landscape"><h2>Nine more margins</h2><p>The same rules with a different seed. Every third page ends its text early.</p><div class="grid">{grid}</div></div>'))
    P.append(page(art('specimen-1'), cls='plain'))
    P.append(page(art('specimen-2'), cls='plain'))
    P.append(page(art('specimen-4'), cls='plain'))
    letters = ''.join(f'<div class="letter">{art(f"tile-{chr(c)}", "width:100%;height:100%")}</div>' for c in range(65, 91))
    P.append(page(f'<div class="landscape"><h2>An alphabet</h2><p>A big first letter for any paragraph, with a cat on it, or curled up inside it where the letter has room. Each one is drawn fresh, so the same letter comes out differently every time.</p><div class="letters">{letters}</div></div>'))
    return P

def oak_pdf():
    P = []
    P.append(page(art('oak-cover'), textbox(3.6, 2.2, 14.4, 5.6, '<h1>One Huge Oak</h1><p class="sub">Work in progress. Grown by a program, without cats for now.</p>', 'center')))
    P.append(page(art('oak1'), caption('Seed 4'), cls='plain'))
    P.append(page(art('oak2'), caption('Seed 2'), cls='plain'))
    P.append(page(art('oak3'), caption('Seed 7'), cls='plain'))
    P.append(page(art('oak4'), caption('Seed 3, in Delft blue'), cls='plain'))
    P.append(page(art('oak5'), caption('Seed 9, in Delft blue'), cls='plain'))
    full = 21.59 * 72 / 2.54
    # close-ups: the same drawing, nearer
    P.append(page(art('oak1', viewbox=f'{full * 0.3:.1f} {full * 0.7:.1f} {full * 0.42:.1f} {full * 0.54:.1f}'), caption('Close up: the trunk. Each plate of bark is lit on one side.'), cls='plain'))
    P.append(page(art('oak1', viewbox=f'{full * 0.22:.1f} {full * 0.38:.1f} {full * 0.42:.1f} {full * 0.54:.1f}'), caption('Close up: where the limbs leave the trunk, and the leaves over them.'), cls='plain'))
    P.append(page(art('oak2', viewbox=f'{full * 0.04:.1f} {full * 0.1:.1f} {full * 0.42:.1f} {full * 0.54:.1f}'), caption('Close up: the crown, built in layers, pale behind and bright in front.'), cls='plain'))
    P.append(page(art('oak-box'), textbox(3, 2.2, 15.6, 8.8, '<h2>Around the words</h2><p>The crown grows around a box of text in the same way the cat gym does: branches turn away from it, and the leaves stop at its edge. The tree grows from a space-colonization method, in which branches compete for open room, and the thickness of each limb is worked out from everything it carries.</p>', 'center')))
    P.append(page(art('oak-two'), textbox(1.6, 2, 8.4, 7, '<p>The trunk stands wherever the boxes leave it the most room, and the crown fills whatever is left.</p>'), textbox(13.2, 15, 7, 8, '<p>Every tree here comes out differently. Nothing is copied or stored: only numbers and rules.</p>')))
    P.append(page(art('oak-parts'), cls='plain'))
    return P

STYLE = """
@page { size: 8.5in 11in; margin: 0 }
* { box-sizing: border-box }
html, body { margin: 0; padding: 0; background: #fff }
.page { position: relative; width: 8.5in; height: 11in; overflow: hidden; break-after: page; background: #fefdfb; color: #16224f;
  font: 11pt/1.5 Georgia, 'Times New Roman', serif }
.text { position: absolute; overflow: hidden }
.text p { margin: 0 0 0.6em }
.text.center { display: flex; flex-direction: column; justify-content: center; text-align: center }
h1 { font-size: 46pt; line-height: 1.1; margin: 0 0 0.2em; font-weight: bold }
h2 { font-size: 17pt; line-height: 1.2; margin: 0 0 0.6em; font-weight: bold }
.sub { font-size: 13pt; font-style: italic }
.cap { position: absolute; font: italic 10pt Georgia, serif; color: #16224f; background: #fefdfb; padding: 0.08cm 0.2cm; border-radius: 2pt }
.landscape { position: absolute; inset: 1.2cm }
.landscape h2 { margin-bottom: 0.2em }
.landscape p { margin: 0 0 0.6em }
.row { display: flex; flex-direction: column; gap: 0.3cm; align-items: center }
.slide { position: relative; width: 6.1cm; height: 7.625cm; background: #fff; outline: 0.5pt solid #b9bfd4 }
.row { flex-direction: row; flex-wrap: nowrap; justify-content: center; gap: 0.15cm; margin-top: 1.7cm }
.row .slide { width: 6.2cm; height: 7.75cm }
.row4 { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5cm; margin-top: 0.4cm }
.slide4 { position: relative; width: 9.15cm; height: 11.4cm; outline: 0.5pt solid #b9bfd4 }
.slidetext { position: absolute; left: 14.5%; top: 11.5%; width: 71%; font-size: 12pt; line-height: 1.35; text-align: center }
.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.35cm; margin-top: 0.2cm }
.letters { display: grid; grid-template-columns: repeat(6, 1fr); gap: 0.32cm; margin-top: 0.3cm }
.letter { aspect-ratio: 1 }
.thumb { position: relative; aspect-ratio: 8.5 / 11; outline: 0.5pt solid #b9bfd4 }
"""
for name, pages in (('cat-trees', gym_pdf()), ('oak-trees', oak_pdf())):
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>{name}</title><style>{STYLE}</style></head><body>{"".join(pages)}</body></html>'
    (ROOT / f'build/showcase/{name}.html').write_text(html)
    print(name, len(pages), 'pages', len(html) // (1024 * 1024), 'MB html')
