#!/bin/bash
# Package an app bundle as a drag-to-install DMG: the app beside an
# Applications alias, over a background with an arrow between them.
#
#   Scripts/make-dmg.sh <TextEd.app> <out.dmg>
#
# Finder lays out the window through AppleScript, so the first run asks
# for permission to control Finder.

set -euo pipefail

APP=${1:?usage: make-dmg.sh <app> <out.dmg>}
OUT=${2:?usage: make-dmg.sh <app> <out.dmg>}
VOL=TextEd
HERE=$(cd "$(dirname "$0")" && pwd)

WORK=$(mktemp -d)
MNT=
cleanup() {
    [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet -force 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

# Background at 1x and 2x, combined so Retina screens get the sharp one.
swift "$HERE/dmg-background.swift" "$WORK/bg.png" 1
swift "$HERE/dmg-background.swift" "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/bg.tiff" 2>/dev/null

mkdir -p "$WORK/stage/.background"
ditto "$APP" "$WORK/stage/$(basename "$APP")"
ln -s /Applications "$WORK/stage/Applications"
cp "$WORK/bg.tiff" "$WORK/stage/.background/bg.tiff"

hdiutil create -quiet -srcfolder "$WORK/stage" -volname "$VOL" -fs HFS+ \
    -format UDRW -ov "$WORK/rw.dmg"
MNT=$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen \
    | awk -F'\t' '/\/Volumes\// { print $NF }')

# Finder addresses the disk by its mounted name, which may be "TextEd 1"
# if another TextEd volume is already mounted. Bounds go last, once the
# toolbar is hidden; closing and reopening the window would reset them.
osascript <<EOF
tell application "Finder"
    tell disk "$(basename "$MNT")"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set opts to icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 13
        set background picture of opts to file ".background:bg.tiff"
        set bounds of container window to {200, 120, 800, 548}
        set position of item "$(basename "$APP")" of container window to {150, 190}
        set position of item "Applications" of container window to {450, 190}
        update without registering applications
        close
    end tell
end tell
EOF

# Finder writes .DS_Store asynchronously after the window closes.
for _ in $(seq 50); do
    perl -0777 -ne 'exit !/bwsp/' "$MNT/.DS_Store" 2>/dev/null && break
    sleep 0.2
done

# Custom icons go in last: Finder deletes .VolumeIcon.icns and clears the
# custom-icon flag while laying out the window. The app gets the same
# stamped icon `make install` gives it, so macOS 26 shows it bare instead
# of on a platter; a Finder drag to Applications keeps it. The signature
# still verifies (only --strict objects to the resource fork).
cp "$APP/Contents/Resources/TextEd.icns" "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT"
swift "$HERE/set-finder-icon.swift" "$HERE/../Resources/FinderIcon.icns" \
    "$MNT/$(basename "$APP")" >/dev/null
sync
hdiutil detach "$MNT" -quiet
MNT=
rm -f "$OUT"
hdiutil convert -quiet "$WORK/rw.dmg" -format ULFO -o "$OUT"
echo "$OUT"
