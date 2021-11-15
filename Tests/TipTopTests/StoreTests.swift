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

extension StoreDelegate {
  func store(_ store: Shopping, offers products: [SKProduct], error: ShoppingError?) {}
  func store(_ store: Shopping, purchasing productIdentifier: String) {}
  func store(_ store: Shopping, purchased productIdentifier: String) {}
  func storeRestoring(_ store: Shopping) {}
  func storeRestored(_ store: Shopping, productIdentifiers: [String]) {}
  func store(_ store: Shopping, error: ShoppingError) {}
}

extension Paying {
  func add(_ payment: SKPayment) {}
  func restoreCompletedTransactions() {}
  func finishTransaction(_ transaction: SKPaymentTransaction) {}
  func add(_ observer: SKPaymentTransactionObserver) {}
  func remove(_ observer: SKPaymentTransactionObserver) {}
}

private class TestPaymentQueue: Paying {}

class StoreTests: XCTestCase {
  
  class Accessor: StoreAccessDelegate {
    
    func reach() -> Bool {
      return true
    }
    
    var isAccessible = false
    
    func store(_ store: Shopping, isAccessible: Bool) {
      self.isAccessible = isAccessible
    }
    
    var isExpired = false
    
    func store(_ store: Shopping, isExpired: Bool) {
      self.isExpired = isExpired
    }
  }
  
  class StoreController: StoreDelegate {
    
    var products: [SKProduct]?
    
    func store(
      _ store: Shopping,
      offers products: [SKProduct],
      error: ShoppingError?
    ) {
      self.products = products
    }
  }
  
  var store: Store!
  var db: NSUbiquitousKeyValueStore!
  
  override func setUp() {
    super.setUp()
    
    let url = Bundle.module.url(forResource: "products", withExtension: "json")!
    let v = BuildVersion(bundle: Bundle.module)

    XCTAssertEqual(v.env, .simulator)

    let q = TestPaymentQueue()
    
    db = NSUbiquitousKeyValueStore()
    store = Store(url: url, paymentQueue: q, db: db, version: v)
    
    
    XCTAssertEqual(store.state, .initialized)
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  private func injectReceipts() {
    let r = PodestReceipt(
      productIdentifier: "abc",
      transactionIdentifier: "abc123",
      transactionDate: Date()
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode([r])
    
    db.set(data, forKey: "receipts")
  }
}

// MARK: - Resuming

extension StoreTests {
  
  func testResumingInterested() {
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    
    store.resume()
    
    let exp = expectation(description: "resuming")
    let q = DispatchQueue.main
    
    q.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      q.asyncAfter(deadline: .now() + .milliseconds(15)) {
        let ids = Set(["abc", "def", "ghi"])
        let req = SKProductsRequest(productIdentifiers: ids)
        let res = SKProductsResponse()
        
        // The end. Unfortunately, I cannot mock a products response.
        
        self.store.productsRequest(req, didReceive: res)
        
        q.asyncAfter(deadline: .now() + .milliseconds(15)) {
          XCTAssertEqual(self.store.state, .interested(true))
          XCTAssertEqual(delegate.products, [])
          XCTAssertTrue(subscriberDelegate.isAccessible)
          XCTAssertFalse(subscriberDelegate.isExpired)
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5)
  }
  
  func testResumingSubscribed() {
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    
    injectReceipts()
    store.resume()
    
    let exp = expectation(description: "resuming")
    let q = DispatchQueue.main
    
    q.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      q.asyncAfter(deadline: .now() + .milliseconds(15)) {
        let ids = Set(["abc", "def", "ghi"])
        let req = SKProductsRequest(productIdentifiers: ids)
        let res = SKProductsResponse()
        
        // The end. Unfortunately, I cannot mock a products response.
        
        self.store.productsRequest(req, didReceive: res)
        
        q.asyncAfter(deadline: .now() + .milliseconds(15)) {
          XCTAssertEqual(self.store.state, .subscribed("abc"))
          XCTAssertEqual(delegate.products, [])
          XCTAssertFalse(subscriberDelegate.isAccessible)
          XCTAssertFalse(subscriberDelegate.isExpired)
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5)
  }
  
  func testResumingWithoutDelegate() {
    let exp = expectation(description: "resuming")
    
    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .offline(true))
      exp.fulfill()
    }
    
    waitForExpectations(timeout: 5)
  }
}

// MARK: - Updating Settings 

extension StoreTests {
  
  func testMakeSettingsInfo() {
    XCTAssertNil(Store.makeSettingsInfo(receipts: []))
    
    let wanted = Date()
    
    let receipts = [
      PodestReceipt(
        productIdentifier: "com.apple.peter", 
        transactionIdentifier: "abc", 
        transactionDate: Date(timeIntervalSinceNow: 120)
      ),
      PodestReceipt(
        productIdentifier: "com.apple.paul", 
        transactionIdentifier: "def", 
        transactionDate: wanted
      ),
      PodestReceipt(
        productIdentifier: "com.apple.mary", 
        transactionIdentifier: "ghi", 
        transactionDate: Date(timeIntervalSinceNow: 60)
      )
    ]
    
    let (status, expiration) = Store.makeSettingsInfo(receipts: receipts)!
    
    XCTAssertEqual(status, "Paul", "should find the youngest")
    XCTAssertEqual(expiration, Store.makeExpiration(
      date: wanted, 
      period: .subscription
    ))
  }
}

// MARK: - Expiring

extension StoreTests {
  
  func testExpiredTrial() {
    db.set(Date.distantPast.timeIntervalSince1970, forKey: Store.unsealedKey)
    
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    let exp = expectation(description: "fetching products")
    
    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      
      let req = SKProductsRequest(productIdentifiers: Set())
      let res = SKProductsResponse()
      
      self.store.productsRequest(req, didReceive: res)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
        XCTAssertEqual(self.store.state, .interested(false))
        XCTAssertEqual(delegate.products, [])
        XCTAssertTrue(subscriberDelegate.isAccessible)
        
        XCTAssertFalse(
          subscriberDelegate.isExpired,
          "should not have been called yet"
        )
        
        XCTAssertTrue(self.store!.isExpired())
        
        DispatchQueue.main.async {
          XCTAssertTrue(
            subscriberDelegate.isExpired,
            "should be updated with isExpired method"
          )
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5) { er in }
  }
  
  func testExpiredTrialSubscribed() {
    db.set(Date.distantPast.timeIntervalSince1970, forKey: Store.unsealedKey)
    
    let subscriberDelegate = Accessor()
    store.subscriberDelegate = subscriberDelegate
    let delegate = StoreController()
    store.delegate = delegate
    let exp = expectation(description: "fetching products")
    
    injectReceipts()
    store.resume()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
      XCTAssertEqual(self.store.state, .fetchingProducts)
      
      let req = SKProductsRequest(productIdentifiers: Set())
      let res = SKProductsResponse()
      
      self.store.productsRequest(req, didReceive: res)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
        XCTAssertEqual(self.store.state, .subscribed("abc"))
        XCTAssertEqual(delegate.products, [])
        XCTAssertFalse(subscriberDelegate.isAccessible)
        XCTAssertFalse(subscriberDelegate.isExpired)
        XCTAssertFalse(self.store!.isExpired())
        
        DispatchQueue.main.async {
          XCTAssertFalse(subscriberDelegate.isExpired)
          exp.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5) { er in }
  }
  
  func testMakeExpiration() {
    let zero = Date(timeIntervalSince1970: 0)
    let fixtures: [(Date, Store.Period, Date)] = [
      (zero, .always, zero),
      (zero, .subscription, zero.addingTimeInterval(3.154e7)),
      (zero, .trial, zero.addingTimeInterval(2.419e6))
    ]
    
    for (date, period, wanted) in fixtures {
      XCTAssertEqual(Store.makeExpiration(date: date, period: period), wanted)
    }
  }

  func testExpiration() {
    do {
      let expirations: [Store.Period] = [.trial, .subscription]

      for x in expirations {
        XCTAssertFalse(x.isExpired(date: Date.distantFuture))
        XCTAssertTrue(x.isExpired(date: Date.distantPast))
        XCTAssertFalse(x.isExpired(date: Date()))
      }
    }

    do {
      let always = Store.Period.always
      let dates = [Date(), Date.distantPast]

      for date in dates {
        XCTAssertTrue(always.isExpired(date: date))
      }

      XCTAssertFalse(always.isExpired(date: Date.distantFuture))
    }

    do {
      XCTAssertFalse(Store.Period.trial.isExpired(
        date: Date(timeIntervalSinceNow: -Store.Period.trial.rawValue + 1)))
      XCTAssertTrue(Store.Period.trial.isExpired(
        date: Date(timeIntervalSinceNow: -Store.Period.trial.rawValue)))

      XCTAssertFalse(Store.Period.subscription.isExpired(
        date: Date(timeIntervalSinceNow: -Store.Period.subscription.rawValue + 1)))
      XCTAssertTrue(Store.Period.subscription.isExpired(
        date: Date(timeIntervalSinceNow: -Store.Period.subscription.rawValue)))
    }
  }
  
  static var allTests: [(String, (StoreTests) -> () -> ())] = [
  ]
}
