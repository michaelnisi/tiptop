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

/// A receipt for a product purchase stored in iCloud.
struct PodestReceipt: Codable {
  let productIdentifier: String
  let transactionIdentifier: String
  let transactionDate: Date

  init?(transaction: SKPaymentTransaction) {
    guard
      let transactionIdentifier = transaction.transactionIdentifier,
      let transactionDate = transaction.transactionDate else {
      return nil
    }
    self.productIdentifier = transaction.payment.productIdentifier
    self.transactionIdentifier = transactionIdentifier
    self.transactionDate = transactionDate
  }

  init(productIdentifier: String, transactionIdentifier: String, transactionDate: Date) {
    self.productIdentifier = productIdentifier
    self.transactionIdentifier = transactionIdentifier
    self.transactionDate = transactionDate
  }
}
