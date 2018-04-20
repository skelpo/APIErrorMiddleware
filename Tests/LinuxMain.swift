import XCTest

import APIErrorMiddlewareTests

var tests = [XCTestCaseEntry]()
tests += APIErrorMiddlewareTests.allTests()
XCTMain(tests)