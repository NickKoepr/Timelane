import Foundation
#if os(iOS)
import UIKit
#endif

/// The name shown for this device in backup metadata.
enum DeviceName {
    @MainActor static var current: String {
        #if os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        UIDevice.current.name
        #endif
    }
}
