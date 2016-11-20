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
public enum Error1 : Error {
    case withCode(code:Int32)
    case handleClosed
}

extension Error1 : ErrorWithCodeType {
    public init(code:Int32) {
        self = .withCode(code: code)
    }
    
    public static func isError(_ code:Int32) -> Bool {
        return code < 0
    }
    
    public static func error(code:Int32) -> Error1? {
        return isError(code) ? Error1(code: code) : nil
    }
}

public extension Error1 {
    public var name:String {
        get {
            switch self {
            case .handleClosed:
                return "HandleClosed"
            case .withCode(let code):
                return String(cString: uv_err_name(code))
            }
        }
    }
}

extension Error1 : CustomStringConvertible {
    public var description: String {
        get {
            switch self {
            case .handleClosed:
                return "The handle you are trying to is was already closed"
            case .withCode(let code):
                return String(cString: uv_strerror(code))
            }
        }
    }
}
