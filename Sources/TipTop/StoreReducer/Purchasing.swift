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
import os.log

private let log = OSLog(subsystem: "ink.codes.tiptop", category: "Store")

struct Purchasing: StoreReducing {
  let store: Store
  let nextState: StoreState
  let productIdentifier: ProductIdentifier
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
      switch event {
      case .purchased(let pid):
        if productIdentifier != pid {
          os_log("mismatching products: ( %@, %@ )", log: log, productIdentifier, pid)
        }

        store.delegateQueue.async {
          store.delegate?.store(store, purchased: pid)
        }

        return store.updateIsAccessible(matching: store.validateReceipts())
        
      case .failed(let error):
        return store.updatedState(after: error, next: nextState)
        
      case .purchasing(let pid), .pay(let pid):
        if productIdentifier != pid {
          os_log("parallel purchasing: ( %@, %@ )", log: log, productIdentifier, pid)
        }

        return state
      
      case .receiptsChanged:
        return store.updateIsAccessible(matching: store.validateReceipts())

      case .update:
        return store.updateProducts()

      case .pause:
        return store.removeObservers()

      case .productsReceived(let products, let error):
        return store.receiveProducts(products, error: error)
        
      case .considerReview, .review:
        return state
        
      case .cancelReview(let resetting):
        store.reviewRequester?.cancelReview(resetting: resetting)
        
        return state

      case .resume, .online, .restore, .restored:
        fatalError("unhandled event")
      }
  }
}
