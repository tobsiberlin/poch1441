#!/bin/zsh

set -u

project_root="/Users/tobsi/poch1441"
lab_root="$project_root/tasks/reviews/poch-melden-reinvention-v2"
backgrounds="$lab_root/assets/backgrounds"
components="$lab_root/assets/components"
output="$lab_root/mockups"
evidence="$lab_root/evidence"
work_dir="$(mktemp -d)"
font_regular="/System/Library/Fonts/Avenir Next.ttc"
font_display="/System/Library/Fonts/SFNS.ttf"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$output" "$evidence"

prepare_background() {
  magick "$1" -auto-orient -resize '1170x2532^' -gravity center -extent 1170x2532 "$2"
}

prepare_asset() {
  local source="$1"
  local width="$2"
  local rotation="$3"
  local destination="$4"
  magick "$source" -resize "${width}x" -background none -rotate "$rotation" \
    \( +clone -background '#000000' -shadow 64x16+0+20 \) \
    +swap -background none -layers merge +repage "$destination"
}

prepare_portrait() {
  local source="$1"
  local destination="$2"
  magick "$source" -resize '128x128^' -gravity center -extent 128x128 -alpha set \
    \( -size 128x128 xc:none -fill white -draw 'circle 64,64 64,3' -blur 0x0.7 \) \
    -compose DstIn -composite -compose Over \
    -stroke 'rgba(216,177,93,0.82)' -strokewidth 4 -fill none -draw 'circle 64,64 64,4' \
    \( +clone -background '#000000' -shadow 62x12+0+16 \) \
    +swap -background none -layers merge +repage "$destination"
}

for index in 1 2 3 4 5; do
  prepare_background "$backgrounds/0${index}-"*.png "$work_dir/background-${index}.png"
done

prepare_asset "$components/poch-ring-native.png" 760 0 "$work_dir/ring-760.png"
prepare_asset "$components/poch-ring-native.png" 650 0 "$work_dir/ring-650.png"
prepare_asset "$components/poch-ring-native.png" 560 0 "$work_dir/ring-560.png"
prepare_asset "$components/poch-ring-native.png" 500 0 "$work_dir/ring-500.png"

for card in 7D 8D 9D KD QD AS 10C JC; do
  prepare_asset "$components/${card}.png" 230 0 "$work_dir/${card}-230.png"
  prepare_asset "$components/${card}.png" 285 0 "$work_dir/${card}-285.png"
done

for seat in hana noah jonas; do
  prepare_portrait "$components/${seat}-thinking.png" "$work_dir/${seat}.png"
done

prepare_asset "$components/coin-silver.png" 104 0 "$work_dir/coin-silver.png"
prepare_asset "$components/coin-gold.png" 104 0 "$work_dir/coin-gold.png"

# 1. Constellation - the exact hand and ring become one rule diagram.
magick "$work_dir/background-1.png" \
  -fill 'rgba(4,7,11,0.80)' -stroke 'rgba(222,184,104,0.30)' -strokewidth 2 \
  -draw 'roundrectangle 54,60 1116,356 42,42' \
  -draw 'roundrectangle 56,2060 1114,2454 46,46' \
  -stroke 'rgba(219,177,86,0.74)' -strokewidth 3 -fill none \
  -draw "path 'M 340,1990 C 335,1700 355,1440 435,1192'" \
  -draw "path 'M 585,1950 C 585,1610 585,1400 585,1115'" \
  -draw "path 'M 830,1990 C 835,1700 815,1440 735,1192'" \
  -stroke 'rgba(110,224,245,0.48)' -strokewidth 2 \
  -draw 'circle 435,1192 435,1181' \
  -draw 'circle 585,1115 585,1104' \
  -draw 'circle 735,1192 735,1181' \
  "$work_dir/ring-760.png" -geometry +205+535 -composite \
  "$work_dir/hana.png" -geometry +230+382 -composite \
  "$work_dir/noah.png" -geometry +520+382 -composite \
  "$work_dir/jonas.png" -geometry +810+382 -composite \
  \( "$work_dir/7D-285.png" -background none -rotate -12 \) -geometry +255+1580 -composite \
  "$work_dir/8D-285.png" -geometry +442+1538 -composite \
  \( "$work_dir/9D-285.png" -background none -rotate 12 \) -geometry +630+1580 -composite \
  -font "$font_display" -fill '#F7F6F1' -pointsize 70 -annotate +86+124 'POCH' \
  -fill '#D3A94E' -pointsize 62 -annotate +300+129 '1441' \
  -font "$font_regular" -fill '#77808F' -pointsize 24 -kerning 7 -annotate +86+232 'PHASE 1 · MELDEN' \
  -fill '#FFFFFF' -pointsize 44 -kerning 0 -annotate +86+286 'DEINE KARO-FOLGE IST VOLLSTÄNDIG' \
  -fill '#D2D6DE' -pointsize 27 -annotate +120+2135 '7♦, 8♦ und 9♦ berühren drei Regelkontakte.' \
  -fill '#E4B958' -pointsize 24 -kerning 4 -annotate +120+2200 'AUSZAHLUNG · 4 MÜNZEN' \
  -fill 'rgba(255,255,255,0.08)' -stroke 'rgba(255,255,255,0.18)' -draw 'roundrectangle 116,2262 470,2385 32,32' \
  -fill '#A8ADB8' -stroke none -pointsize 34 -kerning 0 -annotate +224+2318 'Passen' \
  -fill '#D3A94E' -draw 'roundrectangle 498,2262 1054,2385 32,32' \
  -fill '#090B0D' -pointsize 34 -annotate +622+2318 'Folge melden  +4' \
  "$output/01-constellation.png"

# 2. Exploded ring - hand, rule and payout occupy separate physical planes.
magick "$work_dir/background-2.png" \
  -fill 'rgba(3,4,6,0.78)' -stroke 'rgba(255,255,255,0.14)' -strokewidth 2 \
  -draw 'roundrectangle 54,54 1116,314 42,42' \
  "$work_dir/ring-560.png" -geometry +305+280 -composite \
  "$work_dir/coin-silver.png" -geometry +438+910 -composite \
  "$work_dir/coin-gold.png" -geometry +535+878 -composite \
  "$work_dir/coin-silver.png" -geometry +633+910 -composite \
  \( "$work_dir/7D-230.png" -background none -rotate -9 \) -geometry +255+1265 -composite \
  "$work_dir/8D-230.png" -geometry +468+1225 -composite \
  \( "$work_dir/9D-230.png" -background none -rotate 9 \) -geometry +680+1265 -composite \
  -fill 'rgba(5,7,10,0.86)' -stroke 'rgba(220,180,96,0.28)' -draw 'roundrectangle 88,2048 1082,2438 44,44' \
  -font "$font_display" -fill '#F7F6F1' -pointsize 68 -annotate +84+112 'POCH' \
  -fill '#D3A94E' -pointsize 60 -annotate +292+117 '1441' \
  -font "$font_regular" -fill '#87909E' -pointsize 23 -kerning 7 -annotate +84+210 'ARCHITEKTUR-LAGEN · MELDEN' \
  -fill '#FFFFFF' -pointsize 42 -kerning 0 -annotate +84+265 'HAND → REGEL → AUSZAHLUNG' \
  -fill '#E0B65B' -pointsize 23 -kerning 4 -annotate +130+2125 'EBENE 03 · AUSZAHLUNG' \
  -fill '#F3F2EE' -pointsize 38 -kerning 0 -annotate +130+2192 'Vier Münzen lösen sich aus der Folge.' \
  -fill '#AEB4BE' -pointsize 27 -annotate +130+2260 'Jede Ebene bleibt einzeln prüfbar.' \
  -fill '#D3A94E' -draw 'roundrectangle 640,2312 1025,2404 28,28' \
  -fill '#090B0D' -pointsize 30 -annotate +710+2354 'Auszahlen' \
  "$output/02-exploded-ring.png"

# 3. Evidence table - every payout has a visible cause.
magick "$work_dir/background-3.png" \
  -fill 'rgba(2,3,5,0.70)' -stroke 'rgba(222,183,100,0.36)' -strokewidth 2 \
  -draw 'roundrectangle 46,44 1124,254 36,36' \
  "$work_dir/ring-650.png" -geometry +45+285 -composite \
  \( "$work_dir/7D-230.png" -background none -rotate -3 \) -geometry +780+360 -composite \
  "$work_dir/8D-230.png" -geometry +780+735 -composite \
  \( "$work_dir/9D-230.png" -background none -rotate 3 \) -geometry +780+1110 -composite \
  \( "$work_dir/AS-230.png" -background none -rotate -18 \) -geometry +135+1650 -composite \
  \( "$work_dir/10C-230.png" -background none -rotate -11 \) -geometry +278+1600 -composite \
  \( "$work_dir/KD-230.png" -background none -rotate -4 \) -geometry +420+1572 -composite \
  \( "$work_dir/QD-230.png" -background none -rotate 4 \) -geometry +562+1572 -composite \
  \( "$work_dir/JC-230.png" -background none -rotate 11 \) -geometry +704+1600 -composite \
  -stroke 'rgba(223,184,99,0.74)' -strokewidth 3 -fill none \
  -draw "path 'M 680,565 C 735,545 740,510 780,500'" \
  -draw "path 'M 654,718 C 738,780 742,860 780,875'" \
  -draw "path 'M 608,868 C 700,1020 735,1220 780,1250'" \
  -font "$font_display" -fill '#F7F6F1' -pointsize 64 -annotate +78+95 'POCH' \
  -fill '#D3A94E' -pointsize 56 -annotate +274+100 '1441' \
  -font "$font_regular" -fill '#8D96A4' -pointsize 22 -kerning 6 -annotate +78+188 'MELDEN · BEWEISKETTE' \
  -fill 'rgba(6,7,10,0.90)' -stroke 'rgba(255,255,255,0.12)' -draw 'roundrectangle 80,2050 1090,2445 44,44' \
  -fill '#E1B75D' -stroke none -pointsize 23 -kerning 5 -annotate +126+2122 'DREI BELEGE · EIN ERGEBNIS' \
  -fill '#F5F4F0' -pointsize 42 -kerning 0 -annotate +126+2192 'Die Karo-Folge zahlt 4 Münzen.' \
  -fill '#ABB1BC' -pointsize 26 -annotate +126+2260 'Trumpf, Hand und Ring bleiben gleichzeitig sichtbar.' \
  -fill '#D3A94E' -draw 'roundrectangle 665,2320 1036,2410 26,26' \
  -fill '#090B0D' -pointsize 29 -annotate +728+2362 'Belege melden' \
  "$output/03-evidence-table.png"

# 4. Hand theatre - the combination becomes the hero without losing the ring.
magick "$work_dir/background-4.png" \
  -fill 'rgba(0,0,0,0.52)' -draw 'rectangle 0,0 1170,420' \
  "$work_dir/ring-500.png" -geometry +335+300 -composite \
  "$work_dir/hana.png" -geometry +160+460 -composite \
  "$work_dir/noah.png" -geometry +520+432 -composite \
  "$work_dir/jonas.png" -geometry +880+460 -composite \
  \( "$work_dir/7D-285.png" -background none -rotate -11 \) -geometry +190+1030 -composite \
  "$work_dir/8D-285.png" -geometry +440+930 -composite \
  \( "$work_dir/9D-285.png" -background none -rotate 11 \) -geometry +685+1030 -composite \
  "$work_dir/coin-gold.png" -geometry +385+1580 -composite \
  "$work_dir/coin-silver.png" -geometry +500+1610 -composite \
  "$work_dir/coin-silver.png" -geometry +615+1580 -composite \
  "$work_dir/coin-silver.png" -geometry +730+1610 -composite \
  -fill 'rgba(7,5,7,0.88)' -stroke 'rgba(225,185,101,0.32)' -strokewidth 2 -draw 'roundrectangle 72,2015 1098,2446 46,46' \
  -font "$font_display" -fill '#F7F6F1' -pointsize 66 -annotate +82+92 'POCH' \
  -fill '#D3A94E' -pointsize 58 -annotate +284+97 '1441' \
  -font "$font_regular" -fill '#D4A953' -pointsize 23 -kerning 6 -annotate +82+188 'HAND-BÜHNE · MELDEN' \
  -fill '#FFFFFF' -pointsize 45 -kerning 0 -annotate +82+248 'DEINE FOLGE TRITT INS LICHT' \
  -fill '#E0B65B' -pointsize 22 -kerning 5 -annotate +126+2100 'KARO IST TRUMPF' \
  -fill '#F4F2EE' -pointsize 42 -kerning 0 -annotate +126+2172 '7♦ · 8♦ · 9♦' \
  -fill '#B7BBC4' -pointsize 27 -annotate +126+2240 'Vier Münzen warten im Folge-Pott.' \
  -fill '#D3A94E' -draw 'roundrectangle 620,2310 1045,2405 28,28' \
  -fill '#090B0D' -pointsize 30 -annotate +696+2354 'Folge melden' \
  "$output/04-hand-theatre.png"

# 5. Dual lens - cause and effect remain visible at once.
magick "$work_dir/background-5.png" \
  -fill 'rgba(6,5,4,0.72)' -stroke 'rgba(220,178,92,0.28)' -strokewidth 2 -draw 'roundrectangle 46,48 1124,286 38,38' \
  "$work_dir/ring-650.png" -geometry +510+350 -composite \
  \( "$work_dir/AS-230.png" -background none -rotate -16 \) -geometry +40+1220 -composite \
  \( "$work_dir/10C-230.png" -background none -rotate -8 \) -geometry +128+1160 -composite \
  "$work_dir/7D-230.png" -geometry +235+1100 -composite \
  \( "$work_dir/8D-230.png" -background none -rotate 8 \) -geometry +338+1140 -composite \
  \( "$work_dir/9D-230.png" -background none -rotate 16 \) -geometry +440+1200 -composite \
  -stroke 'rgba(222,181,95,0.88)' -strokewidth 4 -fill 'rgba(10,12,14,0.76)' \
  -draw 'roundrectangle 536,1060 634,1160 48,48' \
  -font "$font_regular" -fill '#E0B75D' -stroke none -pointsize 42 -annotate +562+1115 '↔' \
  -fill 'rgba(5,6,8,0.86)' -stroke 'rgba(255,255,255,0.14)' -draw 'roundrectangle 65,1998 1105,2448 46,46' \
  -font "$font_display" -fill '#F7F6F1' -pointsize 66 -annotate +80+98 'POCH' \
  -fill '#D3A94E' -pointsize 58 -annotate +282+103 '1441' \
  -font "$font_regular" -fill '#978365' -pointsize 22 -kerning 6 -annotate +80+192 'DOPPELLINSE · MELDEN' \
  -fill '#FFFFFF' -pointsize 43 -kerning 0 -annotate +80+250 'URSACHE UND WIRKUNG IN EINEM BLICK' \
  -fill '#D7B46A' -pointsize 22 -kerning 5 -annotate +112+2082 'LINKS · DEINE HAND' \
  -fill '#B8C2D0' -pointsize 22 -kerning 5 -annotate +650+2082 'RECHTS · DER RING' \
  -fill '#F4F2EE' -pointsize 34 -kerning 0 -annotate +112+2152 '7♦  8♦  9♦' \
  -fill '#F4F2EE' -pointsize 34 -annotate +650+2152 'FOLGE · +4' \
  -fill '#AEB4BE' -pointsize 26 -annotate +112+2220 'Eine Entscheidung, zwei gleichzeitig lesbare Folgen.' \
  -fill '#D3A94E' -draw 'roundrectangle 628,2310 1050,2406 28,28' \
  -fill '#090B0D' -pointsize 30 -annotate +704+2355 'Folge melden' \
  "$output/05-dual-lens.png"

identify -format '%f %wx%h\n' "$output"/*.png

for mockup in "$output"/*.png; do
  contact_name="${mockup:t:r}"
  magick "$mockup" -thumbnail '360x779' -bordercolor '#07090c' -border 18 \
    "$work_dir/contact-${contact_name}.png"
done

magick "$work_dir"/contact-*.png +append "$evidence/contact-sheet.png"
