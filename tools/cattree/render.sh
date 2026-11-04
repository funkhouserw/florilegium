#!/bin/sh
# render.sh NAME DPI [x y w h (cm, from the top-left)] -> build/cattree/NAME[-crop].png
# Full page at DPI, or a crop of it.
set -e
cd "$(dirname "$0")/../../build/cattree"
name=$1; dpi=${2:-150}
pw=$(echo "21*$dpi/2.54" | bc); ph=$(echo "29.7*$dpi/2.54" | bc)
if [ -n "$3" ]; then
  ox=$(echo "-$3*$dpi/2.54" | bc); oy=$(echo "-$4*$dpi/2.54" | bc)
  ww=$(echo "$5*$dpi/2.54" | bc); wh=$(echo "$6*$dpi/2.54" | bc); out="$name-crop.png"
else ox=0; oy=0; ww=$pw; wh=$ph; out="$name.png"; fi
cat > "_r.html" <<H
<html><body style="margin:0;overflow:hidden"><img src="$name.svg" style="position:absolute;left:${ox}px;top:${oy}px;width:${pw}px;height:${ph}px"></body></html>
H
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --window-size=$ww,$wh --screenshot="$PWD/$out" "file://$PWD/_r.html" 2>/dev/null
echo "$PWD/$out"
