import AppKit

func buildMainMenu() -> NSMenu {
    let mainMenu = NSMenu()

    // App
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About TextEd", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "Hide TextEd", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "Quit TextEd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    addSubmenu(appMenu, titled: "TextEd", to: mainMenu)

    // File
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
    fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
    let recentMenu = NSMenu(title: "Open Recent")
    // An item with this action marks the submenu as the recent-documents menu;
    // AppKit populates the rest.
    recentMenu.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
    let recentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
    recentItem.submenu = recentMenu
    fileMenu.addItem(recentItem)
    fileMenu.addItem(.separator())
    fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    fileMenu.addItem(withTitle: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
    let saveAs = fileMenu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "s")
    saveAs.keyEquivalentModifierMask = [.command, .shift]
    fileMenu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
    addSubmenu(fileMenu, titled: "File", to: mainMenu)

    // Edit
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenu.addItem(.separator())
    let findMenu = NSMenu(title: "Find")
    let find = NSMenuItem(title: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
    find.tag = NSFindPanelAction.showFindPanel.rawValue.asInt
    findMenu.addItem(find)
    let findNext = NSMenuItem(title: "Find Next", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
    findNext.tag = NSFindPanelAction.next.rawValue.asInt
    findMenu.addItem(findNext)
    let findPrev = NSMenuItem(title: "Find Previous", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
    findPrev.keyEquivalentModifierMask = [.command, .shift]
    findPrev.tag = NSFindPanelAction.previous.rawValue.asInt
    findMenu.addItem(findPrev)
    let useSelection = NSMenuItem(title: "Use Selection for Find", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "e")
    useSelection.tag = NSFindPanelAction.setFindString.rawValue.asInt
    findMenu.addItem(useSelection)
    let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
    findItem.submenu = findMenu
    editMenu.addItem(findItem)
    addSubmenu(editMenu, titled: "Edit", to: mainMenu)

    // Format
    let formatMenu = NSMenu(title: "Format")
    let bigger = formatMenu.addItem(withTitle: "Bigger", action: #selector(Document.makeTextBigger(_:)), keyEquivalent: "+")
    bigger.keyEquivalentModifierMask = [.command]
    formatMenu.addItem(withTitle: "Smaller", action: #selector(Document.makeTextSmaller(_:)), keyEquivalent: "-")
    addSubmenu(formatMenu, titled: "Format", to: mainMenu)

    // Window
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    windowMenu.addItem(.separator())
    windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
    addSubmenu(windowMenu, titled: "Window", to: mainMenu)
    NSApp.windowsMenu = windowMenu

    return mainMenu
}

private func addSubmenu(_ submenu: NSMenu, titled title: String, to mainMenu: NSMenu) {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = submenu
    mainMenu.addItem(item)
}

private extension UInt {
    var asInt: Int { Int(bitPattern: self) }
}
