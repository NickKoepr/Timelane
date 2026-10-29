import Foundation
import Testing
@testable import Timelane

struct ZipArchiveWriterTests {
    @Test func crcKnownVector() {
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(CRC32.checksum(Data()) == 0)
    }

    @Test func roundTrip() throws {
        let files: [(path: String, data: Data)] = [
            ("a.txt", Data("hello".utf8)), ("dir/é.bin", Data([0, 1, 2, 255])), ("empty", Data()),
        ]
        let archive = try ZipArchiveWriter.archive(of: files)
        let read = try ZipTestReader.read(archive)
        #expect(read.map(\.path) == files.map(\.path))
        #expect(read.map(\.data) == files.map(\.data))
    }

    @Test func isDeterministic() throws {
        let files: [(path: String, data: Data)] = [("a", Data("x".utf8))]
        #expect(try ZipArchiveWriter.archive(of: files) == ZipArchiveWriter.archive(of: files))
    }
}
