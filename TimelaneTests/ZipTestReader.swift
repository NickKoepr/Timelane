import Foundation

/// Test-only reader for stored ZIP archives (as written by `ZipArchiveWriter`).
enum ZipTestReader {
    struct Failure: Error {}

    static func read(_ data: Data) throws -> [(path: String, data: Data)] {
        let bytes = [UInt8](data)
        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        guard bytes.count >= 22, let eocd = (0...(bytes.count - 22)).reversed().first(where: { u32($0) == 0x0605_4B50 })
        else { throw Failure() }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)
        var result: [(String, Data)] = []
        for _ in 0..<count {
            guard u32(offset) == 0x0201_4B50, u16(offset + 10) == 0 else { throw Failure() }
            let size = u32(offset + 24)
            let nameLength = u16(offset + 28)
            let extra = u16(offset + 30) + u16(offset + 32)
            let local = u32(offset + 42)
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            result.append((name, Data(bytes[start..<(start + size)])))
            offset += 46 + nameLength + extra
        }
        return result
    }

    static func string(_ files: [(path: String, data: Data)], _ path: String) -> String? {
        files.first { $0.path == path }.map { String(decoding: $0.data, as: UTF8.self) }
    }
}
