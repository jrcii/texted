import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMainMenu()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    @objc func showAbout(_ sender: Any?) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6

        let credits = NSMutableAttributedString()
        func line(_ text: String, bold: Bool = false, link: String? = nil) {
            let font = bold ? NSFont.boldSystemFont(ofSize: 11) : NSFont.systemFont(ofSize: 11)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ]
            if let link { attributes[.link] = URL(string: link)! }
            credits.append(NSAttributedString(string: text + "\n", attributes: attributes))
        }
        line("The leanest plain-text editor for macOS.", bold: true)
        line("Inspired by Jeena TextEd 1.0", link: "https://github.com/jeena/TextEd.app")

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
