//===--- Prepare.swift -------------------------------------------------------===//
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

public typealias uv_prepare_p = UnsafeMutablePointer<uv_prepare_t>

public typealias PrepareCallback = (Prepare) -> Void

public class Prepare : Handle<uv_prepare_p> {
    private let callback:PrepareCallback
    
    public init(loop:Loop, callback:PrepareCallback) throws {
        self.callback = callback
        try super.init { handle in
            uv_prepare_init(loop.loop, handle)
        }
    }
    
    public func start() throws {
        try doWithHandle { handle in
            try Error.handle {
                uv_prepare_start(handle, prepare_cb)
            }
        }
    }
    
    public func stop() throws {
        try doWithHandle { handle in
            try Error.handle {
                uv_prepare_stop(handle)
            }
        }
    }
}

private func prepare_cb(handle:uv_prepare_p) {
    let prepare:Prepare = Prepare.fromHandle(handle)
    prepare.callback(prepare)
}