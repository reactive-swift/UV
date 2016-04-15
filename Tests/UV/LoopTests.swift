//===--- LoopTests.swift -----------------------------------------------------===//
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
//===-------------------------------------------------------------------------===//

import Foundation

import XCTest
@testable import UV
import CUV

class LoopTests: XCTestCase {
    
    func testCreateDestroy() {
        let loop1 = try? Loop()
        XCTAssertNotNil(loop1)
        let loop2 = try? Loop()
        XCTAssertNotNil(loop2)
        XCTAssertNotEqual(loop1, loop2)
    }
    
    func testDefaultLoop() {
        let loop1 = Loop.defaultLoop()
        let loop2 = Loop.defaultLoop()
        XCTAssertEqual(loop1, loop2)
    }
    
    func testAlive() {
        let loop = try! Loop()
        
        XCTAssertFalse(loop.alive)
        //TODO: add source, check alive
    }
    
    func testStop() {
        //TODO: implement
    }
    
    func testBackendFd() {
        let fd = Loop.defaultLoop().backendFd
        XCTAssertGreaterThan(fd, 0)
    }
    
    func testBackendTimeout() {
        let loop = Loop.defaultLoop()
        let timeout = loop.backendTimeout.flatMap { $0 == 0 ? nil : $0 }
        XCTAssertNil(timeout)
        //TODO: set timeout, test again
    }
    
    func testTime() {
        let loop = Loop.defaultLoop()
        
        let time1 = loop.now
        let time2 = loop.now
        usleep(10000)
        loop.updateTime()
        let time3 = loop.now
        usleep(10000)
        loop.run()
        let time4 = loop.now
        
        XCTAssertEqual(time1, time2)
        XCTAssertNotEqual(time1, time3)
        XCTAssertNotEqual(time1, time4)
        XCTAssertNotEqual(time3, time4)
    }
    
    func testWalk() {
        let loop = Loop.defaultLoop()
        
        var n = 0
        loop.walk { handle in
            n += 1
        }
        
        XCTAssertEqual(n, 0)
        
        let timer = try! Timer(loop: loop) { timer in
        }
        
        n = 0
        loop.walk { handle in
            n += 1
        }
        
        XCTAssertEqual(n, 1)
        
        XCTAssertEqual(loop.handles.count, 1)
        
        for handle in loop.handles {
            XCTAssertEqual(handle.baseHandle, timer.baseHandle)
        }
    }
}

#if os(Linux)
extension LoopTests {
	static var allTests : [(String, LoopTests -> () throws -> Void)] {
		return [
			("testCreateDestroy", testCreateDestroy),
			("testDefaultLoop", testDefaultLoop),
			("testAlive", testAlive),
			("testStop", testStop),
			("testBackendFd", testBackendFd),
			("testBackendTimeout", testBackendTimeout),
			("testTime", testTime),
			("testWalk", testWalk),
		]
	}
}
#endif