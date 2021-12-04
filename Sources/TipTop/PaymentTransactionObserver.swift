//===----------------------------------------------------------------------===//
//
// This source file is part of the Podest open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/podest/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import StoreKit
import os.log

private let log = OSLog(subsystem: "ink.codes.tiptop", category: "PaymentTransactionObserver")

// MARK: - SKPaymentTransactionObserver

extension Store: SKPaymentTransactionObserver {
  public func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    os_log("updated transactions", log: log, type: .debug)
    
    DispatchQueue.global(qos: .userInitiated).async {
      for t in transactions {
        self.process(transaction: t)
      }
    }
  }
  
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    os_log("restore failed: %{public}@", log: log, type: .error, error as CVarArg)
    
    DispatchQueue.global(qos: .userInitiated).async {
      self.event(.failed(.failed))
    }
  }

  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    os_log("restore completed: %{pulbic}i", log: log, type: .debug, queue.transactions.count)
    
    DispatchQueue.global(qos: .userInitiated).async {
      self.event(.restored)
    }
  }
}

private extension Store {
  func finish(transaction t: SKPaymentTransaction) {
    os_log("finishing: %@", log: log, type: .debug, t)
    paymentQueue.finishTransaction(t)
  }

  func process(transaction t: SKPaymentTransaction) {
    os_log("processing: %@", log: log, type: .debug, t)

    let pid = t.payment.productIdentifier

    guard t.error == nil else {
      let er = t.error!

      os_log("handling transaction error: %@",
             log: log, type: .error, er as CVarArg)

      event(.failed(ShoppingError(underlyingError: er)))

      return finish(transaction: t)
    }

    switch t.transactionState {
    case .failed:
      os_log("transactionState: failed", log: log, type: .debug)
      event(.failed(.failed))
      finish(transaction: t)

    case .purchased:
      os_log("transactionState: purchased", log: log, type: .debug)
      guard let receipt = PodestReceipt(transaction: t) else {
        fatalError("receipt missing")
      }
      
      saveReceipt(receipt)
      event(.purchased(pid))

      finish(transaction: t)

    case .purchasing, .deferred:
      os_log("transactionState: purchasing | deferred", log: log, type: .debug)
      event(.purchasing(pid))

    case .restored:
      fatalError("unexpected transaction state")
      
    @unknown default:
      fatalError("unknown case in switch: \(t.transactionState)")
    }
  }
}
