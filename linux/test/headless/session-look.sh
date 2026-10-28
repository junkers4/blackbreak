# Looks only: the work phase with the menu open, then the notice (a visual check, not part of the suite).
. "$(dirname "$0")/lib.sh"
check_wait 'the extension is active' 15 "Main.extensionManager.lookup('$UUID').state === 1"
ev "$X._indicator.menu.open()" >/dev/null; sleep 1
screenshot /tmp/bbt/menu-linux.png
ev "$X._indicator.menu.close(); $X._notice.show('Break in 10 s')" >/dev/null; sleep 1
screenshot /tmp/bbt/notice-linux.png
ev "Main.extensionManager.openExtensionPrefs('$UUID', '', {})" >/dev/null; sleep 6
screenshot /tmp/bbt/prefs-linux.png
