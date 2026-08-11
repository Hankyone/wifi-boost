import Foundation
import CoreMediaIO

/// Monitors camera usage across all processes on the system using CoreMediaIO.
/// No camera permission is required — this only queries device metadata, not the camera stream.
final class CameraMonitor {
    /// Called on the main queue when any physical camera starts or stops being used
    var onCameraStateChanged: ((Bool) -> Void)?

    private(set) var isCameraActive: Bool = false

    private var monitoredDevices: [CMIOObjectID] = []
    private var deviceListenerBlocks: [CMIOObjectID: CMIOObjectPropertyListenerBlock] = [:]
    private var systemListenerBlock: CMIOObjectPropertyListenerBlock?

    init() {}

    deinit {
        stopMonitoring()
    }

    /// Start monitoring camera state changes
    func startMonitoring() {
        addDeviceListListener()
        refreshDevices()
    }

    /// Stop monitoring and clean up all listeners
    func stopMonitoring() {
        removeAllDeviceListeners()
        removeDeviceListListener()
        isCameraActive = false
    }

    // MARK: - Device Enumeration

    private func getAllDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        var dataUsed: UInt32 = 0

        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, dataSize, &dataUsed, &devices
        ) == noErr else {
            return []
        }

        return devices
    }

    private func isPhysicalCamera(_ deviceID: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyTransportType),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        guard CMIOObjectHasProperty(deviceID, &address) else { return true }

        var transportType: UInt32 = 0
        let dataSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        var dataUsed: UInt32 = 0

        guard CMIOObjectGetPropertyData(
            deviceID, &address, 0, nil, dataSize, &dataUsed, &transportType
        ) == noErr else {
            return true
        }

        // Exclude virtual cameras (0x76697274 = 'virt')
        return transportType != 0x76697274
    }

    private func isDeviceRunning(_ deviceID: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        guard CMIOObjectHasProperty(deviceID, &address) else { return false }

        var isRunning: UInt32 = 0
        let dataSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        var dataUsed: UInt32 = 0

        guard CMIOObjectGetPropertyData(
            deviceID, &address, 0, nil, dataSize, &dataUsed, &isRunning
        ) == noErr else {
            return false
        }

        return isRunning != 0
    }

    // MARK: - Per-Device Listeners

    private func refreshDevices() {
        let allDevices = getAllDevices()
        let physicalDevices = allDevices.filter { isPhysicalCamera($0) }

        // Remove listeners for devices no longer present
        let removedDevices = monitoredDevices.filter { !physicalDevices.contains($0) }
        for deviceID in removedDevices {
            removeDeviceListener(for: deviceID)
        }

        // Add listeners for new devices
        let newDevices = physicalDevices.filter { !monitoredDevices.contains($0) }
        for deviceID in newDevices {
            addDeviceListener(for: deviceID)
        }

        monitoredDevices = physicalDevices
        updateCameraState()
    }

    private func addDeviceListener(for deviceID: CMIOObjectID) {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.updateCameraState()
        }

        deviceListenerBlocks[deviceID] = block
        CMIOObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
    }

    private func removeDeviceListener(for deviceID: CMIOObjectID) {
        guard let block = deviceListenerBlocks.removeValue(forKey: deviceID) else { return }

        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        CMIOObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
    }

    private func removeAllDeviceListeners() {
        for deviceID in monitoredDevices {
            removeDeviceListener(for: deviceID)
        }
        monitoredDevices.removeAll()
    }

    // MARK: - System Device List Listener (hot-plug support)

    private func addDeviceListListener() {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDevices()
        }

        systemListenerBlock = block
        CMIOObjectAddPropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject), &address, DispatchQueue.main, block
        )
    }

    private func removeDeviceListListener() {
        guard let block = systemListenerBlock else { return }

        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        CMIOObjectRemovePropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject), &address, DispatchQueue.main, block
        )
        systemListenerBlock = nil
    }

    // MARK: - State

    private func updateCameraState() {
        let anyRunning = monitoredDevices.contains { isDeviceRunning($0) }

        if anyRunning != isCameraActive {
            isCameraActive = anyRunning
            onCameraStateChanged?(anyRunning)
        }
    }
}
