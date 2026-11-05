# Fonts the studio embeds in its PDFs

`fell.ttf`, `fell-italic.ttf`, `lmroman.ttf`, `lmroman-italic.ttf` and `lmroman-bold.ttf` are the playground's Latin subsets (`web/fonts`, with their licenses and
how they were made) as plain TrueType. pdf-lib's subsetter makes a font that can be selected but draws
nothing from a WOFF2, and an invalid one from CFF outlines, so the `lmroman` files also have their outlines
converted to quadratics. It stays named Florilegium Roman, as GUST asks of modified fonts.
IM Fell has no bold, and neither typeface has a bold italic: the studio makes the face it has heavier.
