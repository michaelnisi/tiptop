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

import Foundation

struct Initialized: StoreReducing {
  let store: Store
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
    switch event {
    case .resume:
      return store.addObservers()
      
    case .pause, .considerReview, .review:
      return state
      
    case .cancelReview(let resetting):
      store.reviewRequester?.cancelReview(resetting: resetting)
      
      return state
      
    case .failed,
        .online,
        .pay,
        .productsReceived,
        .purchased,
        .purchasing,
        .receiptsChanged,
        .update,
        .restore,
        .restored:
      fatalError("unhandled event")
    }
  }
}
