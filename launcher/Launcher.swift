// SPDX-License-Identifier: MIT
// Flowgorithm launcher for macOS (unofficial Wine wrapper).
//
// This is the app's executable (LSUIElement: it never shows in the Dock). It:
//  - creates the Wine prefix on first launch, showing a progress window;
//  - starts Flowgorithm.exe through the "engine" bundle Engine/Flowgorithm.app,
//    so the Wine process gets Flowgorithm's name and icon in the Dock and menu bar;
//  - receives .fprg documents opened from the Finder (even while the app is
//    already running) and opens them in Flowgorithm;
//  - quits when every Flowgorithm window has been closed.

import Cocoa

/// UI strings: English by default, Italian when that is the user's preferred language.
private let italian = Locale.preferredLanguages.first?.hasPrefix("it") ?? false
private func tr(_ english: String, _ italianText: String) -> String { italian ? italianText : english }

final class Launcher: NSObject, NSApplicationDelegate {
    private let fm = FileManager.default
    private let res = Bundle.main.resourceURL!
    private lazy var engine = res.appendingPathComponent("Engine/Flowgorithm.app")
    private lazy var engineExe = engine.appendingPathComponent("Contents/MacOS/wine")
    private lazy var wineBin = engine.appendingPathComponent("Contents/Resources/wine/bin")
    private lazy var program = res.appendingPathComponent("Flowgorithm/Flowgorithm.exe")
    private lazy var filePanel = res.appendingPathComponent("FilePanel.app/Contents/MacOS/FilePanel")
    private lazy var prefix: URL = {
        let name = Bundle.main.object(forInfoDictionaryKey: "MGWinePrefix") as? String ?? "prefix"
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flowgorithm/\(name)")
    }()
    private lazy var logURL = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/Flowgorithm.log")
    private lazy var log: FileHandle? = {
        try? fm.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: logURL.path) { fm.createFile(atPath: logURL.path, contents: nil) }
        let h = try? FileHandle(forWritingTo: logURL)
        h?.seekToEndOfFile()
        return h
    }()

    private var pending: [URL] = []
    private var ready = false
    private var children: [Process: Date] = [:]
    private var setupWindow: NSWindow?

    // MARK: NSApplicationDelegate

    func application(_ sender: NSApplication, open urls: [URL]) {
        if ready { urls.forEach { runFlowgorithm($0) } } else { pending += urls }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // give the launch-time "open document" events a moment to arrive before starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.start() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let pid = children.keys.first?.processIdentifier {
            NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        } else if ready {
            runFlowgorithm(nil)
        }
        return false
    }

    // MARK: startup

    private var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        env["WINEDEBUG"] = "-all"
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"
        env["MACGORITHM_FILE_PANEL"] = filePanel.path
        return env
    }

    private func start() {
        let marker = prefix.appendingPathComponent(".macgorithm-ready")
        if fm.fileExists(atPath: marker.path) { launchPending(); return }
        showSetupWindow()
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = self.setupPrefix(marker: marker)
            DispatchQueue.main.async {
                self.setupWindow?.close()
                self.setupWindow = nil
                if ok { self.launchPending() } else { self.fail() }
            }
        }
    }

    private func launchPending() {
        ready = true
        if pending.isEmpty { runFlowgorithm(nil) } else { pending.forEach { runFlowgorithm($0) } }
        pending = []
    }

    @discardableResult
    private func tool(_ exe: URL, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        p.environment = environment
        if let log = log { p.standardOutput = log; p.standardError = log }
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private func setupPrefix(marker: URL) -> Bool {
        try? fm.createDirectory(at: prefix, withIntermediateDirectories: true)
        let wine = wineBin.appendingPathComponent("wine")
        tool(wine, ["wineboot", "-i"])
        let reg = prefix.appendingPathComponent("macgorithm-fonts.reg")
        // UTF-16LE .reg file with BOM, like Windows writes them (Wine mangles hex(7) data in ANSI files)
        if (try? ("\u{FEFF}" + fontLinkRegistry()).write(to: reg, atomically: true, encoding: .utf16LittleEndian)) != nil {
            tool(wine, ["regedit", "/S", dosPath(reg.path)])
        }
        tool(wineBin.appendingPathComponent("wineserver"), ["-w"])
        guard fm.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) else { return false }
        fm.createFile(atPath: marker.path, contents: nil)
        return true
    }

    /// Font fallbacks to macOS system fonts (Chinese, Japanese, Korean, Thai, Indic scripts).
    private func fontLinkRegistry() -> String {
        let links = ["Hiragino Sans GB.ttc", "AppleSDGothicNeo.ttc", "Ayuthaya.ttf",
                     "Tamil Sangam MN.ttc", "Kohinoor.ttc", "Arial Unicode.ttf"]
        let data = Array((links.joined(separator: "\0") + "\0\0").utf16)
        let hex = data.flatMap { [UInt8($0 & 0xff), UInt8($0 >> 8)] }
            .map { String(format: "%02x", $0) }.joined(separator: ",")
        let faces = ["Tahoma", "Tahoma Bold", "Microsoft Sans Serif", "Segoe UI", "Arial", "Verdana",
                     "Lucida Sans Unicode", "Courier New", "Consolas"]
        var out = "Windows Registry Editor Version 5.00\r\n\r\n"
        out += "[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink]\r\n"
        for face in faces { out += "\"\(face)\"=hex(7):\(hex)\r\n" }
        return out
    }

    private func dosPath(_ path: String) -> String {
        "Z:" + path.replacingOccurrences(of: "/", with: "\\")
    }

    private func runFlowgorithm(_ document: URL?) {
        let p = Process()
        p.executableURL = engineExe   // symlink to the Wine loader inside the "engine" bundle
        p.arguments = [program.path] + (document.map { [dosPath($0.path)] } ?? [])
        p.environment = environment
        if let log = log { p.standardOutput = log; p.standardError = log }
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async { self?.childExited(proc) }
        }
        do {
            try p.run()
            children[p] = Date()
        } catch {
            fail()
        }
    }

    private func childExited(_ proc: Process) {
        let started = children.removeValue(forKey: proc) ?? Date()
        if proc.terminationStatus != 0 && Date().timeIntervalSince(started) < 5 && children.isEmpty {
            fail()
            return
        }
        if children.isEmpty { NSApp.terminate(nil) }
    }

    // MARK: user interface

    private func showSetupWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 110),
                         styleMask: [.titled], backing: .buffered, defer: false)
        w.title = "Flowgorithm"
        let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 39, width: 32, height: 32))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        let label = NSTextField(wrappingLabelWithString: tr(
            "Setting up Flowgorithm…\nThis happens only on first launch and takes a few seconds.",
            "Preparazione di Flowgorithm…\nSuccede solo al primo avvio e richiede qualche secondo."))
        label.frame = NSRect(x: 72, y: 30, width: 290, height: 50)
        w.contentView?.addSubview(spinner)
        w.contentView?.addSubview(label)
        w.center()
        setupWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func fail() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = tr("Flowgorithm could not start", "Flowgorithm non è riuscito ad avviarsi")
        alert.informativeText = tr("Details in the log: ", "Dettagli nel registro: ") + logURL.path
        alert.alertStyle = .warning
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let launcher = Launcher()
app.delegate = launcher
app.setActivationPolicy(.accessory)
app.run()
