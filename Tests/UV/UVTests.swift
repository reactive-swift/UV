//===--- UVTests.swift -------------------------------------------------------===//
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

import XCTest
@testable import UV
import CUV

class UVTests: XCTestCase {
        
    func testTimer() {
        var counter = 0
        
        let loop = try! Loop()
        let timer = try! Timer(loop: loop) { timer in
            counter += 1
            print("timer:", counter)
            if counter == 10 {
                try! timer.stop()
                try! timer.start(.Immediate, repeatTimeout: .In(timeout: 0.1))
            }
            if counter > 20 {
                timer.close()
            }
        }
        
        try! timer.start(.Immediate, repeatTimeout: .In(timeout: 0.05))
        
        loop.run()
        
        print(timer.repeatTimeout)
    }
    
    func testExample() {
        let loop = try? Loop()
        
        loop?.run()
    }
    
}

#if os(Linux)
extension UVTests {
	static var allTests : [(String, UVTests -> () throws -> Void)] {
		return [
			("testExample", testExample),
			("testTimer", testTimer),
		]
	}
}
#endif