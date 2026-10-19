on run argv
    set mountPath to item 1 of argv
    set mountedAlias to POSIX file mountPath as alias
    tell application "Finder"
        set mountedFolder to folder mountedAlias
        open mountedFolder
        delay 2
        tell container window of mountedFolder
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {100, 100, 820, 460}
        end tell
        set opts to icon view options of container window of mountedFolder
        tell opts
            set arrangement to not arranged
            set icon size to 88
            set text size to 13
            set background picture to POSIX file (mountPath & "/.background/background.png") as alias
        end tell
        tell mountedFolder
            set position of item ".background" to {120, 600}
            set position of item "Wianu.app" to {210, 190}
            set extension hidden of item "Wianu.app" to true
            set position of item "Applications" to {510, 190}
        end tell
        close container window of mountedFolder
        open mountedFolder
        delay 2
        set bounds of container window of mountedFolder to {100, 100, 820, 460}
        update mountedFolder without registering applications
        delay 3
    end tell
end run
