import Foundation

/// RepairMinder-chosen SF Symbol per diagnostic test id. Used by the selection + results grids.
enum DiagnosticIcons {
    static func symbol(for id: String) -> String {
        switch id {
        case "device_info": return "info.circle"
        case "touchscreen": return "hand.tap"
        case "multitouch": return "hand.point.up.left"
        case "touch3d": return "hand.tap.fill"
        case "color": return "circle.hexagongrid.fill"
        case "pen": return "applepencil"
        case "battery": return "battery.100"
        case "battery_drain": return "battery.25"
        case "charge": return "powerplug"
        case "hardwarebutton": return "switch.2"
        case "vibration": return "iphone.radiowaves.left.and.right"
        case "storage": return "internaldrive"
        case "rearcamera": return "camera"
        case "frontcamera": return "camera.rotate"
        case "flash": return "bolt.circle"
        case "truedepth": return "faceid"
        case "lidar": return "cube.transparent"
        case "biometric": return "touchid"
        case "speaker": return "speaker.wave.3"
        case "microphone": return "mic"
        case "headphones": return "headphones"
        case "wifi": return "wifi"
        case "bluetooth": return "antenna.radiowaves.left.and.right"
        case "nfc": return "wave.3.right.circle"
        case "call": return "phone"
        case "gps": return "location"
        case "accelerometer": return "move.3d"
        case "gyroscope": return "gyroscope"
        case "magnetic": return "location.north.circle"
        case "proximity": return "hand.raised"
        case "light": return "sun.max"
        default: return "checkmark.seal"
        }
    }
}
