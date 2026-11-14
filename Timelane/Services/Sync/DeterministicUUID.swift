import CryptoKit
import Foundation

/// A name-based UUID (version 5 layout, but with SHA-256): the same name always gives the same UUID,
/// so two devices that split the same entry create tails with identical identities.
enum DeterministicUUID {
    static func make(from name: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(name.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50     // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80     // RFC 4122 variant
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let chars = Array(hex)
        let parts = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(chars[$0]) }
        return UUID(uuidString: parts.joined(separator: "-"))!
    }
}
