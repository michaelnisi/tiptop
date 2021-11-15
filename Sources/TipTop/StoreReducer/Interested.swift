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

struct Interested: StoreReducing {
  let store: Store
  
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
      switch event {
      case .restore:
        return store.restore()
        
      case .restored:
        fatalError()
        
      case .receiptsChanged:
        return store.updateIsAccessible(matching: store.validateReceipts())

      case .purchased(let pid):
        store.delegateQueue.async {
          self.store.delegate?.store(self.store, purchased: pid)
        }

        return store.updateIsAccessible(matching: store.validateReceipts())

      case .purchasing(let pid):
        store.delegateQueue.async {
          self.store.delegate?.store(self.store, purchasing: pid)
        }

        return .purchasing(pid, state)

      case .failed(let error):
        return store.updatedState(after: error, next: state)

      case .pay(let pid):
        store.delegateQueue.async {
          self.store.delegate?.store(self.store, purchasing: pid)
        }

        return store.addPayment(matching: pid)

      case .update:
        return store.updateProducts()

      case .productsReceived(let products, let error):
        return store.receiveProducts(products, error: error)

      case .resume:
        return state

      case .pause:
        return store.removeObservers()

      case .online:
        fatalError("unhandled event")
        
      case .considerReview:
        store.reviewRequester?.setReviewTimeout {
          self.store.event(.review)
        }
        
        return state
        
      case .review:
        store.reviewRequester?.requestReview()
      
        return state
        
      case .cancelReview(let resetting):
        store.reviewRequester?.cancelReview(resetting: resetting)
        
        return state
      }
  }
}
