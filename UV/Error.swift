//===--- Error.swift ------------------------------------------------------===//
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
//===----------------------------------------------------------------------===//

import CUV
import Boilerplate

//TODO: make enum
public enum Error : ErrorProtocol {
    case WithCode(code:Int32)
    case HandleClosed
}

public extension Error {
    public static func handle(@noescape fun:()->Int32) throws {
        let result = fun()
        if result < 0 {
            throw Error.WithCode(code: result)
        }
    }
    
    public static func handle<Value>(@noescape fun:(inout code:Int32)->Value) throws -> Value {
        var code:Int32 = 0
        let result = fun(code: &code)
        if code < 0 {
            throw Error.WithCode(code: code)
        }
        return result
    }
}

public extension Error {
    public var name:String {
        get {
            switch self {
            case .HandleClosed:
                return "HandleClosed"
            case .WithCode(let code):
                return String(cString: uv_err_name(code))
            }
        }
    }
}

extension Error : CustomStringConvertible {
    public var description: String {
        get {
            switch self {
            case .HandleClosed:
                return "The handle you are trying to is was already closed"
            case .WithCode(let code):
                return String(cString: uv_strerror(code))
            }
        }
    }
}
