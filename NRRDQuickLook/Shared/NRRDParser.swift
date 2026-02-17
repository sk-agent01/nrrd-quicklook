import Foundation
import Compression

/// NRRD file parser - reads header and decompresses data
struct NRRDFile {
    let header: [String: String]
    let data: [Float]
    let shape: [Int]  // dimensions
    let type: String
    
    var width: Int { shape.count >= 1 ? shape[0] : 0 }
    var height: Int { shape.count >= 2 ? shape[1] : 0 }
    var depth: Int { shape.count >= 3 ? shape[2] : 0 }
    
    /// For 4D data (e.g., multi-segment masks)
    var channels: Int { shape.count >= 4 ? shape[3] : 1 }
}

enum NRRDError: Error, LocalizedError {
    case invalidMagic
    case invalidHeader
    case missingSizes
    case unsupportedEncoding(String)
    case unsupportedType(String)
    case decompressionFailed(String)
    case dataSizeMismatch(expected: Int, got: Int)
    case fileReadError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMagic: return "Not a valid NRRD file (invalid magic)"
        case .invalidHeader: return "Could not parse NRRD header"
        case .missingSizes: return "Missing 'sizes' field in header"
        case .unsupportedEncoding(let enc): return "Unsupported encoding: \(enc)"
        case .unsupportedType(let t): return "Unsupported data type: \(t)"
        case .decompressionFailed(let msg): return "Decompression failed: \(msg)"
        case .dataSizeMismatch(let expected, let got): return "Data size mismatch: expected \(expected), got \(got)"
        case .fileReadError(let msg): return "File read error: \(msg)"
        }
    }
}

class NRRDParser {
    
    static func parse(url: URL) throws -> NRRDFile {
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw NRRDError.fileReadError(error.localizedDescription)
        }
        return try parse(data: fileData)
    }
    
    static func parse(data: Data) throws -> NRRDFile {
        // Find header/data separator (blank line)
        guard let separatorRange = findHeaderSeparator(in: data) else {
            throw NRRDError.invalidHeader
        }
        
        let headerData = data[..<separatorRange.lowerBound]
        let bodyData = data[separatorRange.upperBound...]
        
        // Parse header
        guard let headerString = String(data: headerData, encoding: .utf8) ?? String(data: headerData, encoding: .ascii) else {
            throw NRRDError.invalidHeader
        }
        
        let lines = headerString.components(separatedBy: .newlines)
        
        // Check magic
        guard let firstLine = lines.first,
              firstLine.hasPrefix("NRRD") else {
            throw NRRDError.invalidMagic
        }
        
        // Parse header fields
        var header: [String: String] = [:]
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Handle both "key: value" and "key:=value" formats
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                var valueStart = trimmed.index(after: colonIndex)
                // Skip "=" if present (for key:=value format)
                if valueStart < trimmed.endIndex && trimmed[valueStart] == "=" {
                    valueStart = trimmed.index(after: valueStart)
                }
                let value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)
                header[key] = value
            }
        }
        
        // Get dimensions
        guard let sizesStr = header["sizes"] else {
            throw NRRDError.missingSizes
        }
        let shape = sizesStr.split(separator: " ").compactMap { Int($0) }
        
        guard !shape.isEmpty else {
            throw NRRDError.missingSizes
        }
        
        // Get data type
        let typeStr = header["type"] ?? "float"
        
        // Get encoding
        let encoding = header["encoding"] ?? "raw"
        
        // Check endianness
        let endian = header["endian"]?.lowercased() ?? "little"
        let needsByteSwap = (endian == "big")
        
        // Decompress/decode data
        let rawData: Data
        switch encoding.lowercased() {
        case "raw":
            rawData = Data(bodyData)
        case "gzip", "gz":
            rawData = try decompressGzip(Data(bodyData), expectedSize: shape.reduce(1, *) * bytesPerElement(type: typeStr))
        default:
            throw NRRDError.unsupportedEncoding(encoding)
        }
        
        // Convert to float array
        let totalElements = shape.reduce(1, *)
        let floatData = try convertToFloat(rawData, type: typeStr, count: totalElements, bigEndian: needsByteSwap)
        
        return NRRDFile(header: header, data: floatData, shape: shape, type: typeStr)
    }
    
    private static func bytesPerElement(type: String) -> Int {
        switch type.lowercased() {
        case "uint8", "uchar", "unsigned char", "int8", "char", "signed char":
            return 1
        case "uint16", "ushort", "unsigned short", "int16", "short", "signed short":
            return 2
        case "uint32", "uint", "unsigned int", "int32", "int", "signed int", "float", "float32":
            return 4
        case "double", "float64", "uint64", "int64":
            return 8
        default:
            return 4
        }
    }
    
    private static func findHeaderSeparator(in data: Data) -> Range<Data.Index>? {
        // Look for \n\n or \r\n\r\n
        let newlineNewline = Data([0x0A, 0x0A])
        let crlfCrlf = Data([0x0D, 0x0A, 0x0D, 0x0A])
        
        if let range = data.range(of: crlfCrlf) {
            return range
        }
        if let range = data.range(of: newlineNewline) {
            return range
        }
        return nil
    }
    
    private static func decompressGzip(_ compressed: Data, expectedSize: Int) throws -> Data {
        // Skip gzip header if present (10 bytes minimum)
        var offset = 0
        if compressed.count > 10 && compressed[0] == 0x1f && compressed[1] == 0x8b {
            // Gzip magic bytes found, skip header
            let flags = compressed[3]
            offset = 10
            
            // Skip extra field if present
            if flags & 0x04 != 0 && offset + 2 <= compressed.count {
                let extraLen = Int(compressed[offset]) | (Int(compressed[offset + 1]) << 8)
                offset += 2 + extraLen
            }
            
            // Skip original filename if present
            if flags & 0x08 != 0 {
                while offset < compressed.count && compressed[offset] != 0 {
                    offset += 1
                }
                offset += 1 // skip null terminator
            }
            
            // Skip comment if present
            if flags & 0x10 != 0 {
                while offset < compressed.count && compressed[offset] != 0 {
                    offset += 1
                }
                offset += 1
            }
            
            // Skip header CRC if present
            if flags & 0x02 != 0 {
                offset += 2
            }
        }
        
        // Strip gzip trailer (8 bytes: CRC32 + original size)
        guard compressed.count > offset + 8 else {
            throw NRRDError.decompressionFailed("Compressed data too short")
        }
        
        let deflateData = compressed.subdata(in: offset..<(compressed.count - 8))
        
        // Read original size from trailer (last 4 bytes, little-endian)
        let trailerOffset = compressed.count - 4
        let originalSize = Int(compressed[trailerOffset]) |
                          (Int(compressed[trailerOffset + 1]) << 8) |
                          (Int(compressed[trailerOffset + 2]) << 16) |
                          (Int(compressed[trailerOffset + 3]) << 24)
        
        // Use the larger of expected size, original size from trailer, or compressed * 20
        let bufferSize = max(expectedSize, originalSize, deflateData.count * 20)
        var destinationBuffer = [UInt8](repeating: 0, count: bufferSize)
        
        let decompressedSize = deflateData.withUnsafeBytes { sourcePtr -> Int in
            let sourceBytes = sourcePtr.bindMemory(to: UInt8.self)
            return compression_decode_buffer(
                &destinationBuffer,
                bufferSize,
                sourceBytes.baseAddress!,
                deflateData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard decompressedSize > 0 else {
            throw NRRDError.decompressionFailed("compression_decode_buffer returned 0")
        }
        
        return Data(destinationBuffer.prefix(decompressedSize))
    }
    
    private static func convertToFloat(_ data: Data, type: String, count: Int, bigEndian: Bool) throws -> [Float] {
        var result = [Float](repeating: 0, count: count)
        
        data.withUnsafeBytes { rawPtr in
            switch type.lowercased() {
            case "float", "float32":
                let floatPtr = rawPtr.bindMemory(to: Float.self)
                let available = min(count, floatPtr.count)
                for i in 0..<available {
                    var value = floatPtr[i]
                    if bigEndian {
                        value = Float(bitPattern: value.bitPattern.bigEndian)
                    }
                    result[i] = value
                }
                
            case "double", "float64":
                let doublePtr = rawPtr.bindMemory(to: Double.self)
                let available = min(count, doublePtr.count)
                for i in 0..<available {
                    var value = doublePtr[i]
                    if bigEndian {
                        value = Double(bitPattern: value.bitPattern.bigEndian)
                    }
                    result[i] = Float(value)
                }
                
            case "uint8", "uchar", "unsigned char":
                let uint8Ptr = rawPtr.bindMemory(to: UInt8.self)
                let available = min(count, uint8Ptr.count)
                for i in 0..<available {
                    result[i] = Float(uint8Ptr[i])
                }
                
            case "int8", "char", "signed char":
                let int8Ptr = rawPtr.bindMemory(to: Int8.self)
                let available = min(count, int8Ptr.count)
                for i in 0..<available {
                    result[i] = Float(int8Ptr[i])
                }
                
            case "uint16", "ushort", "unsigned short":
                let uint16Ptr = rawPtr.bindMemory(to: UInt16.self)
                let available = min(count, uint16Ptr.count)
                for i in 0..<available {
                    var value = uint16Ptr[i]
                    if bigEndian { value = value.bigEndian }
                    result[i] = Float(value)
                }
                
            case "int16", "short", "signed short":
                let int16Ptr = rawPtr.bindMemory(to: Int16.self)
                let available = min(count, int16Ptr.count)
                for i in 0..<available {
                    var value = int16Ptr[i]
                    if bigEndian { value = value.bigEndian }
                    result[i] = Float(value)
                }
                
            case "uint32", "uint", "unsigned int":
                let uint32Ptr = rawPtr.bindMemory(to: UInt32.self)
                let available = min(count, uint32Ptr.count)
                for i in 0..<available {
                    var value = uint32Ptr[i]
                    if bigEndian { value = value.bigEndian }
                    result[i] = Float(value)
                }
                
            case "int32", "int", "signed int":
                let int32Ptr = rawPtr.bindMemory(to: Int32.self)
                let available = min(count, int32Ptr.count)
                for i in 0..<available {
                    var value = int32Ptr[i]
                    if bigEndian { value = value.bigEndian }
                    result[i] = Float(value)
                }
                
            default:
                // Try as uint8 fallback
                let uint8Ptr = rawPtr.bindMemory(to: UInt8.self)
                let available = min(count, uint8Ptr.count)
                for i in 0..<available {
                    result[i] = Float(uint8Ptr[i])
                }
            }
        }
        
        return result
    }
}
