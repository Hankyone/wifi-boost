import SwiftUI

struct ContentView: View {
    @State private var awdlEnabled = AWDLController.shared.isEnabled()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: awdlEnabled ? "wifi" : "wifi.slash")
                .font(.system(size: 64))
                .foregroundStyle(awdlEnabled ? .green : .secondary)

            Text("AWDL is \(awdlEnabled ? "Enabled" : "Disabled")")
                .font(.title2)

            Toggle("AWDL (AirDrop, Handoff, etc.)", isOn: $awdlEnabled)
                .toggleStyle(.switch)
                .onChange(of: awdlEnabled) { _, newValue in
                    AWDLController.shared.setEnabled(newValue)
                }

            Text("Disabling AWDL reduces Wi-Fi latency spikes but disables AirDrop, Handoff, Universal Clipboard, and Sidecar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Refresh Status") {
                awdlEnabled = AWDLController.shared.isEnabled()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(width: 320, height: 280)
        .onAppear {
            awdlEnabled = AWDLController.shared.isEnabled()
        }
    }
}

#Preview {
    ContentView()
}
