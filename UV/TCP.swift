//===--- TCP.swift -------------------------------------------------------===//
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

public typealias uv_tcp_p = UnsafeMutablePointer<uv_tcp_t>

extension uv_connect_t : uv_request_type {
}

public class ConnectRequest : Request<uv_connect_t> {
}

public final class TCP : Stream<uv_tcp_p> {
    public init(loop:Loop, connectionCallback:TCP.SimpleCallback, readCallback:TCP.ReadCallback) throws {
        try super.init(readCallback: readCallback, connectionCallback: connectionCallback) { handle in
            uv_tcp_init(loop.loop, handle.portable)
        }
    }
    
    public convenience init(loop:Loop, readCallback:TCP.ReadCallback) throws {
        try self.init(loop: loop, connectionCallback: {_ in}, readCallback: readCallback)
    }
    
    public convenience init(loop:Loop, connectionCallback:TCP.SimpleCallback) throws {
        try self.init(loop: loop, connectionCallback: connectionCallback, readCallback: {_,_ in})
    }
    
    func fresh<A>(_ tcp:TCP) -> A {
        return tcp as! A
    }
    
    override func fresh(on loop:Loop, readCallback:ReadCallback) throws -> Self {
        return try fresh(TCP(loop: loop, readCallback: readCallback))
    }
    
    public func bind(to addr:UnsafePointer<sockaddr>, ipV6only:Bool = false) throws {
        let flags:UInt32 = ipV6only ? UV_TCP_IPV6ONLY.rawValue : 0
        try ccall(Error.self) {
            uv_tcp_bind(handle.portable, addr, flags)
        }
    }
    
    public func connect(to addr:UnsafePointer<sockaddr>, callback:ConnectRequest.RequestCallback = {_,_ in}) {
        ConnectRequest.perform(callback: callback) { req in
            uv_tcp_connect(req, self.handle.portable, addr, connect_cb)
        }
    }
}

#if swift(>=3.0)
    func connect_cb(req:UnsafeMutablePointer<uv_connect_t>?, status:Int32) {
        req_cb(req, status: status)
    }
#else
    func connect_cb(req:UnsafeMutablePointer<uv_connect_t>, status:Int32) {
        req_cb(req, status: status)
    }
#endif
