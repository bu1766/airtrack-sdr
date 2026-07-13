import AppKit
import Foundation
import Network
import WebKit

struct SDRDevice: Codable {
    let id: String
    let type: String
    let name: String
    let serial: String?
}

final class DecoderManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.airtracksdr.decoder")
    private var process: Process?
    private var logHandle: FileHandle?
    private(set) var devices: [SDRDevice] = []
    private(set) var message = "Searching for SDR Devices…"
    private let dataDirectory: URL
    private let executableDirectory: URL
    private let pidFileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AirTrack SDR", isDirectory: true)
        dataDirectory = support.appendingPathComponent("data", isDirectory: true)
        executableDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        pidFileURL = support.appendingPathComponent("decoder.pid")
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        cleanupOrphanedDecoder()
    }

    var isRunning: Bool { queue.sync { process?.isRunning == true } }
    var dataURL: URL { dataDirectory }

    func refreshDevices() -> [SDRDevice] {
        var found: [SDRDevice] = []
        let rtlOutput = runProbe(executable: "rtl_test", arguments: ["-t"])
        let pattern = #"(?m)^\s*(\d+):\s+(.+?),\s+SN:\s*(\S+)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(rtlOutput.startIndex..<rtlOutput.endIndex, in: rtlOutput)
            for match in regex.matches(in: rtlOutput, range: range) {
                guard
                    let indexRange = Range(match.range(at: 1), in: rtlOutput),
                    let nameRange = Range(match.range(at: 2), in: rtlOutput),
                    let serialRange = Range(match.range(at: 3), in: rtlOutput)
                else { continue }
                let index = String(rtlOutput[indexRange])
                let name = String(rtlOutput[nameRange]).trimmingCharacters(in: .whitespaces)
                let serial = String(rtlOutput[serialRange])
                found.append(SDRDevice(id: "rtlsdr:\(serial)", type: "rtlsdr", name: name, serial: serial.isEmpty ? index : serial))
            }
        }

        let bladeOutput = runProbe(executable: "bladeRF-cli", arguments: ["-p"])
        let bladeLines = bladeOutput.components(separatedBy: .newlines)
            .filter { $0.localizedCaseInsensitiveContains("Serial") || $0.localizedCaseInsensitiveContains("bladeRF") }
        if !bladeLines.isEmpty && !bladeOutput.localizedCaseInsensitiveContains("No devices are available") {
            found.append(SDRDevice(id: "bladerf:0", type: "bladerf", name: "Nuand bladeRF", serial: nil))
        }

        queue.sync {
            devices = found
            if process?.isRunning != true {
                message = found.isEmpty ? "No Supported SDR Device Found" : "\(found.count) SDR Device\(found.count == 1 ? "" : "s") Ready"
            }
        }
        return found
    }

    func start(deviceID: String?) -> (Bool, String) {
        stop()
        let available = refreshDevices()
        guard !available.isEmpty else { return (false, "No Supported SDR Device Found") }
        let device = available.first(where: { $0.id == deviceID }) ?? available[0]
        let decoder = executableDirectory.appendingPathComponent("dump1090")
        guard FileManager.default.isExecutableFile(atPath: decoder.path) else {
            return (false, "Decoder Is Missing")
        }

        for name in ["aircraft.json", "receiver.json", "stats.json"] {
            try? FileManager.default.removeItem(at: dataDirectory.appendingPathComponent(name))
        }

        let task = Process()
        task.executableURL = decoder
        var args = ["--device-type", device.type]
        if device.type == "rtlsdr", let serial = device.serial { args += ["--device", serial] }
        if device.type == "bladerf", device.id != "bladerf:0" { args += ["--device", String(device.id.dropFirst("bladerf:".count))] }
        args += [
            "--gain", "38", "--adaptive-burst", "--fix",
            "--write-json", dataDirectory.path, "--write-json-every", "1",
            "--metric", "--quiet"
        ]
        task.arguments = args

        let support = dataDirectory.deletingLastPathComponent()
        let logURL = support.appendingPathComponent("decoder.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        logHandle = try? FileHandle(forWritingTo: logURL)
        task.standardOutput = logHandle
        task.standardError = logHandle
        task.terminationHandler = { [weak self] process in
            guard let self else { return }
            self.queue.async {
                if self.process === process {
                    self.process = nil
                    self.message = process.terminationStatus == 0 ? "SDR Disconnected" : "Unable to Open SDR — It May Be in Use"
                }
            }
        }

        do {
            try task.run()
            queue.sync {
                process = task
                message = "\(device.name) Connected"
            }
            try? String(task.processIdentifier).write(to: pidFileURL, atomically: true, encoding: .utf8)
            Thread.sleep(forTimeInterval: 0.35)
            if !task.isRunning {
                return (false, "Unable to Open SDR — It May Be in Use")
            }
            return (true, "\(device.name) Connected")
        } catch {
            queue.sync { message = "Unable to Start Decoder" }
            return (false, "Unable to Start Decoder")
        }
    }

    func stop() {
        let task: Process? = queue.sync {
            let current = process
            process = nil
            return current
        }
        if let task, task.isRunning {
            task.interrupt()
            let deadline = Date().addingTimeInterval(2)
            while task.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if task.isRunning { task.terminate() }
        }
        queue.sync { message = devices.isEmpty ? "No Supported SDR Device Found" : "SDR Disconnected" }
        try? FileManager.default.removeItem(at: pidFileURL)
        try? logHandle?.close()
        logHandle = nil
    }

    func statusPayload() -> [String: Any] {
        queue.sync {
            ["connected": process?.isRunning == true, "message": message, "devices": devices.map(dictionary)]
        }
    }

    private func dictionary(_ device: SDRDevice) -> [String: Any] {
        var value: [String: Any] = ["id": device.id, "type": device.type, "name": device.name]
        if let serial = device.serial { value["serial"] = serial }
        return value
    }

    private func runProbe(executable: String, arguments: [String]) -> String {
        let url = executableDirectory.appendingPathComponent(executable)
        guard FileManager.default.isExecutableFile(atPath: url.path) else { return "" }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = url
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch { return "" }
    }

    private func cleanupOrphanedDecoder() {
        guard let rawPID = try? String(contentsOf: pidFileURL, encoding: .utf8),
              let pid = Int32(rawPID.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1 else {
            try? FileManager.default.removeItem(at: pidFileURL)
            return
        }
        let ps = Process()
        let pipe = Pipe()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-p", String(pid), "-o", "command="]
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        try? ps.run()
        ps.waitUntilExit()
        let command = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if command.contains("AirTrack SDR.app/Contents/MacOS/dump1090") && command.contains(dataDirectory.path) {
            Darwin.kill(pid, SIGINT)
            Thread.sleep(forTimeInterval: 0.25)
            if Darwin.kill(pid, 0) == 0 { Darwin.kill(pid, SIGTERM) }
        }
        try? FileManager.default.removeItem(at: pidFileURL)
    }
}

final class HTTPServer: @unchecked Sendable {
    private let decoder: DecoderManager
    private let webRoot: URL
    private let queue = DispatchQueue(label: "app.airtracksdr.http", qos: .userInitiated)
    private var listener: NWListener?
    private(set) var port: UInt16 = 0

    init(decoder: DecoderManager) {
        self.decoder = decoder
        self.webRoot = Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true)
    }

    func start(completion: @escaping @Sendable (URL) -> Void) throws {
        let chosenPort = Self.availablePort()
        port = chosenPort
        let nwPort = NWEndpoint.Port(rawValue: chosenPort)!
        let listener = try NWListener(using: .tcp, on: nwPort)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                completion(URL(string: "http://127.0.0.1:\(chosenPort)/")!)
            }
        }
        listener.start(queue: queue)
    }

    func stop() { listener?.cancel() }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, data: Data())
    }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] chunk, _, complete, error in
            guard let self else { return }
            var buffer = data
            if let chunk { buffer.append(chunk) }
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerText = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) ?? ""
                let contentLength = headerText.components(separatedBy: "\r\n")
                    .first(where: { $0.lowercased().hasPrefix("content-length:") })
                    .flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                let bodyStart = headerEnd.upperBound
                if buffer.count >= bodyStart + contentLength {
                    self.route(connection, request: buffer)
                    return
                }
            }
            if complete || error != nil { connection.cancel(); return }
            self.receive(connection, data: buffer)
        }
    }

    private func route(_ connection: NWConnection, request: Data) {
        guard let requestText = String(data: request, encoding: .utf8),
              let firstLine = requestText.components(separatedBy: "\r\n").first else {
            send(connection, status: 400, type: "application/json", body: json(["error": "Bad Request"]))
            return
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { connection.cancel(); return }
        let method = String(parts[0])
        let rawPath = String(parts[1])
        let path = rawPath.removingPercentEncoding?.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        let headers = Dictionary(uniqueKeysWithValues: requestText.components(separatedBy: "\r\n").dropFirst().compactMap { line -> (String, String)? in
            let pieces = line.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { return nil }
            return (pieces[0].lowercased(), pieces[1].trimmingCharacters(in: .whitespaces))
        })
        let body = request.range(of: Data("\r\n\r\n".utf8)).map { Data(request[$0.upperBound...]) } ?? Data()

        if path == "/api/receiver/status" {
            send(connection, status: 200, type: "application/json", body: json(decoder.statusPayload()))
        } else if path == "/api/receiver/devices" {
            let devices = decoder.refreshDevices()
            send(connection, status: 200, type: "application/json", body: json(["devices": devices.map { ["id": $0.id, "type": $0.type, "name": $0.name, "serial": $0.serial ?? ""] }]))
        } else if path == "/api/receiver/start" && method == "POST" {
            guard headers["x-adsb-control"] == "1" else {
                send(connection, status: 403, type: "application/json", body: json(["error": "Control Header Required"])); return
            }
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            let result = decoder.start(deviceID: object?["device"] as? String)
            send(connection, status: result.0 ? 200 : 409, type: "application/json", body: json(decoder.statusPayload()))
        } else if path == "/api/receiver/stop" && method == "POST" {
            guard headers["x-adsb-control"] == "1" else {
                send(connection, status: 403, type: "application/json", body: json(["error": "Control Header Required"])); return
            }
            decoder.stop()
            send(connection, status: 200, type: "application/json", body: json(decoder.statusPayload()))
        } else if path == "/api/routes" && method == "POST" {
            proxyRoutes(connection, body: body)
        } else {
            serveFile(connection, path: path)
        }
    }

    private func proxyRoutes(_ connection: NWConnection, body: Data) {
        var request = URLRequest(url: URL(string: "https://adsb.im/api/0/routeset")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 502
            self.send(connection, status: code, type: "application/json", body: data ?? Data("[]".utf8))
        }.resume()
    }

    private func serveFile(_ connection: NWConnection, path: String) {
        let relative = path == "/" ? "index.html" : String(path.dropFirst())
        guard !relative.contains("..") else {
            send(connection, status: 403, type: "text/plain", body: Data("Forbidden".utf8)); return
        }
        let fileURL = relative.hasPrefix("data/")
            ? decoder.dataURL.appendingPathComponent(String(relative.dropFirst(5)))
            : webRoot.appendingPathComponent(relative)
        guard let data = try? Data(contentsOf: fileURL) else {
            send(connection, status: 404, type: "application/json", body: relative.hasPrefix("data/") ? json(["now": Date().timeIntervalSince1970, "messages": 0, "aircraft": []]) : Data("Not Found".utf8))
            return
        }
        let gzip = data.count > 2 && data[0] == 0x1f && data[1] == 0x8b
        send(connection, status: 200, type: mimeType(fileURL.pathExtension), body: data, gzip: gzip)
    }

    private func send(_ connection: NWConnection, status: Int, type: String, body: Data, gzip: Bool = false) {
        let reason = [200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 409: "Conflict", 502: "Bad Gateway"][status] ?? "Error"
        var headers = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-cache\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n"
        if gzip { headers += "Content-Encoding: gzip\r\n" }
        headers += "\r\n"
        connection.send(content: Data(headers.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    private func mimeType(_ ext: String) -> String {
        ["html": "text/html; charset=utf-8", "js": "application/javascript", "css": "text/css", "json": "application/json", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "svg": "image/svg+xml", "woff": "font/woff", "woff2": "font/woff2", "geojson": "application/geo+json"][ext.lowercased()] ?? "application/octet-stream"
    }

    private static func availablePort() -> UInt16 {
        for candidate in UInt16(8090)...UInt16(8190) {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = candidate.bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            close(fd)
            if result == 0 { return candidate }
        }
        return 8191
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private let decoder = DecoderManager()
    private var server: HTTPServer!
    private var window: NSWindow!
    private var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AirTrack SDR"
        window.minSize = NSSize(width: 980, height: 640)
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installMenu()

        server = HTTPServer(decoder: decoder)
        do {
            try server.start { [weak self] url in
                DispatchQueue.main.async {
                    self?.webView.load(URLRequest(url: url))
                    let devices = self?.decoder.refreshDevices() ?? []
                    if devices.count == 1 { _ = self?.decoder.start(deviceID: devices[0].id) }
                }
            }
        } catch {
            presentError(title: "Unable to Start AirTrack SDR", message: error.localizedDescription)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        decoder.stop()
        server?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           url.host != "127.0.0.1" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About AirTrack SDR", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit AirTrack SDR", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
