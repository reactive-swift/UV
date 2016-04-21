//===--- Request.swift -------------------------------------------------------===//
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

import CUV

public typealias uv_req_p = UnsafeMutablePointer<uv_req_t>
public typealias uv_any_req_p = UnsafeMutablePointer<uv_any_req>
public typealias uv_connect_p = UnsafeMutablePointer<uv_connect_t>
public typealias uv_fs_p = UnsafeMutablePointer<uv_fs_t>
public typealias uv_getaddrinfo_p = UnsafeMutablePointer<uv_getaddrinfo_t>
public typealias uv_getnameinfo_p = UnsafeMutablePointer<uv_getnameinfo_t>
public typealias uv_shutdown_p = UnsafeMutablePointer<uv_shutdown_t>
public typealias uv_udp_send_p = UnsafeMutablePointer<uv_udp_send_t>
public typealias uv_work_p = UnsafeMutablePointer<uv_work_t>
public typealias uv_write_p = UnsafeMutablePointer<uv_write_t>

public protocol uv_request_type {
}

internal extension uv_request_type {
    internal var request:Request<uv_req_t> {
        get {
            let req = unsafeBitCast(self, to: uv_req_t.self)
            return Unmanaged<Request<uv_req_t>>.fromOpaque(OpaquePointer(req.data)).takeUnretainedValue()
        }
    }
}

extension uv_req_t : uv_request_type {
}

public protocol RequestCallbackCaller {
    associatedtype RequestCallback = (Self, Int32)->Void
}

public class Request<Type: uv_request_type> : RequestCallbackCaller {
    internal let _req:UnsafeMutablePointer<Type>
    private let _baseReq:UnsafeMutablePointer<uv_req_t>
    
    private let _callback:Request<Type>.RequestCallback
    
    internal init(_ callback:Request<Type>.RequestCallback) {
        self._req = UnsafeMutablePointer(allocatingCapacity: 1)
        self._baseReq = UnsafeMutablePointer(_req)
        self._callback = callback
    }
    
    deinit {
        _req.deinitialize(count: 1)
        _req.deallocateCapacity(1)
    }
    
    internal var pointer:UnsafeMutablePointer<Type> {
        return _req
    }
    
    internal func alive() {
        _baseReq.pointee.data = UnsafeMutablePointer(OpaquePointer(bitPattern: Unmanaged.passRetained(self)))
    }
    
    internal func kill() {
        Unmanaged<Request<Type>>.fromOpaque(OpaquePointer(_baseReq.pointee.data)).release()
    }
    
    private func call(status:Int32) {
        _callback(self, status)
    }
    
    public func cancel() throws {
        try ccall(Error.self) {
            uv_cancel(_baseReq)
        }
    }
}

internal func req_cb<Type: uv_request_type>(req:UnsafeMutablePointer<Type>, status:Int32) {
    let request = req.pointee.request
    defer {
        request.kill()
    }
    request.call(status)
}