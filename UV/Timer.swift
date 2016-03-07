//===--- Timer.swift -------------------------------------------------------===//
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

import CUV
import Boilerplate

public typealias uv_timer_p = UnsafeMutablePointer<uv_timer_t>

public typealias TimerCallback = (Timer) -> Void

public class Timer : Handle<uv_timer_p> {
    private let callback:TimerCallback
    
    public init(loop:Loop, callback:TimerCallback) throws {
        self.callback = callback
        try super.init { handle in
            uv_timer_init(loop.loop, handle)
        }
    }
    
    //uv_timer_start
    public func start(timeout:Timeout, repeatTimeout:Timeout? = nil) throws {
        try doWithHandle { handle in
            let repeatTimeout = repeatTimeout ?? .Immediate
            try Error.handle {
                uv_timer_start(handle, timer_cb, timeout.uvTimeout, repeatTimeout.uvTimeout)
            }
        }
    }
    
    //uv_timer_stop
    public func stop() throws {
        try doWithHandle { handle in
            try Error.handle {
                uv_timer_stop(handle)
            }
        }
    }
    
    //uv_timer_again
    public func again() throws {
        try doWithHandle { handle in
            try Error.handle {
                uv_timer_again(handle)
            }
        }
    }
    
    public var repeatTimeout:Timeout {
        //uv_timer_get_repeat
        get {
            return handle.isNil() ? .Immediate : Timeout(uvTimeout: uv_timer_get_repeat(handle))
        }
        //uv_timer_set_repeat
        set {
            if !handle.isNil() {
                uv_timer_set_repeat(handle, newValue.uvTimeout)
            }
        }
    }
    
}

private func timer_cb(handle:uv_timer_p) {
    let timer:Timer = Timer.fromHandle(handle)
    timer.callback(timer)
}

extension Timeout {
    init(uvTimeout:UInt64) {
        switch uvTimeout {
        case 0:
            self = .Immediate
        case UInt64.max:
            self = .Infinity
        default:
            self = .In(timeout: Double(uvTimeout) / 1000)
        }
    }
    
    var uvTimeout:UInt64 {
        get {
            switch self {
            case .Immediate:
                return 0
            case .Infinity:
                return UInt64.max
            case .In(let timeout):
                return UInt64(timeout * 1000)
            }
        }
    }
}
