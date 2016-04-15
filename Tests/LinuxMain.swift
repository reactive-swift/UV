import XCTest

@testable import UVTestSuite

XCTMain([
	testCase(LoopTests.allTests),
	testCase(UVTests.allTests),
])