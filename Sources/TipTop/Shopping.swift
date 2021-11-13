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

/// Plain Strings to identify products for flexibility.
public typealias ProductIdentifier = String

/// A locally known product, stored in the local JSON file `products.json`.
struct LocalProduct: Codable {
  let productIdentifier: ProductIdentifier
}

/// Get notified when accessiblity to the store changes.
public protocol StoreAccessDelegate: AnyObject {
  /// Pinged if the store should be shown or hidden.
  func store(_ store: Shopping, isAccessible: Bool)
  
  /// The delegate is responsible for checking if the App Store is reachable.
  /// This method should return `true` if the App Store is reachable. If the
  /// App Store is not reachable, it should return `false` and begin probing
  /// reachability, so it can notify the store via `Shopping.online()` once the
  /// App Store can be reached again.
  func reach() -> Bool

  /// Receives expiration updates.
  func store(_ store: Shopping, isExpired: Bool)
}

/// Receives shopping events.
public protocol StoreDelegate: AnyObject {
  /// After fetching available IAPs, this callback receives products or error.
  func store(
    _ store: Shopping,
    offers products: [SKProduct],
    error: ShoppingError?
  )

  /// The identifier of the product currently being purchased.
  func store(_ store: Shopping, purchasing productIdentifier: String)

  /// The identifier of a successfully purchased product.
  func store(_ store: Shopping, purchased productIdentifier: String)

  /// Display an error message after this callback.
  func store(_ store: Shopping, error: ShoppingError)
}

/// Ask users for rating and reviews.
public protocol Rating {
  /// Requests user to rate the app if appropriate.
  func considerReview()

  /// Cancels previous review request, `resetting` the cycle to defer the next.
  ///
  /// For example, just after becoming active again is probably not a good time
  /// to ask for a rating. Prevent this by `resetting` before going into the
  /// background.
  func cancelReview(resetting: Bool)

  /// Cancels previous review request.
  func cancelReview()
}

/// Checking user status.
public protocol Expiring {
  /// Returns `true` if the trial period has been exceeded, `false` is returned
  /// within the trial period or if a valid subscription receipt is present.
  ///
  /// Might modify internal state or call delegates.
  func isExpired() -> Bool
}

/// A set of methods to offer in-app purchases.
public protocol Shopping: SKPaymentTransactionObserver, Rating, Expiring {
  /// Clients use this delegate to receive callbacks from the store.
  var delegate: StoreDelegate? { get set }

  /// The store isn’t always accessible. The subscriber delegate get notified
  /// about that.
  var subscriberDelegate: StoreAccessDelegate? { get set }
  
  /// Requests App Store for payment of the product matching `productIdentifier`.
  func payProduct(matching productIdentifier: String)

  /// Is `true` if users can make payments.
  var canMakePayments: Bool { get }
  
  /// Synchronizes pending transactions with the Apple App Store, observing the
  /// payment queue for transaction updates.
  ///
  /// There’s no use case for `pause`.
  func resume()
  
  /// Updates the store state.
  func update()
  
  /// Notifies the store that the App Store is reachable.
  func online()
  
  /// Requests App Store to restore previously completed purchases.
  func restore()
}

