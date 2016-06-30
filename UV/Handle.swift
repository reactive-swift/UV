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

import Boilerplate

import CUV

public protocol uv_handle_type {
    func cast<T>() -> UnsafeMutablePointer<T>
    func cast<T>() -> UnsafePointer<T>
    
    var isNil:Bool {get}
    func testNil() throws
    
#if swift(>=3.0)
#else
    mutating func nullify()
#endif
    static func alloc() -> Self
    mutating func dealloc()
}

extension UnsafeMutablePointer : uv_handle_type {
    public func cast<T>() -> UnsafeMutablePointer<T> {
        return UnsafeMutablePointer<T>(self)
    }
    
    public func cast<T>() -> UnsafePointer<T> {
        return UnsafePointer<T>(self)
    }
    
    public var isNil:Bool {
        return self == .null
    }
    
    public func testNil() throws {
        if isNil {
            throw Error.HandleClosed
        }
    }
    
#if swift(>=3.0)
#else
    public mutating func nullify() {
        self = nil
    }
#endif
    
    public static func alloc() -> UnsafeMutablePointer {
        return UnsafeMutablePointer(allocatingCapacity: 1)
    }
    
    mutating public func dealloc() {
        self.deinitialize(count: 1)
        self.deallocateCapacity(1)
    }
}

#if swift(>=3.0)
    extension Optional where Wrapped : uv_handle_type {
        public mutating func nullify() {
            self = nil
        }
        
        public var isNil:Bool {
            return self?.isNil ?? true
        }
        
        public func testNil() throws {
            if isNil {
                throw Error.HandleClosed
            }
        }
    
        public var portable:Wrapped? {
            return self
        }
    }
#else
    extension Optional where Wrapped : uv_handle_type {
        public mutating func nullify() {
            self?.nullify()
            self = nil
        }
    
        public var isNil:Bool {
            return self.map({$0.isNil}).getOr(else: true)
        }
    
        public func testNil() throws {
            if isNil {
                throw Error.HandleClosed
            }
        }
    
        public var portable:Wrapped {
            return self!
        }
    }
#endif

public typealias uv_handle_p = UnsafeMutablePointer<uv_handle_t>

protocol PropertyType {
    associatedtype Object
    associatedtype `Type`
    
    static var name: String {get}
    
    static var getterValue:`Type` {get}
    static var function:(Object, UnsafeMutablePointer<`Type`>) -> Int32 {get}
    
    static func read(from object:Object) throws -> `Type`
    static func write(to object:Object, value:`Type`) throws
}

extension PropertyType {
    static func read(from object:Object) throws -> Type {
        return try ccall(Error.self) { code in
            var value:Type = getterValue
            code = function(object, &value)
            return value
        }
    }
    
    static func write(to object:Object, value:Type) throws {
        var value:Type = value
        try ccall(Error.self) {
            function(object, &value)
        }
    }
}

extension PropertyType {
    static func readNoThrow(from object:Object) -> Type? {
        return try? read(from: object)
    }
    
    static func writeNoThrow(to object:Object, value:Type?) {
        if let value = value {
            do {
                try write(to: object, value: value)
            } catch let e as Error {
                print(e.description)
            } catch {
                print("Unknown error occured while setting ", name)
            }
        }
    }
}

private protocol BufferPropertyType : PropertyType {
}

private extension BufferPropertyType where Type == Int32 {
    static var getterValue:Type {
        return 0
    }
}

private class SendBufferSizeProperty : BufferPropertyType {
    typealias Object = uv_handle_p
    typealias `Type` = Int32
    
    static var name: String {
        return "send buffer size"
    }
    
    static var function:(Object, UnsafeMutablePointer<Type>) -> Int32 {
        return uv_send_buffer_size
    }
}

private class RecvBufferSizeProperty : BufferPropertyType {
    typealias Object = uv_handle_p
    typealias `Type` = Int32
    
    static var name: String {
        return "recv buffer size"
    }
    
    static var function:(Object, UnsafeMutablePointer<Type>) -> Int32 {
        return uv_recv_buffer_size
    }
}

public protocol HandleType : AnyObject {
    var baseHandle:uv_handle_p? {get}
    
    var loop:Loop? {get}
    var active:Bool {get}
    var closing:Bool {get}
    
    func close()
    func ref() throws
    func unref() throws
    
    var referenced:Bool {get}
    
    //present, because properties can not throw. So both ways
    func getSendBufferSize() throws -> Int32
    func setSendBufferSize(size:Int32) throws
    
    var sendBufferSize:Int32? {get set}
    
    //present, because properties can not throw. So both ways
    func getRecvBufferSize() throws -> Int32
    func setRecvBufferSize(size:Int32) throws
    
    var recvBufferSize:Int32? {get set}
    
    //present, because properties can not throw. So both ways
    func getFileno() throws -> uv_os_fd_t
    var fileno:uv_os_fd_t? {get}
}

public class HandleBase {
    private var _baseHandle:uv_handle_p?
    
    public var baseHandle:uv_handle_p? {
        get {
            if _baseHandle == .null {
                _baseHandle = getBaseHandle()
            }
            return _baseHandle
        }
        set {
            _baseHandle = newValue
        }
    }
    
    func getBaseHandle() -> uv_handle_p? {
        return nil
    }
    
    func clearHandle() {
        baseHandle.nullify()
    }
}

public class Handle<Type : uv_handle_type> : HandleBase, HandleType {
    public var handle:Type?
    
    override func getBaseHandle() -> uv_handle_p? {
        return self.handle.map({$0.cast()})
    }
    
    override func clearHandle() {
        super.clearHandle()
        handle.nullify()
    }
    
    init(_ initializer:(Type?)->Int32) throws {
        self.handle = Type.alloc()
        super.init()
        
        do {
            try ccall(Error.self) {
                initializer(self.handle)
            }
            baseHandle?.pointee.data = UnsafeMutablePointer<Void>(OpaquePointer(bitPattern: Unmanaged.passRetained(self)))
        } catch let e {
            //cleanum if not created
            handle?.dealloc()
            throw e
        }
    }
    
    private static func doWith<Handle: uv_handle_type, Ret>(handle handle: Handle?, fun:(Handle) throws -> Ret) throws -> Ret {
        try handle.testNil()
        return try fun(handle!)
    }
    
    private func doWithBaseHandle<Ret>(fun:(uv_handle_p) throws -> Ret) throws -> Ret {
        return try Handle.doWith(handle: baseHandle, fun: fun)
    }
    
    func doWithHandle<Ret>(fun:(Type) throws -> Ret) throws -> Ret {
        return try Handle.doWith(handle: handle, fun: fun)
    }
    
    public var loop:Loop? {
        get {
            return try? doWithBaseHandle { handle in
                Loop(loop: handle.pointee.loop)
            }
        }
    }
    
    public var active:Bool {
        get {
            return !baseHandle.isNil && uv_is_active(baseHandle!) != 0
        }
    }
    
    public var closing:Bool {
        get {
            return baseHandle.isNil || uv_is_closing(baseHandle!) != 0
        }
    }
    
    //uv_close
    public func close() {
        if !baseHandle.isNil {
            uv_close(baseHandle!, handle_close_cb)
        }
    }
    
    public func ref() throws {
        try doWithBaseHandle { _ in
            uv_ref(self.baseHandle.portable)
        }
    }
    
    public func unref() throws {
        try doWithBaseHandle { _ in
            uv_unref(self.baseHandle.portable)
        }
    }
    
    public var referenced:Bool {
        get {
            return !baseHandle.isNil && uv_has_ref(baseHandle.portable) != 0
        }
    }
    
    //uv_handle_size
    
    //present, because properties can not throw. So both ways
    public func getSendBufferSize() throws -> Int32 {
        return try doWithBaseHandle { handle in
            try SendBufferSizeProperty.read(from: handle)
        }
    }
    
    public func setSendBufferSize(size:Int32) throws {
        try doWithBaseHandle { handle in
            try SendBufferSizeProperty.write(to: handle, value: size)
        }
    }
    
    public var sendBufferSize:Int32? {
        get {
            return try? doWithBaseHandle { handle in
                return try SendBufferSizeProperty.read(from: handle)
            }
        }
        set {
            do {
                try doWithBaseHandle { handle in
                    SendBufferSizeProperty.writeNoThrow(to: handle, value: newValue)
                }
            } catch {
            }
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getRecvBufferSize() throws -> Int32 {
        return try doWithBaseHandle { handle in
            try RecvBufferSizeProperty.read(from: handle)
        }
    }
    
    public func setRecvBufferSize(size:Int32) throws {
        try doWithBaseHandle { handle in
            try RecvBufferSizeProperty.write(to: handle, value: size)
        }
    }
    
    public var recvBufferSize:Int32? {
        get {
            return try? doWithBaseHandle { handle in
                return try RecvBufferSizeProperty.read(from: handle)
            }
        }
        set {
            do {
                try doWithBaseHandle { handle in
                    RecvBufferSizeProperty.writeNoThrow(to: handle, value: newValue)
                }
            } catch {
            }
        }
    }
    
    //present, because properties can not throw. So both ways
    public func getFileno() throws -> uv_os_fd_t {
        return try doWithBaseHandle { handle in
            try ccall(Error.self) { code in
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

extension HandleType {
    static func from(handle handle:uv_handle_type!) -> Self {
        let handle:uv_handle_p = handle.cast()
        return Unmanaged.fromOpaque(OpaquePointer(handle.pointee.data)).takeUnretainedValue()
    }
}

private func _handle_close_cb(handle:uv_handle_p?) {
    guard let handle = handle where handle != .null else {
        return
    }
    
    if handle.pointee.data != .null {
        let object = Unmanaged<HandleBase>.fromOpaque(OpaquePointer(handle.pointee.data)).takeRetainedValue()
        handle.pointee.data = nil
        object.clearHandle()
    }
    
    handle.deinitialize(count: 1)
    handle.deallocateCapacity(1)
}

#if swift(>=3.0)
    private func handle_close_cb(handle:uv_handle_p?) {
        _handle_close_cb(handle: handle)
    }
#else
    private func handle_close_cb(handle:uv_handle_p) {
        _handle_close_cb(handle)
    }
#endif

