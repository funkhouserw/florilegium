# Fonts the studio embeds in its PDFs

`fell.ttf` and `lmroman.ttf` are the playground's Latin subsets (`web/fonts`, with their licenses and
how they were made) as plain TrueType. pdf-lib's subsetter makes a font that can be selected but draws
nothing from a WOFF2, and an invalid one from CFF outlines, so `lmroman.ttf` also has its outlines
converted to quadratics. It stays named Florilegium Roman, as GUST asks of modified fonts.
