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

import StoreKit

/// The payment queue proxy allows swapping out the queue for testing.
protocol Paying {
  func add(_ payment: SKPayment)
  func restoreCompletedTransactions()
  func finishTransaction(_ transaction: SKPaymentTransaction)
  func add(_ observer: SKPaymentTransactionObserver)
  func remove(_ observer: SKPaymentTransactionObserver)
}

extension Paying {
  func add(_ payment: SKPayment) {
    SKPaymentQueue.default().add(payment)
  }
  
  func restoreCompletedTransactions() {
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
  
  func finishTransaction(_ transaction: SKPaymentTransaction) {
    SKPaymentQueue.default().finishTransaction(transaction)
  }
  
  func add(_ observer: SKPaymentTransactionObserver) {
    SKPaymentQueue.default().add(observer)
  }
  
  func remove(_ observer: SKPaymentTransactionObserver) {
    SKPaymentQueue.default().remove(observer)
  }
}
