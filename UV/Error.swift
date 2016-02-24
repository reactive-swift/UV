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

public struct Error : ErrorType {
    public let code:Int32
    
    init(code:Int32) {
        self.code = code
    }
}

public extension Error {
    public static func handle(@noescape fun:()->Int32) throws {
        let result = fun()
        if result < 0 {
            throw Error(code: result)
        }
    }
}

extension Error : Equatable {
}

public func ==(lhs: Error, rhs: Error) -> Bool {
    return lhs.code == rhs.code
}

public extension Error {
    public var name:String {
        get {
            return String.fromCString(uv_err_name(code))!
        }
    }
}

extension Error : CustomStringConvertible {
    public var description: String {
        get {
            return String.fromCString(uv_strerror(code))!
        }
    }
}
