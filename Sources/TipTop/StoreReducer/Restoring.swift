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

struct Restoring: StoreReducing {
  let store: Store
  let nextState: StoreState
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
    switch event {
    case .receiptsChanged:
      return store.updateIsAccessible(matching: store.validateReceipts())
      
    case .failed(let error):
      if case .failed = error {
        // In fact, non-renewable subscriptions are not restorable via App Store.
        return store.updateIsAccessible(matching: store.validateReceipts())
      }
      
      return store.updatedState(after: error, next: nextState)
      
    case .restore:
      return store.restore()
      
    case .restored:
      return store.updateIsAccessible(matching: store.validateReceipts())
      
    case
        .resume,
        .pause,
        .online,
        .pay(_),
        .productsReceived(_, _),
        .purchased(_),
        .purchasing(_),
        .update,
        .considerReview,
        .review,
        .cancelReview(_):
      fatalError("event not handled: \(event)")
    }
  }
}
