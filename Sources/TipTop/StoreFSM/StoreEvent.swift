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

/// Enumerates known events within the store.
enum StoreEvent {
  case resume
  case pause
  case failed(ShoppingError)
  case online
  case pay(ProductIdentifier)
  case productsReceived([SKProduct], ShoppingError?)
  case purchased(ProductIdentifier)
  case purchasing(ProductIdentifier)
  case receiptsChanged
  case update
  case considerReview
  case review
  case cancelReview(Bool)
}

extension StoreEvent: CustomStringConvertible {
  var description: String {
    switch self {
    case .resume:
      return "StoreEvent: resume"
    case .pause:
      return "StoreEvent: pause"
    case .failed(let error):
      return "StoreEvent: failed: \(error)"
    case .online:
      return "StoreEvent: online"
    case .pay(let productIdentifier):
      return "StoreEvent: pay: \(productIdentifier)"
    case .productsReceived(let products, let error):
      return """
      StoreEvent: productsReceived: (
        products: \(products),
        error: \(error.debugDescription)
      )
      """
    case .purchased(let productIdentifier):
      return "StoreEvent: purchased: \(productIdentifier)"
    case .purchasing(let productIdentifier):
      return "StoreEvent: purchasing: \(productIdentifier)"
    case .receiptsChanged:
      return "StoreEvent: receiptsChanged"
    case .update:
      return "StoreEvent: update"
    case .review:
      return "StoreEvent: review"
    case .considerReview:
      return "StoreEvent: considerReview"
    case .cancelReview:
      return "StoreEvent: cancelReview"
    }
  }
}
