import Foundation

/// Manages AWDL (Apple Wireless Direct Link) interface state
final class AWDLController {
    static let shared = AWDLController()

    private let scriptPath: String

    private init() {
        // Use the installed script location
        // The script should be copied to /usr/local/bin/ or referenced from the app bundle
        if let bundlePath = Bundle.main.path(forResource: "awdl-control", ofType: "sh") {
            scriptPath = bundlePath
        } else {
            // Fallback to installed location
            scriptPath = "/usr/local/bin/awdl-control"
        }
    }

    /// Check if AWDL interface is currently enabled (RUNNING)
    func isEnabled() -> Bool {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        task.arguments = ["awdl0"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("RUNNING")
            }
        } catch {
            print("Failed to check AWDL status: \(error)")
        }

        return false
    }

    /// Enable or disable AWDL interface
    func setEnabled(_ enabled: Bool) {
        let task = Process()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task.arguments = ["/sbin/ifconfig", "awdl0", enabled ? "up" : "down"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to set AWDL state: \(error)")
        }
    }

    /// Toggle AWDL state and return new state
    @discardableResult
    func toggle() -> Bool {
        let currentState = isEnabled()
        setEnabled(!currentState)
        return !currentState
    }
}
