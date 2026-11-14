import Foundation
#if os(iOS)
import UIKit
#endif

/// What kind of device the app runs on; used to word user-facing copy ("this Mac" / "this iPhone").
enum DeviceKind: Equatable, CaseIterable {
    case mac, iPhone, iPad

    /// "Mac", "iPhone" or "iPad".
    var noun: String {
        switch self {
        case .mac: "Mac"
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        }
    }

    /// "this Mac", "this iPhone", …
    var thisDevice: String { "this \(noun)" }

    /// Name of the system settings app, for "sign in to iCloud in …".
    var systemSettingsName: String { self == .mac ? "System Settings" : "Settings" }

    @MainActor static var current: DeviceKind {
        #if os(macOS)
        .mac
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
    }
}
