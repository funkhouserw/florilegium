#!/bin/sh
# montage.sh OUT.png NAME... : the pages side by side (left 9.5 cm of each: the margin and a little text)
set -e
cd "$(dirname "$0")/../../build/cattree"
out=$1; shift
h=1300; w=$(echo "$h*9.5/29.7" | bc)
{ echo '<html><body style="margin:0;background:#fff;display:flex;gap:6px">'
  for n in "$@"; do echo "<div style=\"width:${w}px;height:${h}px;overflow:hidden\"><img src=\"$n.svg\" style=\"height:${h}px\"></div>"; done
  echo '</body></html>'; } > _m.html
W=$(( ($w + 6) * $# ))
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --window-size=$W,$h --screenshot="$PWD/$out" "file://$PWD/_m.html" 2>/dev/null
echo "$PWD/$out"
