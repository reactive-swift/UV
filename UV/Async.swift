//===--- Async.swift -------------------------------------------------------===//
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
import CUV

public typealias uv_async_p = UnsafeMutablePointer<uv_async_t>

public typealias AsyncCallback = (Async) -> Void

public class Async : Handle<uv_async_p> {
    private let callback:AsyncCallback
    
    public init(loop:Loop, callback:AsyncCallback) throws {
        self.callback = callback
        try super.init { handle in
            uv_async_init(loop.loop, handle, async_cb)
        }
    }
    
    /// uv_async_send
    /// the only thread safe function in this lib
    public func send() {
        if !handle.isNil() {
            uv_async_send(handle)
        }
    }
}

private func async_cb(handle:uv_async_p) {
    let async:Async = Async.fromHandle(handle)
    async.callback(async)
}