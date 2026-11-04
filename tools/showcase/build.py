#!/usr/bin/env python3
"""The two showcase PDFs as HTML (then pdf.mjs prints them): every drawing is inline SVG, so it stays
vector, and the text is real text."""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
SVG = ROOT / 'build/showcase/svg'
EXTRA = {'specimen-1': ROOT / 'build/cattree/specimen-1.svg', 'specimen-2': ROOT / 'build/cattree/specimen-2.svg',
         'specimen-4': ROOT / 'build/cattree/specimen-4.svg', 'initials': ROOT / 'build/cattree/initials.svg',
         'oak-parts': ROOT / 'build/trees/oak-green.svg',
         **{n: ROOT / f'build/trees/{n}.svg' for n in ('letters-sheet', 'letter-moss', 'letter-blue', 'drop-spring', 'drop-summer', 'drop-autumn', 'drop-winter', 'drop-dead')}}
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
    P.append(page(art('oak4o'), caption('Seed 4 again, with the open crown: the same tree, limbs showing'), cls='plain'))
    P.append(page(art('oak2o'), caption('Seed 2, open crown'), cls='plain'))
    P.append(page(art('oak7o'), caption('Seed 7, open crown'), cls='plain'))
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
def seasons_pdf():
    P = []
    for sv, cap in (('sn-spring', 'Spring'), ('sn-summer', 'Summer'), ('sn-autumn', 'Autumn'), ('sn-winter', 'Winter'), ('sn-dead', 'Dead'),
                    ('sn-moss', 'Spanish moss'), ('sn-moss-open', 'Spanish moss, open crown'), ('sn-moss-winter', 'Spanish moss in winter'), ('sn-moss-dead', 'Spanish moss on the dead tree'),
                    ('sn-autumn-open', 'Autumn, open crown'), ('sn-autumn-blue', 'Autumn, in Delft blue'), ('sn-winter-blue', 'Winter, in Delft blue'), ('sn-dead-blue', 'Dead, in Delft blue')):
        P.append(page(art(sv), caption(cap), cls='plain'))
    cm = 72 / 2.54
    def crop(sv, x, top, w, cap):
        return page(art(sv, viewbox=f'{x * cm:.1f} {top * cm:.1f} {w * cm:.1f} {w * 1.294 * cm:.1f}'), caption(cap), cls='plain')
    P.append(crop('sn-winter', 1.2, 9, 7, 'Close up: a limb cut long ago, wound wood rolling in, shoots going straight up'))
    P.append(crop('sn-winter', 11.7, 15.5, 9.6, 'Close up: a snowman, and icicles on the swing'))
    P.append(crop('sn-winter', 0, 15.5, 9.6, 'Close up: holly in the snow'))
    P.append(crop('sn-autumn', 0, 15.5, 9.6, 'Close up: pumpkins, one carved, and fallen leaves'))
    P.append(crop('sn-summer', 5, 15, 9.6, 'Close up: the swing, and a heart in the bark'))
    P.append(crop('sn-dead', 3, 15, 9.6, 'Close up: bark falling away, shelf fungus'))
    return P
SENTENCES = (
    "A cut limb does not heal the way skin heals. The tree walls the wound off and rolls new wood in from the edges, a little more each year.",
    "From below that roll, dormant buds wake up and send shoots straight toward the light; gardeners call them water sprouts.",
    "An old oak can be wider than it is tall, because every limb has spent centuries reaching for whatever gap in the sky its neighbors left.",
    "This one is grown the same way. It starts with a scatter of points in the empty parts of the page, and each point pulls on the nearest branch tip until a branch arrives.",
    "Nothing here is drawn by hand, and nothing is copied. A drawing is only numbers and rules, so every seed grows a different tree.",
    "When a box of text is in the way, the points inside it are simply never placed. The branches find the room that is left, and they slide along the edge of the box when they meet it.",
    "The thickness of a limb is worked out from everything it has to carry, added up from the twigs back to the trunk.",
    "Each plate of bark is lit on one side, according to which way that part of the limb faces, so a trunk reads as round without a single gradient.",
    "If the text runs across the foot of the page, the ground simply moves up and stands on top of it.",
    "A narrow margin gets a slimmer trunk. A wide one gets the whole old giant, with room for a swing.",
    "Spanish moss is not a moss at all but a relative of the pineapple. It takes nothing from the tree, only somewhere to hang.",
    "Many oaks keep some of their dead leaves through the winter and drop them only when the new buds push them off in spring.",
    "A dead oak can stand for decades. Its bark falls away in sheets, shelf fungus climbs the trunk, and birds move in.",
    "Somewhere on every trunk, at a different height each time, two initials have been cut into a heart. The bark has been growing around them for years.",
    "Acorns take a long time to matter. An oak may be decades old before it bears a good crop, and in some years it bears almost none, then far too many for the squirrels to eat.",
    "Up close, the leaves are only smooth wavy outlines, a few thousand of them, painted in layers: pale ones at the back, dark ones behind the limbs, bright ones in front.",
    "Depth comes entirely from the order of painting. Whatever lives in the tree sits between the dark leaves and the bright ones, so it is partly hidden, the way it would be.",
    "A limb always comes out from behind its parent here. That one rule did more for the forks than any amount of detail in the bark.",
    "Bark is dead tissue, and it has to split to let the living wood beneath it grow. The plates and furrows of an old trunk are a record of it being outgrown, year after year.",
    "Snow only lies where a limb is level enough to hold it, so it is thickest on the long low boughs and absent on anything steep.",
    "A swing needs a limb that is low, level, and strong, with clear ground under it. If this page has no such limb, it has no swing.",
    "The growing tips of a tree compete for light, and the branches that lose are shed. The shape you see is what is left of a long argument about the sky.",
    "Most of the weight of an oak is not in the crown but in the trunk and the great lower limbs, which is why those limbs can reach out so far without falling.",
    "On this page, as on every other, a seed is the only thing that was chosen. Change it and a different tree grows in the same space, around the same words.",
    "Bats hunt in the open air along the edge of a tree, and they stay clear of the limbs here too, because nothing is allowed to fly into anything.",
    "Robins do not really migrate away from every garden. Plenty stay all winter, and they are easy to see against bare branches once the leaves are down.",
    "Holly keeps its leaves all year and its berries well into the cold, which is why it looks so well under a bare tree when everything else has gone gray.",
    "An oak that is cut back hard will often answer with a crown of straight new shoots, and people have harvested wood that way for centuries without killing the tree.",
    "There is no photograph behind any of this, and no reference drawing to trace. It comes out as paths and fills, and it stays sharp however far you zoom in.",
    "Text sets the terms. Draw a box anywhere on the page, and the tree that grows afterward treats it as a wall it has always known about.",
)
def fill(width, height, start, size=10.5):
    """whole sentences that fit a box of this size, in cm, from the pool, by estimate"""
    chars_line = width / (size * 0.0178)
    lines = int(height / (size * 1.42 * 0.0353)) - 1
    room, out, i = chars_line * lines * 1.08, [], start
    while room > 0:
        t = SENTENCES[i % len(SENTENCES)]
        if len(t) > room and out: break
        out.append(t)
        room -= len(t) + 1
        i += 1
    return ' '.join(out), i
def text_pdf():
    P = []
    n_ = [0]
    def tb(x, top, w, h, title=None, size=10.5):
        head = f'<h2>{title}</h2>' if title else ''
        room = h - (1.3 if title else 0)
        body, n_[0] = fill(w, room, n_[0], size)
        return textbox(x, top, w, h, f'{head}<p style="font-size:{size}pt;line-height:1.42">{body}</p>')
    P.append(page(art('tx-left'), tb(8.2, 2.5, 11.4, 22.9, 'A wide left margin')))
    P.append(page(art('tx-right'), tb(2, 2.5, 11.4, 22.9, 'A wide right margin, in autumn')))
    P.append(page(art('tx-short'), tb(8.2, 2.5, 11.4, 9, 'Short text, in spring')))
    P.append(page(art('tx-title'), textbox(3, 1.8, 15.6, 6, '<h1>Winter</h1><p class="sub">A title page, with the tree under it.</p>', 'center')))
    P.append(page(art('tx-center'), tb(4.5, 8.5, 12.6, 9, 'A box in the middle, in Delft blue')))
    P.append(page(art('tx-cols'), tb(1.8, 2.5, 8.4, 11, 'Two columns'), tb(11.4, 2.5, 8.4, 11)))
    P.append(page(art('tx-foot'), tb(2.5, 18.5, 16.6, 7.4, 'Text along the foot')))
    P.append(page(art('tx-scatter'), tb(1.5, 2, 7.5, 7, 'Scattered boxes', 10), tb(13, 11, 7, 6.5, None, 10), tb(1.5, 20, 6.5, 6, None, 10)))
    P.append(page(art('tx-narrow'), tb(6, 2.5, 9.6, 22.9, 'A narrow column')))
    P.append(page(art('tx-bands'), tb(1.8, 1.5, 18, 3), tb(1.8, 21.5, 18, 5)))
    P.append(page(art('tx-moss'), tb(2, 2.5, 8.6, 13, 'Spanish moss')))
    P.append(page(art('tx-mossdead'), tb(11, 15, 8.8, 10.4, 'Spanish moss, dead tree')))
    return P
def letters_pdf():
    P = [page(art('letters-sheet'), cls='plain')]
    n_ = [3]
    def text(x, top, w, h, drop, first, size=10.5):
        cap = art(drop, 'float:left;width:2.9cm;height:2.9cm;margin:0.1cm 0.4cm 0.1cm 0')
        lines = max(0, h - 1.5)
        body, n_[0] = fill(w, lines, n_[0], size)
        return textbox(x, top, w, h, f'{cap}<p style="font-size:{size}pt;line-height:1.42">{first} {body}</p>')
    P.append(page(art('lt-spring'), text(8.2, 2.5, 11.4, 11, 'drop-spring', 'pring is the shortest season for a big oak: the leaves come pale and small, and the limbs can still be seen through them.')))
    P.append(page(art('lt-summer'), text(8.2, 2.5, 11.4, 22.9, 'drop-summer', 'ummer closes the crown. Whatever lives in the tree now has to be looked for, and the swing hangs in the only deep shade on the page.')))
    P.append(page(art('lt-autumn'), text(2, 2.5, 11.4, 22.9, 'drop-autumn', 'utumn turns the crown a mass at a time, never all at once. The wind takes the leaves, and the bats have the open air to themselves.')))
    P.append(page(art('lt-winter'), text(3, 2, 15.6, 8.5, 'drop-winter', 'inter shows what the tree has been doing all along. Every fork and every old cut is in plain sight, with snow along the top of anything level.')))
    P.append(page(art('lt-dead'), text(11, 12, 8.8, 13.4, 'drop-dead', 'ead, it can stand for decades. The bark lets go in patches and the moss stays on, and the crows do not seem to mind at all.')))
    grid = f'<div style="position:absolute;left:2cm;top:3cm;width:8cm;height:8cm">{art("letter-moss")}</div><div style="position:absolute;left:11.5cm;top:3cm;width:8cm;height:8cm">{art("letter-blue")}</div>'
    P.append(page(grid, caption('Spanish moss on a letter, and winter in Delft blue'), cls='plain'))
    return P
for name, pages in (('cat-trees', gym_pdf()), ('oak-trees', oak_pdf()), ('oak-seasons', seasons_pdf()), ('oak-text', text_pdf()), ('oak-letters', letters_pdf())):
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>{name}</title><style>{STYLE}</style></head><body>{"".join(pages)}</body></html>'
    (ROOT / f'build/showcase/{name}.html').write_text(html)
    print(name, len(pages), 'pages', len(html) // (1024 * 1024), 'MB html')
