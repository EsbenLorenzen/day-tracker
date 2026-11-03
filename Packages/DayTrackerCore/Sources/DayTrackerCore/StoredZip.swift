import Foundation

/// Minimal ZIP writer/reader using the "stored" method (no compression).
/// Enough for one export file that Windows, Python and iOS Files all open (D17).
public enum StoredZip {
    static let localHeaderSignature: UInt32 = 0x0403_4B50
    static let centralHeaderSignature: UInt32 = 0x0201_4B50
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    static let localHeaderSignatureBytes: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
    private static let utf8NamesFlag: UInt16 = 0x0800

    public static func archive(_ files: [(name: String, data: Data)], modified: Date) -> Data {
        let (dosTime, dosDate) = dosDateTime(modified)
        var output = Data()
        var central = Data()

        for file in files {
            let name = Data(file.name.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)
            let offset = UInt32(output.count)

            output.appendLE(localHeaderSignature)
            output.appendLE(UInt16(20))  // version needed
            output.appendLE(utf8NamesFlag)
            output.appendLE(UInt16(0))  // method: stored
            output.appendLE(dosTime)
            output.appendLE(dosDate)
            output.appendLE(crc)
            output.appendLE(size)
            output.appendLE(size)
            output.appendLE(UInt16(name.count))
            output.appendLE(UInt16(0))  // extra length
            output.append(name)
            output.append(file.data)

            central.appendLE(centralHeaderSignature)
            central.appendLE(UInt16(20))  // version made by
            central.appendLE(UInt16(20))  // version needed
            central.appendLE(utf8NamesFlag)
            central.appendLE(UInt16(0))
            central.appendLE(dosTime)
            central.appendLE(dosDate)
            central.appendLE(crc)
            central.appendLE(size)
            central.appendLE(size)
            central.appendLE(UInt16(name.count))
            central.appendLE(UInt16(0))  // extra
            central.appendLE(UInt16(0))  // comment
            central.appendLE(UInt16(0))  // disk
            central.appendLE(UInt16(0))  // internal attributes
            central.appendLE(UInt32(0))  // external attributes
            central.appendLE(offset)
            central.append(name)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendLE(endOfCentralDirectorySignature)
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(files.count))
        output.appendLE(UInt16(files.count))
        output.appendLE(UInt32(central.count))
        output.appendLE(centralOffset)
        output.appendLE(UInt16(0))  // comment length
        return output
    }

    /// Reads files from a stored (uncompressed) archive, by walking the local headers.
    public static func extract(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        var files: [String: Data] = [:]
        var position = 0

        while position + 30 <= bytes.count, bytes.readLE32(at: position) == localHeaderSignature {
            let flags = bytes.readLE16(at: position + 6)
            let method = bytes.readLE16(at: position + 8)
            let compressedSize = Int(bytes.readLE32(at: position + 18))
            let nameLength = Int(bytes.readLE16(at: position + 26))
            let extraLength = Int(bytes.readLE16(at: position + 28))
            guard method == 0, flags & 0x0008 == 0 else { throw BackupError.compressedArchive }

            let nameStart = position + 30
            let dataStart = nameStart + nameLength + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= bytes.count else { throw BackupError.invalidArchive }

            let name = String(decoding: bytes[nameStart..<nameStart + nameLength], as: UTF8.self)
            if !name.hasSuffix("/") {
                files[name] = Data(bytes[dataStart..<dataEnd])
            }
            position = dataEnd
        }
        guard !files.isEmpty else { throw BackupError.invalidArchive }
        return files
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((parts.year ?? 1980) - 1980, 0)
        let time = ((parts.hour ?? 0) << 11) | ((parts.minute ?? 0) << 5) | ((parts.second ?? 0) / 2)
        let day = (year << 9) | ((parts.month ?? 1) << 5) | (parts.day ?? 1)
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: day))
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendLE(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            append(UInt8((value >> UInt32(shift)) & 0xFF))
        }
    }
}

private extension Array where Element == UInt8 {
    func readLE16(at index: Int) -> UInt16 {
        UInt16(self[index]) | UInt16(self[index + 1]) << 8
    }

    func readLE32(at index: Int) -> UInt32 {
        UInt32(self[index]) | UInt32(self[index + 1]) << 8 | UInt32(self[index + 2]) << 16 | UInt32(self[index + 3]) << 24
    }
}
