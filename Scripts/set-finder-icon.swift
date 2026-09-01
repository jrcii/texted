import AppKit

// Programmatic version of the Get Info icon-paste trick: stamps a custom
// Finder icon onto the bundle. macOS 26 renders custom Finder icons bare,
// bypassing the gray platter it puts on non-conforming app icons.
// Usage: swift Scripts/set-finder-icon.swift <icns> <app-path>

let icnsPath = CommandLine.arguments[1]
let appPath = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: icnsPath) else {
    fputs("cannot load \(icnsPath)\n", stderr)
    exit(1)
}
let ok = NSWorkspace.shared.setIcon(image, forFile: appPath, options: [])
print(ok ? "custom Finder icon applied to \(appPath)" : "FAILED")
exit(ok ? 0 : 1)
