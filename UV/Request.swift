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

public protocol uv_request_type  {
}

internal extension uv_request_type {
    
    internal var request:Request<uv_req_t> {
        get {
            var this = self
            return withUnsafePointer(to: &this) { p in
                return p.withMemoryRebound(to:uv_req_t.self, capacity: 1){ pointer in
                    return Unmanaged<Request<uv_req_t>>.fromOpaque(pointer.pointee.data).takeUnretainedValue()
                }
            }
        }
    }
}

extension uv_req_t : uv_request_type {
}

public protocol RequestCallbackCaller {
    associatedtype RequestCallback = (Self, Error?)->Void
}

public class Request<Type: uv_request_type> : RequestCallbackCaller {
    public typealias RequestCallback = (Request, Error?)->Void
    
    internal let _req:UnsafeMutablePointer<Type>
    fileprivate let _baseReq:UnsafeMutablePointer<uv_req_t>
    
    fileprivate let _callback:RequestCallback
    
    internal init(_ callback:@escaping Request<Type>.RequestCallback) {
        self._req = UnsafeMutablePointer.allocate(capacity: 1)
        //UnsafePointer.withMemoryRebound(_req)

        self._baseReq = _req.withMemoryRebound(to: uv_req_t.self, capacity: 1){ pointer in pointer }
        self._callback = callback
    }
    
    deinit {
        _req.deinitialize(count: 1)
        _req.deallocate(capacity: 1)
    }
    
    internal var pointer:UnsafeMutablePointer<Type> {
        return _req
    }
    
    internal func bear() {
        _baseReq.pointee.data = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
    }
    
    internal func kill() {
        Unmanaged<Request<Type>>.fromOpaque(_baseReq).release()
    }
    
    fileprivate func call(result status:Int32) {
        _callback(self, Error.error(code: status))
    }
    
    open func cancel() throws {
        try ccall(Error.self) {
            uv_cancel(_baseReq)
        }
    }
    
    open static func perform(callback:@escaping RequestCallback, action:(UnsafeMutablePointer<Type>)->Int32) {
        let req = Request(callback)
        
        if let error = Error.error(code: action(req.pointer)) {
            callback(req, error)
            return
        }
        
        req.bear()
    }
}

internal func req_cb<Type: uv_request_type>(_ req:UnsafeMutablePointer<Type>?, status:Int32) {
    guard let req = req , req != .null else {
        return
    }
    
    let request = req.pointee.request
    defer {
        request.kill()
    }
    request.call(result: status)
}
