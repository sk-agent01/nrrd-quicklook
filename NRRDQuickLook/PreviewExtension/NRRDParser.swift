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
}

enum NRRDError: Error {
    case invalidMagic
    case invalidHeader
    case unsupportedEncoding(String)
    case unsupportedType(String)
    case decompressionFailed
    case dataSizeMismatch
}

class NRRDParser {
    
    static func parse(url: URL) throws -> NRRDFile {
        let fileData = try Data(contentsOf: url)
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
            
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                header[key] = value
            }
        }
        
        // Get dimensions
        guard let sizesStr = header["sizes"] else {
            throw NRRDError.invalidHeader
        }
        let shape = sizesStr.split(separator: " ").compactMap { Int($0) }
        
        // Get data type
        let typeStr = header["type"] ?? "float"
        
        // Get encoding
        let encoding = header["encoding"] ?? "raw"
        
        // Decompress/decode data
        let rawData: Data
        switch encoding.lowercased() {
        case "raw":
            rawData = Data(bodyData)
        case "gzip", "gz":
            rawData = try decompressGzip(Data(bodyData))
        default:
            throw NRRDError.unsupportedEncoding(encoding)
        }
        
        // Convert to float array
        let floatData = try convertToFloat(rawData, type: typeStr, count: shape.reduce(1, *))
        
        return NRRDFile(header: header, data: floatData, shape: shape, type: typeStr)
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
    
    private static func decompressGzip(_ compressed: Data) throws -> Data {
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
        let deflateData = compressed.subdata(in: offset..<(compressed.count - 8))
        
        // Use Compression framework to decompress raw DEFLATE data
        let bufferSize = deflateData.count * 10  // Estimate
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
            throw NRRDError.decompressionFailed
        }
        
        return Data(destinationBuffer.prefix(decompressedSize))
    }
    
    private static func convertToFloat(_ data: Data, type: String, count: Int) throws -> [Float] {
        var result = [Float](repeating: 0, count: count)
        
        data.withUnsafeBytes { rawPtr in
            switch type.lowercased() {
            case "float", "float32":
                let floatPtr = rawPtr.bindMemory(to: Float.self)
                for i in 0..<min(count, floatPtr.count) {
                    result[i] = floatPtr[i]
                }
                
            case "double", "float64":
                let doublePtr = rawPtr.bindMemory(to: Double.self)
                for i in 0..<min(count, doublePtr.count) {
                    result[i] = Float(doublePtr[i])
                }
                
            case "uint8", "uchar", "unsigned char":
                let uint8Ptr = rawPtr.bindMemory(to: UInt8.self)
                for i in 0..<min(count, uint8Ptr.count) {
                    result[i] = Float(uint8Ptr[i])
                }
                
            case "int8", "char", "signed char":
                let int8Ptr = rawPtr.bindMemory(to: Int8.self)
                for i in 0..<min(count, int8Ptr.count) {
                    result[i] = Float(int8Ptr[i])
                }
                
            case "uint16", "ushort", "unsigned short":
                let uint16Ptr = rawPtr.bindMemory(to: UInt16.self)
                for i in 0..<min(count, uint16Ptr.count) {
                    result[i] = Float(uint16Ptr[i])
                }
                
            case "int16", "short", "signed short":
                let int16Ptr = rawPtr.bindMemory(to: Int16.self)
                for i in 0..<min(count, int16Ptr.count) {
                    result[i] = Float(int16Ptr[i])
                }
                
            case "uint32", "uint", "unsigned int":
                let uint32Ptr = rawPtr.bindMemory(to: UInt32.self)
                for i in 0..<min(count, uint32Ptr.count) {
                    result[i] = Float(uint32Ptr[i])
                }
                
            case "int32", "int", "signed int":
                let int32Ptr = rawPtr.bindMemory(to: Int32.self)
                for i in 0..<min(count, int32Ptr.count) {
                    result[i] = Float(int32Ptr[i])
                }
                
            default:
                // Try as uint8 fallback
                let uint8Ptr = rawPtr.bindMemory(to: UInt8.self)
                for i in 0..<min(count, uint8Ptr.count) {
                    result[i] = Float(uint8Ptr[i])
                }
            }
        }
        
        return result
    }
}
