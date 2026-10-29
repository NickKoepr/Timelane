import Foundation

/// Builds a ZIP archive in memory with stored (uncompressed) entries. No ZIP64. Deterministic output.
enum ZipArchiveWriter {
    enum ZipError: Error { case tooLarge }

    private static let dosTime: UInt16 = 0
    private static let dosDate: UInt16 = (0 << 9) | (1 << 5) | 1   // 1980-01-01

    static func archive(of files: [(path: String, data: Data)]) throws -> Data {
        var output = Data()
        var central = Data()
        for file in files {
            let name = Data(file.path.utf8)
            let crc = CRC32.checksum(file.data)
            guard file.data.count < Int(UInt32.max), output.count < Int(UInt32.max), files.count < Int(UInt16.max)
            else { throw ZipError.tooLarge }
            let offset = UInt32(output.count)
            let size = UInt32(file.data.count)

            output.appendLE(UInt32(0x0403_4B50))
            output.appendLE(UInt16(20)); output.appendLE(UInt16(0x0800)); output.appendLE(UInt16(0))
            output.appendLE(dosTime); output.appendLE(dosDate)
            output.appendLE(crc); output.appendLE(size); output.appendLE(size)
            output.appendLE(UInt16(name.count)); output.appendLE(UInt16(0))
            output.append(name); output.append(file.data)

            central.appendLE(UInt32(0x0201_4B50))
            central.appendLE(UInt16(20)); central.appendLE(UInt16(20))
            central.appendLE(UInt16(0x0800)); central.appendLE(UInt16(0))
            central.appendLE(dosTime); central.appendLE(dosDate)
            central.appendLE(crc); central.appendLE(size); central.appendLE(size)
            central.appendLE(UInt16(name.count))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0))   // extra, comment
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0))   // disk, internal attrs
            central.appendLE(UInt32(0)); central.appendLE(offset)
            central.append(name)
        }
        guard output.count + central.count < Int(UInt32.max) else { throw ZipError.tooLarge }
        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendLE(UInt32(0x0605_4B50))
        output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
        output.appendLE(UInt16(files.count)); output.appendLE(UInt16(files.count))
        output.appendLE(UInt32(central.count)); output.appendLE(centralOffset)
        output.appendLE(UInt16(0))
        return output
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
