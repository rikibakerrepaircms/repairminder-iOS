// Features/Diagnostics/Engine/TestRegistry.swift
import Foundation

/// Single source of truth for the available test battery.
/// Hardware tests are appended in later tasks. DeviceInfoTest is the host-side seed.
enum TestRegistry {
    @MainActor static func allTests() -> [DiagnosticTest] {
        var t: [DiagnosticTest] = []
        t.append(DeviceInfoTest())
        // Screen
        t.append(TouchscreenTest())
        t.append(MultitouchTest())
        t.append(ThreeDTouchTest())
        t.append(DeadPixelTest())
        t.append(StylusTest())
        // Sensors
        t.append(AccelerometerTest())
        t.append(GyroscopeTest())
        t.append(MagneticTest())
        t.append(ProximityTest())
        t.append(LightSensorTest())
        t.append(GPSTest())
        // Hardware (part 1)
        t.append(StorageTest())
        t.append(BatteryTest())
        t.append(BatteryDrainTest())
        t.append(ChargeTest())
        t.append(HardwareButtonsTest())
        t.append(VibrationTest())
        // Hardware (cameras)
        t.append(RearCameraTest())
        t.append(FrontCameraTest())
        t.append(FlashTest())
        // Hardware (depth + biometric)
        t.append(TrueDepthTest())
        t.append(LiDARTest())
        t.append(BiometricTest())
        // Audio
        t.append(SpeakerTest())
        t.append(MicrophoneTest())
        t.append(HeadphonesTest())
        // Connectivity
        t.append(WiFiTest())
        t.append(BluetoothTest())
        t.append(NFCTest())
        t.append(CallTest())
        return t
    }
}
