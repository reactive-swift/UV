//
//  StreamTests.swift
//  UV
//
//  Created by Daniel Leping on 21/04/2016.
//  Copyright © 2016 Crossroad Labs s.r.o. All rights reserved.
//

import Foundation

import XCTest
@testable import UV
import CUV

class StreamTests: XCTestCase {
    func testConnectability() {
        let loop = try! Loop()
        let server = try! TCP(loop: loop) { server in
            let accepted = try! server.accept()
            accepted.close()
            server.close()
        }
        var addr = sockaddr_in()
        
        uv_ip4_addr("127.0.0.1", 45678, &addr)
        
        try! withUnsafePointer(&addr) { pointer in
            try server.bind(UnsafePointer(pointer))
        }
        
        try! server.listen(125)
        
        let client = try! TCP(loop: loop) {_ in}
        
        withUnsafePointer(&addr) { pointer in
            client.connect(UnsafePointer(pointer)) { req, e in
                print("connected")
            }
        }
        
        loop.run(UV_RUN_DEFAULT)
    }
}