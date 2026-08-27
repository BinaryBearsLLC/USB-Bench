on run argv
    if (count of argv) is not 10 then error "configure-dmg: expected volume, items, background, window bounds, icon size, and text size"

    set volumeFolder to POSIX file (item 1 of argv) as alias
    set itemsPath to item 2 of argv
    set backgroundName to item 3 of argv
    set windowLeft to (item 4 of argv) as integer
    set windowTop to (item 5 of argv) as integer
    set windowRight to (item 6 of argv) as integer
    set windowBottom to (item 7 of argv) as integer
    set finderIconSize to (item 8 of argv) as integer
    set finderTextSize to (item 9 of argv) as integer
    set delaySeconds to (item 10 of argv) as real
    set itemRows to paragraphs of (read POSIX file itemsPath as «class utf8»)

    tell application "Finder"
        open volumeFolder
        set volumeWindow to container window of volumeFolder
        set current view of volumeWindow to icon view
        set toolbar visible of volumeWindow to false
        set statusbar visible of volumeWindow to false
        set pathbar visible of volumeWindow to false
        set bounds of volumeWindow to {windowLeft, windowTop, windowRight, windowBottom}

        set viewOptions to the icon view options of volumeWindow
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to finderIconSize
        set text size of viewOptions to finderTextSize
        set background picture of viewOptions to file (".background:" & backgroundName) of volumeFolder

        repeat with itemRow in itemRows
            set rowText to itemRow as text
            if rowText is not "" and rowText does not start with "#" then
                set AppleScript's text item delimiters to tab
                set rowFields to text items of rowText
                set AppleScript's text item delimiters to ""
                if (count of rowFields) is greater than or equal to 4 then
                    set itemName to item 2 of rowFields
                    set itemX to (item 3 of rowFields) as integer
                    set itemY to (item 4 of rowFields) as integer
                    set position of item itemName of volumeFolder to {itemX, itemY}
                end if
            end if
        end repeat

        update volumeFolder without registering applications
        delay delaySeconds
        close volumeWindow
    end tell
end run
