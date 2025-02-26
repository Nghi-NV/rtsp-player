//
//  Socket.swift
//  RtspPlayer
//
//  Created by Nghi Nguyen on 26/2/25.
//
import Foundation

class Socket {
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    deinit {
        close()
    }
    
    func connect(toHost host: String, onPort port: Int32) throws {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)
        
        guard let readStreamUnwrapped = readStream?.takeRetainedValue(),
              let writeStreamUnwrapped = writeStream?.takeRetainedValue() else {
            throw NSError(domain: "Socket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create streams"])
        }
        
        inputStream = readStreamUnwrapped as InputStream
        outputStream = writeStreamUnwrapped as OutputStream
        
        inputStream?.schedule(in: .current, forMode: .default)
        outputStream?.schedule(in: .current, forMode: .default)
        
        inputStream?.open()
        outputStream?.open()
        
        // Check if streams are open
        guard inputStream?.streamStatus == .open, outputStream?.streamStatus == .open else {
            throw NSError(domain: "Socket", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open streams"])
        }
    }
    
    func write(from string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "Socket", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to data"])
        }
        
        try write(from: data)
    }
    
    func write(from data: Data) throws {
        guard let outputStream = outputStream else {
            throw NSError(domain: "Socket", code: 4, userInfo: [NSLocalizedDescriptionKey: "Output stream is nil"])
        }
        
        let bytesToWrite = data.count
        let buffer = [UInt8](data)
        
        var bytesWritten = 0
        while bytesWritten < bytesToWrite {
            let result = buffer.withUnsafeBufferPointer { (pointer: UnsafeBufferPointer<UInt8>) -> Int in
                outputStream.write(pointer.baseAddress!.advanced(by: bytesWritten), 
                                 maxLength: bytesToWrite - bytesWritten)
            }
            if result < 0 {
                if let error = outputStream.streamError {
                    throw error
                } else {
                    throw NSError(domain: "Socket", code: 5, userInfo: [NSLocalizedDescriptionKey: "Write error occurred"])
                }
            }
            bytesWritten += result
        }
    }
    
    func read(into buffer: inout Data) throws -> Int {
        guard let inputStream = inputStream else {
            throw NSError(domain: "Socket", code: 6, userInfo: [NSLocalizedDescriptionKey: "Input stream is nil"])
        }
        
        var tempBuffer = [UInt8](repeating: 0, count: buffer.count)
        let bytesRead = inputStream.read(&tempBuffer, maxLength: buffer.count)
        
        if bytesRead < 0 {
            if let error = inputStream.streamError {
                throw error
            } else {
                throw NSError(domain: "Socket", code: 7, userInfo: [NSLocalizedDescriptionKey: "Read error occurred"])
            }
        }
        
        if bytesRead > 0 {
            buffer = Data(tempBuffer.prefix(bytesRead))
        }
        
        return bytesRead
    }
    
    func readData(ofLength length: Int) throws -> Data {
        var buffer = Data(count: length)
        let bytesRead = try read(into: &buffer)
        return buffer.prefix(bytesRead)
    }
    
    func close() {
        inputStream?.close()
        outputStream?.close()
        
        inputStream?.remove(from: .current, forMode: .default)
        outputStream?.remove(from: .current, forMode: .default)
        
        inputStream = nil
        outputStream = nil
    }
}
