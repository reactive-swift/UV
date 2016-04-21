//===--- Stream.swift -------------------------------------------------------===//
//Copyright (c) 2016 Daniel Leping (dileping)
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//===-----------------------------------------------------------------------===//

import Foundation
import Boilerplate
import Result

import CUV

public protocol uv_stream_type : uv_handle_type {
}

extension UnsafeMutablePointer : uv_stream_type {
}

public typealias uv_stream_p = UnsafeMutablePointer<uv_stream_t>

extension uv_shutdown_t : uv_request_type {
}

extension uv_write_t : uv_request_type {
}

public protocol SimpleCallbackCaller {
    associatedtype SimpleCallback = (Self)->Void
}

public protocol DataProtocol {
    var count:UInt32 {get}
    var len:UInt32 {get}
    var buffers:UnsafePointer<uv_buf_t> {get}
    var array:[UInt8] {get}
    
    func destroy()
}

private struct UVData : DataProtocol {
    let count:UInt32
    let len:UInt32
    let buffers:UnsafePointer<uv_buf_t>
    
    init(size:ssize_t, buffers:UnsafePointer<uv_buf_t>) {
        self.len = UInt32(size)
        var left:Int64 = Int64(size)
        var count = 0
        
        while left > 0 {
            left -= Int64(buffers.advancedBy(count).pointee.len)
            count += 1
        }
        
        self.count = UInt32(count)
        self.buffers = buffers
    }
    
    var array:[UInt8] {
        get {
            if count <= 0 {
                return []
            }
            
            let range = 0...Int(count-1)
            
            var currentElement = 0
            var result = Array<UInt8>(count: Int(self.len), repeatedValue: 0)
            
            for i in range {
                let bufp = buffers.advancedBy(i)
                let buf = bufp.pointee
                
                let len = min(buf.len, Int(self.len) - currentElement)
                let bp = UnsafeBufferPointer<UInt8>(start: UnsafePointer(buf.base), count: len)
                
                result.replaceRange(currentElement..<currentElement + len, with: bp)
                
                currentElement += buf.len
            }
            
            return result
        }
    }
    
    func destroy() {
        if count > 0 {
            for i in 0...Int(count-1) {
                let bufp = buffers.advancedBy(i)
                let buf = bufp.pointee
                
                buf.base.deallocateCapacity(buf.len)
            }
        }
    }
}

public class Data : DataProtocol {
    private let buffer:uv_buf_t
    private let data:[UInt8]
    
    public let buffers:UnsafePointer<uv_buf_t>
    public let count:UInt32 = 1
    public let len:UInt32
    
    public init(data:[UInt8]) {
        self.data = data
        self.len = UInt32(data.count)
        
        self.buffer = uv_buf_t(base: UnsafeMutablePointer(self.data), len: data.count)
        
        self.buffers = withUnsafePointer(&self.buffer) {p in p}
    }
    
    public var array:[UInt8] {
        return data
    }
    
    public func destroy() {
    }
}

public protocol ReadCallbackCaller {
    associatedtype ReadCallback = (Self, Result<DataProtocol, Error>)->Void
}

public class ShutdownRequest : Request<uv_shutdown_t> {
}

public class WriteRequest : Request<uv_write_t> {
}

internal protocol StreamProtocol : ReadCallbackCaller {
    func fresh(with loop:Loop, readCallback:Self.ReadCallback) throws -> Self
}

public class Stream<Type : uv_stream_type> : Handle<Type>, SimpleCallbackCaller, ReadCallbackCaller, StreamProtocol {
    private lazy var streamHandle:UnsafeMutablePointer<uv_stream_t> = self.getStreamHandle()
    
    private let connectionCallback:Stream.SimpleCallback
    private let readCallback:Stream.ReadCallback
    
    private func getStreamHandle() -> UnsafeMutablePointer<uv_stream_t> {
        return handle.cast()
    }
    
    func fresh(with loop:Loop, readCallback:ReadCallback) throws -> Self {
        CommonRuntimeError.NotImplemented(what: "static func fresh(with loop:Loop) -> Self").panic()
    }
    
    init(readCallback:Stream.ReadCallback, connectionCallback:Stream.SimpleCallback, _ initializer:(Type)->Int32) throws {
        self.connectionCallback = connectionCallback
        self.readCallback = readCallback
        try super.init(initializer)
    }
    
    public func shutdown(callback:ShutdownRequest.RequestCallback = {_,_ in}) {
        ShutdownRequest.perform(callback) { req in
            uv_shutdown(req, self.streamHandle, shutdown_cb)
        }
    }
    
    public func listen(backlog:Int32) throws {
        try ccall(Error.self) {
            uv_listen(streamHandle, backlog, connection_cb)
        }
    }
    
    public func accept(readCallback:ReadCallback = {_,_ in}) throws -> Self {
        let new = try self.fresh(with: loop!, readCallback: readCallback)
        try ccall(Error.self) {
            uv_accept(self.streamHandle, new.streamHandle)
        }
        
        return new
    }
    
    public func startReading() throws {
        try ccall(Error.self) {
            uv_read_start(self.streamHandle, alloc_cb, read_cb)
        }
    }
    
    public func stopReading() throws {
        try ccall(Error.self) {
            uv_read_stop(self.streamHandle)
        }
    }
    
    public func write(data:DataProtocol, callback:WriteRequest.RequestCallback) {
        WriteRequest.perform(callback) { preq in
            let buffers = data.buffers
            var new:[uv_buf_t] = []
            new.reserveCapacity(Int(data.count))
            
            var left:Int = Int(data.len)
            
            for i in 0..<Int(data.count) {
                var buff = buffers.advancedBy(i).pointee
                
                let len = buff.len
                
                if left < len {
                    buff.len = left
                }
                
                left -= len
                
                new.append(buff)
                
                if left < 0 {
                    break
                }
            }
            
            return uv_write(preq, self.streamHandle, UnsafePointer(new), UInt32(new.count), write_cb)
        }
    }
    
    public func tryWrite(data:DataProtocol) -> Int? {
        let written = Int(uv_try_write(streamHandle, data.buffers, data.count))
        return written > 0 ? written : nil
    }
}

func read_cb(stream:uv_stream_p, nread:ssize_t, bufp:UnsafePointer<uv_buf_t>) {
    //just skip it. No data. Optimization
    if nread == 0 {
        return
    }
    
    let e = Error.error(Int32(nread))
    let result:Result<DataProtocol, Error> = e.map { e in
        Result(error: e)
    }.getOrElse {
        let data = UVData(size: nread, buffers: bufp)
        return Result(data)
    }
    
    defer {
        //if there is deta - destroy it
        result.value?.destroy()
    }
    
    let stream = Stream<uv_stream_p>.fromHandle(stream)
    stream.readCallback(stream, result)
}

func alloc_cb(handle:uv_handle_p, suggestedSize:size_t, buf:UnsafeMutablePointer<uv_buf_t>) {
    buf.pointee.base = UnsafeMutablePointer(allocatingCapacity: suggestedSize)
    buf.pointee.len = suggestedSize
}

func write_cb(req:UnsafeMutablePointer<uv_write_t>, status:Int32) {
    req_cb(req, status: status)
}

func shutdown_cb(req:UnsafeMutablePointer<uv_shutdown_t>, status:Int32) {
    req_cb(req, status: status)
}

func connection_cb(server:uv_stream_p, status:Int32) {
    let handle:uv_handle_p = server.cast()
    let stream = Stream<uv_stream_p>.fromHandle(handle)
    stream.connectionCallback(stream)
}