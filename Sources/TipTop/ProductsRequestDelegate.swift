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

extension Store: SKProductsRequestDelegate {
  public func productsRequest(
    _ request: SKProductsRequest,
    didReceive response: SKProductsResponse
  ) {
    os_log("response received: %@", log: log, type: .debug, response)

    DispatchQueue.main.async {
      self.request = nil
    }

    DispatchQueue.global(qos: .utility).async {
      let error: ShoppingError? = {
        let invalidIDs = response.invalidProductIdentifiers

        guard invalidIDs.isEmpty else {
          os_log("invalid product identifiers: %@",
                 log: log, type: .error, invalidIDs)
          return .invalidProduct(invalidIDs.first!)
        }

        return nil
      }()

      let products = response.products

      self.event(.productsReceived(products, error))
    }
  }
}
