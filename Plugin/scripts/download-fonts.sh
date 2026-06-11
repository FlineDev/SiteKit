#!/bin/bash
# Download Google Fonts as woff2 files to Theme/fonts/ for self-hosting.
#
# Usage: ./download-fonts.sh <site-root> <family>:<weight1,weight2> [family2:weights...]
#   e.g. ./download-fonts.sh /path/to/site "Inter:400,500,600,700" "JetBrains Mono:400,500"
#
# Uses the google-webfonts-helper public API (gwfh.mranftl.com) which serves woff2
# files under the SIL Open Font License or Apache 2.0 (same as Google Fonts).

set -e

SITE="$1"; shift
FONTS_DIR="$SITE/Theme/fonts"
mkdir -p "$FONTS_DIR"

# Map family name to gwfh slug (lowercase, spaces → hyphens)
slugify() {
   echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Map weight number to gwfh variant (400 → "regular", others → number string)
weight_variant() {
   local w="$1"
   if [ "$w" = "400" ]; then
      echo "regular"
   else
      echo "$w"
   fi
}

for arg in "$@"; do
   family="${arg%%:*}"
   weights_csv="${arg##*:}"
   slug=$(slugify "$family")

   # Build variants list for API (regular,500,600,700)
   variants=""
   for w in ${weights_csv//,/ }; do
      v=$(weight_variant "$w")
      variants="${variants:+$variants,}$v"
   done

   tmp=$(mktemp -d)
   url="https://gwfh.mranftl.com/api/fonts/${slug}?download=zip&subsets=latin&variants=${variants}&formats=woff2"
   echo "→ Downloading ${family} (${weights_csv}) from ${url}"
   curl -fsSL "$url" -o "$tmp/font.zip"
   unzip -qq "$tmp/font.zip" -d "$tmp/extracted"

   # gwfh names files like: inter-v20-latin-regular.woff2, inter-v20-latin-500.woff2
   # Rename to: Inter-400.woff2, Inter-500.woff2 for predictable paths.
   family_clean=$(echo "$family" | tr -d ' ')
   for w in ${weights_csv//,/ }; do
      v=$(weight_variant "$w")
      # Find the matching file (variant is regular/500/etc)
      src=$(find "$tmp/extracted" -iname "*${v}.woff2" | head -1)
      if [ -z "$src" ]; then
         echo "  ! Not found: ${family} weight ${w} (variant ${v})"
         continue
      fi
      dst="$FONTS_DIR/${family_clean}-${w}.woff2"
      cp "$src" "$dst"
      size=$(wc -c < "$dst" | tr -d ' ')
      echo "  ✓ ${family_clean}-${w}.woff2 (${size} bytes)"
   done

   rm -rf "$tmp"
done

echo "Done. Fonts in: $FONTS_DIR"
ls -la "$FONTS_DIR"
