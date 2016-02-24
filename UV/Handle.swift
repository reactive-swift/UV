//===--- Handle.swift ------------------------------------------------------===//
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

public typealias uv_handle_p = UnsafeMutablePointer<uv_handle_t>

protocol PropertyType {
    typealias Object
    typealias Type
    
    static func name() -> String
    
    static func getterValue() -> Type
    static func function() -> (Object, UnsafeMutablePointer<Type>) -> Int32
    
    static func read(object:Object) throws -> Type
    static func write(object:Object, value:Type) throws
}

extension PropertyType {
    static func read(object:Object) throws -> Type {
        return try Error.handle { code in
            var value:Type = getterValue()
            code = function()(object, &value)
            return value
        }
    }
    
    static func write(object:Object, value:Type) throws {
        var value:Type = value
        try Error.handle {
            function()(object, &value)
        }
    }
}

extension PropertyType {
    static func readNoThrow(object:Object) -> Type? {
        return try? read(object)
    }
    
    static func writeNoThrow(object:Object, value:Type?) {
        if let value = value {
            do {
                try write(object, value: value)
            } catch let e as Error {
                print(e.description)
            } catch {
                print("Unknown error occured while setting ", name())
            }
        }
    }
}

private protocol BufferPropertyType : PropertyType {
}

private extension BufferPropertyType where Type == Int32 {
    static func getterValue() -> Type {
        return 0
    }
}

private class SendBufferSizeProperty : BufferPropertyType {
    typealias Object = uv_handle_p
    typealias Type = Int32
    
    static func name() -> String {
        return "send buffer size"
    }
    
    static func function() -> (Object, UnsafeMutablePointer<Type>) -> Int32 {
        return uv_send_buffer_size
    }
}

private class RecvBufferSizeProperty : BufferPropertyType {
    typealias Object = uv_handle_p
    typealias Type = Int32
    
    static func name() -> String {
        return "recv buffer size"
    }
    
    static func function() -> (Object, UnsafeMutablePointer<Type>) -> Int32 {
        return uv_recv_buffer_size
    }
}

public class Handle {
    public let handle:uv_handle_p
    
    public init(handle:uv_handle_p) {
        self.handle = handle
    }
    
    public var active:Bool {
        get {
            return uv_is_active(handle) != 0
        }
    }
    
    public var closing:Bool {
        get {
            return uv_is_closing(handle) != 0
        }
    }
    
    //uv_close
    
    public func ref() {
        uv_ref(handle)
    }
    
    public func unref() {
        uv_unref(handle)
    }
    
    public var referenced:Bool {
        get {
            return uv_has_ref(handle) != 0
        }
    }
    
    //uv_handle_size
    
    //present, because properties can not throw. So both ways
    public func getSendBufferSize() throws -> Int32 {
        return try SendBufferSizeProperty.read(handle)
    }
    
    public func setSendBufferSize(size:Int32) throws {
        try SendBufferSizeProperty.write(handle, value: size)
    }
    
    public var sendBufferSize:Int32? {
        get {
            return SendBufferSizeProperty.readNoThrow(handle)
        }
        set {
            SendBufferSizeProperty.writeNoThrow(handle, value: newValue)
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getRecvBufferSize() throws -> Int32 {
        return try RecvBufferSizeProperty.read(handle)
    }
    
    public func setRecvBufferSize(size:Int32) throws {
        try RecvBufferSizeProperty.write(handle, value: size)
    }
    
    public var recvBufferSize:Int32? {
        get {
            return RecvBufferSizeProperty.readNoThrow(handle)
        }
        set {
            RecvBufferSizeProperty.writeNoThrow(handle, value: newValue)
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getFileno() throws -> uv_os_fd_t {
        return try Error.handle { code in
            var fileno = uv_os_fd_t()
            code = uv_fileno(handle, &fileno)
            return fileno
        }
    }
    
    public var fileno:uv_os_fd_t? {
        get {
            return try? getFileno()
        }
    }
    
    //uv_recv_buffer_size
}