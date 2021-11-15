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

struct FetchingProducts: StoreReducing {
  let store: Store
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
    switch event {
    case .productsReceived(let products, let error):
      return store.receiveProducts(products, error: error)
    
    case .receiptsChanged, .update, .online:
      return state

    case .failed(let error):
      return store.updatedState(after: error, next: .interested(store.validateTrial()))

    case .resume, .considerReview, .review:
      return state
    
    case .cancelReview(let resetting):
      store.reviewRequester?.cancelReview(resetting: resetting)
      
      return state

    case .pause:
      return store.removeObservers()

    case .pay, .purchased, .purchasing, .restore, .restored:
      fatalError("unhandled event")
    }
  }
}
