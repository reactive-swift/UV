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

public typealias uv_timer_p = UnsafeMutablePointer<uv_timer_t>

public typealias TimerCallback = (Timer) -> Void

public class Timer : Handle<uv_timer_p> {
    private let callback:TimerCallback
    
    public init(loop:Loop, callback:TimerCallback) throws {
        self.callback = callback
        super.init(handle: uv_timer_p.alloc(1), wrap: false)
        
        do {
            try Error.handle {
                uv_timer_init(loop.loop, self.handle)
            }
        } catch let e {
            //cleanum if not created
            handle.dealloc(1)
            handle.destroy(1)
            throw e
        }
    }
    
    //uv_timer_start
    public func start(timeout:UInt64, repeatTimeout:UInt64? = nil) throws {
        try doWithHandle { handle in
            let repeatTimeout:UInt64 = repeatTimeout ?? 0
            try Error.handle {
                uv_timer_start(handle, timer_cb, timeout, repeatTimeout)
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
    
    public var repeatTimeout:UInt64 {
        //uv_timer_get_repeat
        get {
            return handle.isNil() ? 0 : uv_timer_get_repeat(handle)
        }
        //uv_timer_set_repeat
        set {
            if !handle.isNil() {
                uv_timer_set_repeat(handle, newValue)
            }
        }
    }
    
}

private func timer_cb(handle:uv_timer_p) {
    let timer:Timer = Timer.fromHandle(handle)
    timer.callback(timer)
}
