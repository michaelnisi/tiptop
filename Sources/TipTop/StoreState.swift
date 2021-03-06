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

/// Enumerates possible states of the finite state machine (FSM), implementing
/// our IAP store, with seven states.
///
/// - initialized
/// - interested
/// - subscribed
/// - fetchingProducts
/// - offline
/// - purchasing
///
/// The specifics of each state are described inline.
enum StoreState: Equatable {

  /// The store starts passively in `initialized` awaiting activation.
  ///
  /// ## resume
  ///
  /// Begins observing payment queue for changed transactions and ubiquitous
  /// key value store for changed receipts. Fetches available products from the
  /// App Store and validates receipts, ideally resulting in one of the two
  /// user states, `interested` or `subscribed`. Of course, we might as well
  /// end up `offline` if the App Store is not reachable or the subscriber
  /// delegate has not been set yet.
  case initialized

  /// No valid receipts have been found. Meaning, no subscription has been
  /// purchased yet, subscriptions are expired, or receipts have been deleted.
  ///
  /// ## receiptsChanged
  /// Validates receipts, resulting in `interested` or `subscribed`.
  ///
  /// ## purchased
  /// Validates receipts, very likely transferring to `subscribed`.
  ///
  /// ## purchasing
  /// Moving to `purchasing`.
  ///
  /// ## failed
  /// Processes error ending up `offline` or `interested`.
  ///
  /// ## pay
  /// Adds payment to queue entering `purchasing`.
  ///
  /// ## update
  /// Fetches products from App Store and validates receipts entering one of the
  /// three elemental states, `interested`, `subscribed`, or `offline`.
  ///
  /// ## productsReceived([SKProduct], ShoppingError?)
  /// The product list has been received from the payment queue and the
  /// products will be forwarded to the shopping delegate for display.
  case interested(Bool)

  /// In `subscribed` state the store currently doesn???t handle any events, the
  /// user is a customer, has purchased a subscription. Ignores all events and
  /// stays `subscribed`.
  case subscribed(ProductIdentifier)

  /// Fetching products from the App Store.
  ///
  /// ## productsReceived([SKProduct], ShoppingError?)
  /// The product list has been received from the payment queue and the
  /// products will be forwarded to the shopping delegate for display.
  ///
  /// ## receiptsChanged
  /// We might receive receipts from `NSUbiquitousKeyValueStore` in the mean
  /// time. In that case we keep waiting for the products. After they have been
  /// received, receipts always get validated, error or not.
  ///
  /// ## update
  /// The `update` event is ignored, we keep `fetchingProducts`.
  ///
  /// ## online
  /// Keep waiting in  to receive the products with `productsReceived`, which
  /// is probably the next event.
  case fetchingProducts

  /// Cannot reach the App Store.
  ///
  /// ## online | receiptsChanged | update
  /// Releases probe and updates products, after validating receipts transfers
  /// to `interested` or `subscribed`. A `receiptsChanged` is unlikely here,
  /// but produces the same result.
  case offline(Bool)

  /// The user is purchasing a subscription.
  ///
  /// ## purchased
  /// Validates receipts resulting in `interested` or `subscribed`.
  ///
  /// ## failed
  /// Processes error ending up `offline`, `interested`, `subscribed`.
  ///
  /// ## purchasing | receiptsChanged | update
  /// These events are ignored staying in `purchasing`.
  indirect case purchasing(ProductIdentifier, StoreState)

  indirect case restoring(StoreState)
}

extension StoreState: CustomStringConvertible {

  var description: String {
    switch self {
    case .initialized:
      return "StoreState: initialized"
    case .interested(let free):
      return "StoreState: ( interested, \(free) )"
    case .subscribed(let pid):
      return "StoreState: ( subscribed, \(pid) )"
    case .fetchingProducts:
      return "StoreState: fetchingProducts"
    case .offline(let free):
      return "StoreState: ( offline, \(free) )"
    case .purchasing(let pid, let nextState):
      return "StoreState: ( purchasing, \(pid), \(nextState) )"
    case .restoring:
      return "StoreState: restoring"
    }
  }

}
