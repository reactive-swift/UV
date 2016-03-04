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

public protocol uv_handle_type {
    func cast<T>() -> UnsafeMutablePointer<T>
    func cast<T>() -> UnsafePointer<T>
    
    func isNil() -> Bool
    func testNil() throws
    
    mutating func nullify()
}

extension UnsafeMutablePointer : uv_handle_type {
    public func cast<T>() -> UnsafeMutablePointer<T> {
        return UnsafeMutablePointer<T>(self)
    }
    
    public func cast<T>() -> UnsafePointer<T> {
        return UnsafePointer<T>(self)
    }
    
    public func isNil() -> Bool {
        return self == nil
    }
    
    public func testNil() throws {
        if isNil() {
            throw Error.HandleClosed
        }
    }
    
    public mutating func nullify() {
        self = nil
    }
}

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

public protocol HandleType {
    var baseHandle:uv_handle_p {get}
}

public class HandleBase {
    public lazy var baseHandle:uv_handle_p = self.getBaseHandle()
    
    func getBaseHandle() -> uv_handle_p {
        return nil
    }
    
    func clearHandle() {
        baseHandle.nullify()
    }
}

public class Handle<Type : uv_handle_type> : HandleBase {
    public var handle:Type
    
    override func getBaseHandle() -> uv_handle_p {
        return self.handle.cast()
    }
    
    override func clearHandle() {
        super.clearHandle()
        handle.nullify()
    }
    
    init(handle:Type, wrap:Bool) {
        self.handle = handle
        super.init()
        if !wrap {
            baseHandle.memory.data = UnsafeMutablePointer<Void>(Unmanaged.passRetained(self).toOpaque())
        }
    }
    
    private static func doWithHandle<Handle: uv_handle_type, Ret>(handle: Handle, fun:(Handle) throws -> Ret) throws -> Ret {
        try handle.testNil()
        return try fun(handle)
    }
    
    private func doWithBaseHandle<Ret>(fun:(uv_handle_p) throws -> Ret) throws -> Ret {
        return try Handle.doWithHandle(baseHandle, fun: fun)
    }
    
    func doWithHandle<Ret>(fun:(Type) throws -> Ret) throws -> Ret {
        return try Handle.doWithHandle(handle, fun: fun)
    }
    
    public var loop:Loop? {
        get {
            return try? doWithBaseHandle { handle in
                Loop(loop: handle.memory.loop)
            }
        }
    }
    
    public var active:Bool {
        get {
            return !baseHandle.isNil() && uv_is_active(baseHandle) != 0
        }
    }
    
    public var closing:Bool {
        get {
            return baseHandle.isNil() || uv_is_closing(baseHandle) != 0
        }
    }
    
    //uv_close
    public func close() {
        if !baseHandle.isNil() {
            uv_close(baseHandle, handle_close_cb)
        }
    }
    
    public func ref() throws {
        try doWithBaseHandle { _ in
            uv_ref(self.baseHandle)
        }
    }
    
    public func unref() throws {
        try doWithBaseHandle { _ in
            uv_unref(self.baseHandle)
        }
    }
    
    public var referenced:Bool {
        get {
            return !baseHandle.isNil() && uv_has_ref(baseHandle) != 0
        }
    }
    
    //uv_handle_size
    
    //present, because properties can not throw. So both ways
    public func getSendBufferSize() throws -> Int32 {
        return try doWithBaseHandle { handle in
            try SendBufferSizeProperty.read(handle)
        }
    }
    
    public func setSendBufferSize(size:Int32) throws {
        try doWithBaseHandle { handle in
            try SendBufferSizeProperty.write(handle, value: size)
        }
    }
    
    public var sendBufferSize:Int32? {
        get {
            return try? doWithBaseHandle { handle in
                return try SendBufferSizeProperty.read(handle)
            }
        }
        set {
            do {
                try doWithBaseHandle { handle in
                    SendBufferSizeProperty.writeNoThrow(handle, value: newValue)
                }
            } catch {
            }
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getRecvBufferSize() throws -> Int32 {
        return try doWithBaseHandle { handle in
            try RecvBufferSizeProperty.read(handle)
        }
    }
    
    public func setRecvBufferSize(size:Int32) throws {
        try doWithBaseHandle { handle in
            try RecvBufferSizeProperty.write(handle, value: size)
        }
    }
    
    public var recvBufferSize:Int32? {
        get {
            return try? doWithBaseHandle { handle in
                return try RecvBufferSizeProperty.read(handle)
            }
        }
        set {
            do {
                try doWithBaseHandle { handle in
                    RecvBufferSizeProperty.writeNoThrow(handle, value: newValue)
                }
            } catch {
            }
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getFileno() throws -> uv_os_fd_t {
        return try doWithBaseHandle { handle in
            try Error.handle { code in
                var fileno = uv_os_fd_t()
                code = uv_fileno(handle, &fileno)
                return fileno
            }
        }
    }
    
    public var fileno:uv_os_fd_t? {
        get {
            return try? getFileno()
        }
    }
}

extension Handle {
    //would prefer to use Self, but is not possible at the moment of writing
    class func fromHandle<T : Handle>(handle:uv_handle_type) -> T {
        let handle:uv_handle_p = handle.cast()
        return Unmanaged<T>.fromOpaque(COpaquePointer(handle.memory.data)).takeUnretainedValue()
    }
}

private func handle_close_cb(handle:uv_handle_p) {
    if handle.memory.data != nil {
        let object = Unmanaged<HandleBase>.fromOpaque(COpaquePointer(handle.memory.data)).takeRetainedValue()
        handle.memory.data = nil
        object.clearHandle()
    }
    
    handle.destroy(1)
    handle.dealloc(1)
}