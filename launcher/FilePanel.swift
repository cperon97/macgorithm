// SPDX-License-Identifier: MIT
// Native macOS file panel for Wine's Open/Save dialogs (comdlg32 patch 0005).
//
// Usage: FilePanel open|save|folder --out FILE [--title T] [--dir D] [--name N] [--types ext,ext]
// Writes the chosen path to FILE and exits with 0; exits with 1 when the user cancels.

import Cocoa
import UniformTypeIdentifiers

let args = Array(CommandLine.arguments.dropFirst())
guard let mode = args.first, ["open", "save", "folder"].contains(mode) else { exit(2) }
var opts: [String: String] = [:]
var i = 1
while i + 1 < args.count { opts[args[i]] = args[i + 1]; i += 2 }
guard let out = opts["--out"] else { exit(2) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let panel: NSSavePanel
if mode == "save" {
    let save = NSSavePanel()
    save.canCreateDirectories = true
    save.isExtensionHidden = false
    if let name = opts["--name"] { save.nameFieldStringValue = name }
    panel = save
} else {
    let open = NSOpenPanel()
    open.canChooseFiles = mode == "open"
    open.canChooseDirectories = mode == "folder"
    open.allowsMultipleSelection = false
    open.canCreateDirectories = mode == "folder"
    panel = open
}
if let title = opts["--title"] { panel.title = title; panel.message = title }
if let dir = opts["--dir"] { panel.directoryURL = URL(fileURLWithPath: dir, isDirectory: true) }
if mode != "folder", let types = opts["--types"] {
    let exts = types.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    if !exts.isEmpty {
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = exts.compactMap { UTType(filenameExtension: $0) }
        } else {
            panel.allowedFileTypes = exts
        }
    }
}

/// Brings Flowgorithm (the Wine process that launched us) back to the front.
func returnToCaller() {
    NSRunningApplication(processIdentifier: getppid())?.activate(options: [.activateIgnoringOtherApps])
}

let result = panel.runModal()
if result == .OK, let url = panel.url {
    try? (url.path + "\n").write(toFile: out, atomically: true, encoding: .utf8)
    returnToCaller()
    exit(0)
}
returnToCaller()
exit(1)
