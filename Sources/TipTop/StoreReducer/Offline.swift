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

struct Offline: StoreReducing {
  let store: Store
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
    switch event {
    case .online, .receiptsChanged, .update:
      return store.updateProducts()

    case .pause:
      return store.removeObservers()
      
    case .considerReview, .review:
      return state
      
    case .cancelReview(let resetting):
      store.reviewRequester?.cancelReview(resetting: resetting)
      
      return state

    case .resume, .failed, .pay, .productsReceived, .purchased, .purchasing, .restore, .restored:
      fatalError("unhandled event")
    }
  }
}
