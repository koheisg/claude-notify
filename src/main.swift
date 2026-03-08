import Cocoa
import UserNotifications

func log(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    let path = "/tmp/claude-notify.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var signalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("app launched")
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            log("permission granted=\(granted)")
        }

        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in self?.sendNotification() }
        source.resume()
        signalSource = source
    }

    func sendNotification() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Claude Code"
        let msg = (try? String(contentsOfFile: "/tmp/claude-notify-message", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Done"
        content.body = msg
        content.sound = .default

        // Embed pane ID in notification so click handler uses the correct pane
        let paneId = (try? String(contentsOfFile: "/tmp/claude-notify-pane", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.userInfo = ["paneId": paneId]

        log("sending notification: \(msg) (pane=\(paneId))")

        // Use pane ID as identifier so same-pane notifications replace each other
        let notifId = paneId.isEmpty ? UUID().uuidString : "claude-\(paneId)"
        let request = UNNotificationRequest(
            identifier: notifId, content: content, trigger: nil
        )
        center.add(request) { error in
            if let error = error { log("error: \(error)") }
            else { log("notification sent OK") }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let paneId = response.notification.request.content.userInfo["paneId"] as? String ?? ""
        log("notification CLICKED (pane=\(paneId))")
        focusGhosttyPane(paneId: paneId)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func focusGhosttyPane(paneId: String) {
        log("focusGhosttyPane paneId='\(paneId)'")

        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", "tell application \"Ghostty\" to activate"]
        try? activate.run()
        activate.waitUntilExit()
        log("activated Ghostty via osascript (exit=\(activate.terminationStatus))")

        if !paneId.isEmpty {
            let tmux = "/opt/homebrew/bin/tmux"

            // Switch to the session containing the target pane
            let p0 = Process()
            p0.executableURL = URL(fileURLWithPath: tmux)
            p0.arguments = ["switch-client", "-t", paneId]
            try? p0.run()
            p0.waitUntilExit()

            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: tmux)
            p1.arguments = ["select-window", "-t", paneId]
            try? p1.run()
            p1.waitUntilExit()

            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: tmux)
            p2.arguments = ["select-pane", "-t", paneId]
            try? p2.run()
            p2.waitUntilExit()
            log("tmux switch+select done")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
