//===----------------------------------------------------------------------===//
//
// This source file is part of the TipTop open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/tiptop/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import XCTest
import StoreKit
@testable import TipTop

/// Tests in-app purchase receipts, `PodestReceipt`.
class ReceiptTests: XCTestCase {
  
  func testInvalidReceipts() {
    let past = PodestReceipt(
      productIdentifier: "abc",
      transactionIdentifier: "123",
      transactionDate: Date.distantPast
    )
    
    let future = PodestReceipt(
      productIdentifier: "abc",
      transactionIdentifier: "123",
      transactionDate: Date.distantFuture
    )
    
    let found = [
      Store.validProductIdentifier([], matching: Set()),
      Store.validProductIdentifier([past], matching: Set()),
      Store.validProductIdentifier([past], matching: Set(["def"])),
      Store.validProductIdentifier([past], matching: Set(["abc"])),
      Store.validProductIdentifier([future], matching: Set(["def"]))
    ]
    
    for f in found {
      XCTAssertNil(f)
    }
  }
  
  func testValidReceipts() {
    let past = PodestReceipt(
      productIdentifier: "abc",
      transactionIdentifier: "123",
      transactionDate: Date.distantPast
    )
    
    let future = PodestReceipt(
      productIdentifier: "abc",
      transactionIdentifier: "123",
      transactionDate: Date.distantFuture
    )
    
    let recent = PodestReceipt(
      productIdentifier: "def",
      transactionIdentifier: "123",
      transactionDate: Date.init(timeIntervalSinceNow: -3600)
    )
    
    let found = [
      Store.validProductIdentifier([future], matching: Set(["abc"])),
      Store.validProductIdentifier([past, future], matching: Set(["abc"])),
      Store.validProductIdentifier([future, past], matching: Set(["abc"])),
      Store.validProductIdentifier([past, future, past], matching: Set(["abc"])),
      Store.validProductIdentifier([recent, past, future], matching: Set(["def"])),
      Store.validProductIdentifier([past, recent, past], matching: Set(["def"])),
      Store.validProductIdentifier([future, past, recent], matching: Set(["def"]))
    ]
    
    let wanted = [
      "abc",
      "abc",
      "abc",
      "abc",
      "def",
      "def",
      "def"
    ]
    
    for (n, f) in found.enumerated() {
      let w = wanted[n]
      XCTAssertEqual(f, w)
    }
  }
  
}
