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

import UIKit
import StoreKit
import os.log

private let log = OSLog(subsystem: "ink.codes.tiptop", category: "Store")

public class DefaultPaymentQueue: Paying {
  public init() {}
}

/// Store is a store for in-app purchases, offering a single non-renewing
/// subscription at three flexible prices. After a successful purchase the store
/// disappears. It returns when the subscription expires or its receipts has
/// been deleted from the `Storing` key-value database.
///
/// The exposed `Shopping` API expects calls from the main queue.
public final class Store: NSObject {
  /// The file URL of where to find the product identifiers.
  private let url: URL

  /// The maximum age of cached products should be kept relatively short, not
  /// existing products cannot be sold. However, products don’t change often.
  private let ttl: TimeInterval
  
  /// A queue of payment transactions to be processed by the App Store.
  let paymentQueue: Paying
  
  /// The (default) iCloud key-value store object.
  private let db: NSUbiquitousKeyValueStore

  /// The version of the app.
  private let version: BuildVersion

  static var unsealedKey = "ink.codes.podest.store.unsealed"
  
  private var unsealedTime: TimeInterval {
    db.double(forKey: Store.unsealedKey)
  }
  
  /// Sets unsealed timestamp in `db` and returns existing or new timestamp.
  @discardableResult 
  private static func unseal(
    _ db: NSUbiquitousKeyValueStore, 
    env: BuildVersion.Environment
  ) -> TimeInterval {  
    let value = db.double(forKey: Store.unsealedKey)
    
    guard env != .sandbox, value != 0 else {
      os_log("unsealing", log: log)
      
      let ts = Date().timeIntervalSince1970
      
      db.set(ts, forKey: Store.unsealedKey)
      
      return ts
    }
    
    return value
  }
  
  var reviewRequester: ReviewRequester?
  
  /// Creates a new store with minimal dependencies. **Protocol dependencies**
  /// for easier testing.
  ///
  /// - Parameters:
  ///   - url: The file URL of a JSON file containing product identifiers.
  ///   - ttl: The maximum age, 10 minutes, of cached products in seconds.
  ///   - paymentQueue: The App Store payment queue.
  ///   - db: The (default) iCloud key-value store object.
  ///   - version: The version of this app.
  public init(
    url: URL,
    ttl: TimeInterval = 600,
    paymentQueue: Paying = DefaultPaymentQueue(),
    db: NSUbiquitousKeyValueStore = .default,
    version: BuildVersion = BuildVersion()
  ) {
    self.url = url
    self.ttl = ttl
    self.paymentQueue = paymentQueue
    self.db = db
    self.version = version
    self.state = .initialized
    
    let t = Store.unseal(db, env: version.env)
    self.reviewRequester = ReviewRequester(
      version: version, unsealedTime: t, log: log)
  }

  /// A date formatting block.
  public var formatDate: ((Date) -> String)?

  /// Flag for asserts, `true` if we are observing the payment queue.
  private var isObserving: Bool {
    didChangeExternallyObserver != nil
  }

  /// The currently available products.
  private (set) var products: [SKProduct]?

  weak public var delegate: StoreDelegate?
  
  weak public var subscriberDelegate: StoreAccessDelegate?
  
  // MARK: Reachability

  private func isReachable() -> Bool {
    subscriberDelegate?.reach() ?? false
  }

  // MARK: Products and Identifiers

  /// Returns the first product matching `identifier`.
  private func product(matching identifier: ProductIdentifier) -> SKProduct? {
    products?.first { $0.productIdentifier == identifier }
  }

  /// The current products request.
  var request: SKProductsRequest?

  private var _productIdentifiers: Set<String>?

  /// Product identifiers of, locally known, available products. If necessary,
  /// loaded from a configuration file.
  private var productIdentifiers: Set<String> {
    if let pids = _productIdentifiers {
      return pids
    }
    
    dispatchPrecondition(condition: .notOnQueue(.main))

    do {
      os_log("loading product identifiers", log: log, type: .debug)
      
      let json = try Data(contentsOf: url)
      let localProducts = try JSONDecoder().decode(
        [LocalProduct].self, from: json
      )
      _productIdentifiers = Set(localProducts.map { $0.productIdentifier })
      
      os_log("product identifiers: %@", log: log, type: .debug, _productIdentifiers!)
      
      return _productIdentifiers!
    } catch {
      os_log("no product identifiers", log: log, type: .error)
      
      return []
    }
  }

  private func fetchProducts() {
    os_log("fetching products: %@", log: log, type: .debug, self.productIdentifiers)
    request?.cancel()

    let req = SKProductsRequest(productIdentifiers: self.productIdentifiers)
    req.delegate = self
    
    req.start()
    
    request = req
  }

  func updateProducts() -> StoreState {
    guard isReachable() else {
      delegateQueue.async {
        self.delegate?.store(self, offers: [], error: .offline)
      }
      
      if case .subscribed = validateReceipts() {
        return .offline(true)
      } else {
        return .offline(validateTrial())
      }
    }
    
    fetchProducts()
    
    return .fetchingProducts
  }

  // MARK: Saving and Loading Receipts

  /// Returns different key for store and sandbox `environment`.
  private static func receiptsKey(suiting environment: BuildVersion.Environment) -> String {
    environment == .sandbox ? "receiptsSandbox" : "receipts"
  }
  
  public func removeReceipts(forcing: Bool = false) -> Bool {
    switch (version.env, forcing) {
    case (.sandbox, _), (.store, true), (.simulator, _):
      os_log("removing receipts", log: log)
      db.removeObject(forKey: Store.receiptsKey(suiting: version.env))
      Store.unseal(db, env: version.env)
      
      return true
      
    case (.store, _):
      os_log("not removing production receipts without force", log: log)
      
      return false
    }
  }

  private func loadReceipts() -> [PodestReceipt] {
    dispatchPrecondition(condition: .notOnQueue(.main))

    let r = Store.receiptsKey(suiting: version.env)

    os_log("loading receipts: %@", log: log, type: .debug, r)

    guard let json = db.data(forKey: r) else {
      os_log("no receipts: creating container: %@", log: log, type: .debug, r)
      return []
    }
    
    do {
      return try JSONDecoder().decode([PodestReceipt].self, from: json)
    } catch {
      precondition(removeReceipts(forcing: true))
      return []
    }
  }

  private func updateSettings(status: String, expiration: Date) {
    let date = formatDate?(expiration) ?? expiration.description
    
    os_log("updating settings: ( %@, %@ )", log: log, type: .debug, status, date)
    UserDefaults.standard.set(status, forKey: UserDefaults.statusKey)
    UserDefaults.standard.set(date, forKey: UserDefaults.expirationKey)
  }

  static func makeExpiration(date: Date, period: Period) -> Date {
    Date(timeIntervalSince1970: date.timeIntervalSince1970 + period.rawValue)
  }

  func saveReceipt(_ receipt: PodestReceipt) {
    os_log("saving receipt: %@", log: log, type: .debug, String(describing: receipt))

    let acc = loadReceipts() + [receipt]
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode(acc)
    let r = Store.receiptsKey(suiting: version.env)

    db.set(data, forKey: r)

    if let (status, expiration) = Store.makeSettingsInfo(receipts: acc) {
      updateSettings(status: status, expiration: expiration)
    }

    let str = String(data: data, encoding: .utf8)!

    os_log("saved: ( %@, %@ )", log: log, type: .debug, r, str)
  }

  /// Enumerates time periods in seconds.
  enum Period: TimeInterval {
    typealias RawValue = TimeInterval
    case subscription = 3.154e7
    case trial = 2.419e6
    case always = 0

    /// Returns `true` if `date` exceeds this period into the future.
    func isExpired(date: Date) -> Bool {
      date.timeIntervalSinceNow <= -rawValue
    }
  }
  
  /// Returns the product identifier of the first valid subscription found in
  /// `receipts` or `nil` if a matching product identifier could not be found
  /// or, respectively, all matching transactions are older than one year, the
  /// duration of our subscriptions.
  static func validProductIdentifier(
    _ receipts: [PodestReceipt],
    matching productIdentifiers: Set<ProductIdentifier>
  ) -> ProductIdentifier? {
    for r in receipts {
      let id = r.productIdentifier

      guard productIdentifiers.contains(id),
        !Period.subscription.isExpired(date: r.transactionDate) else {
        continue
      }
      
      return id
    }
    
    return nil
  }
  
  func validateTrial(updatingSettings: Bool = false) -> Bool {
    os_log("validating trial", log: log, type: .debug)
    
    let ts = unsealedTime
    
    if updatingSettings {
      let unsealed = Date(timeIntervalSince1970: ts)
      let expiration = Store.makeExpiration(date: unsealed, period: Period.trial)
      updateSettings(status: "Free Trial", expiration: expiration)
    }

    return !Period.trial.isExpired(date: Date(timeIntervalSince1970: ts))
  }
  
  /// Returns a tuple for updating Settings.app with subscription status name 
  /// and expiration date of the latest receipt in `receipts` or `nil` if 
  /// `receipts` is empty.
  static func makeSettingsInfo(receipts: [PodestReceipt]) -> (String, Date)? {
    let sorted = receipts.sorted { $0.transactionDate < $1.transactionDate }
    
    guard let receipt = sorted.first else {
      return nil
    }
    
    let id = receipt.productIdentifier
    let status = (id.split(separator: ".").last ?? "unknown").capitalized
    let expiration = Store.makeExpiration(
      date: receipt.transactionDate, 
      period: .subscription
    )
    
    return (status, expiration)
  }

  func validateReceipts() -> StoreState {
    let receipts = loadReceipts()
    
    os_log("validating receipts: %@", log: log, type: .debug, String(describing: receipts))

    guard let id = Store.validProductIdentifier(
      receipts, matching: productIdentifiers) else {
      return .interested(validateTrial(updatingSettings: true))
    }
    
    if let (status, expiration) = Store.makeSettingsInfo(receipts: receipts) {
      updateSettings(status: status, expiration: expiration)
    }
    
    return .subscribed(id)
  }

  // MARK: Handling Events and Managing State

  /// An internal serial queue for synchronized access.
  private let sQueue = DispatchQueue(
    label: "ink.codes.podest.Store",
    target: .global(qos: .userInitiated)
  )

  private (set) var state: StoreState {
    didSet {
      os_log(
        "new state: %{public}@, old state: %{public}@",
        log: log, type: .debug,
        state.description, oldValue.description
      )
    }
  }

  // Calling the delegate on a distinct system queue for keeping things
  // serially in order.
  var delegateQueue = DispatchQueue.global(qos: .userInitiated)

  /// Is `true` for interested users with the intention of hiding the store for customers.
  private var isAccessible: Bool = false {
    didSet {
      guard isAccessible != oldValue else {
        return
      }
      
      delegateQueue.async {
        self.subscriberDelegate?.store(self, isAccessible: self.isAccessible)
      }
    }
  }
  
  /// Updates `isAccessible` matching `state`.
  func updateIsAccessible(matching state: StoreState) -> StoreState {
    switch state {
    case .subscribed:
      isAccessible = false
    case .interested:
      isAccessible = true
    default:
      break
    }
    
    return state
  }
  
  func addPayment(matching productIdentifier: ProductIdentifier) -> StoreState {
    guard let p = product(matching: productIdentifier) else {
      delegateQueue.async {
        self.delegate?.store(self, error: .invalidProduct(productIdentifier))
      }

      return state
    }
    
    let payment = SKPayment(product: p)

    paymentQueue.add(payment)
    
    return .purchasing(productIdentifier, state)
  }
  
  func restore() -> StoreState {
    paymentQueue.restoreCompletedTransactions()
    
    return .restoring(state)
  }

  private var didChangeExternallyObserver: NSObjectProtocol?

  /// Begin observing kv-store for receipt and account changes. In both cases
  /// firing a `.receiptsChanged` event.
  private func observeUbiquitousKeyValueStore() {
    precondition(didChangeExternallyObserver == nil)

    let r = Store.receiptsKey(suiting: version.env)
    
    didChangeExternallyObserver = NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: db,
      queue: .main
    ) { notification in
      guard let info = notification.userInfo,
        let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
        return
      }
      
      switch reason {
      case NSUbiquitousKeyValueStoreAccountChange:
        os_log("push received: account change", log: log, type: .info)

        DispatchQueue.global(qos: .utility).async {
          self.event(.receiptsChanged)
        }

      case NSUbiquitousKeyValueStoreInitialSyncChange,
           NSUbiquitousKeyValueStoreServerChange:
        guard
          let keys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
          keys.contains(r) else {
          break
        }

        os_log("push received: initial sync | server change",
               log: log, type: .info)
        DispatchQueue.global(qos: .utility).async {
          self.event(.receiptsChanged)
        }

      case NSUbiquitousKeyValueStoreQuotaViolationChange:
        os_log("push received: quota violation", log: log)

      default:
        break
      }
    }
  }
  
  private func stopObservingUbiquitousKeyValueStore() {
    guard let observer = didChangeExternallyObserver else {
      return
    }

    NotificationCenter.default.removeObserver(observer)

    didChangeExternallyObserver = nil
  }

  func addObservers() -> StoreState {
    precondition(!isObserving)
    paymentQueue.add(self)
    observeUbiquitousKeyValueStore()

    return updateProducts()
  }

  func removeObservers() -> StoreState {
    precondition(isObserving)
    paymentQueue.remove(self)
    stopObservingUbiquitousKeyValueStore()
    
    return .initialized
  }

  func receiveProducts(_ products: [SKProduct], error: ShoppingError?) -> StoreState {
    self.products = products

    delegateQueue.async {
      self.delegate?.store(self, offers: products, error: error)
    }

    return updateIsAccessible(matching: validateReceipts())
  }
  
  /// Returns the next state after an `error`, overriding `nextState` in some
  /// cases.
  ///
  /// Designated to **never** prompt subscribers about their expired free trial.
  /// OK, there’s still the rare case, where users subscribed on another device
  /// and are launching the app on an offline unsynchronized device. Thoughts?
  func updatedState(after error: ShoppingError, next nextState: StoreState) -> StoreState {
    let er: ShoppingError = isReachable() ? error : .offline
    
    delegateQueue.async {
      self.delegate?.store(self, error: er)
    }
    
    if case .offline = er {
      if case .subscribed  = validateReceipts() {
        return .offline(true)
      } else {
        return .offline(validateTrial())
      }
    }
    
    return nextState
  }
  
  /// Returns the new store state after processing `event` relatively to the
  /// current state. `interested` and `subscribed` are the two main antagonistic
  /// states this finite state machine can be in. Its other states are
  /// transitional.
  ///
  /// This strict FSM **traps** on unexpected events. All switch statements must
  /// be **exhaustive**.
  ///
  /// - Parameter event: The event to handle.
  ///
  /// - Returns: The state resulting from the event.
  private func updatedState(after event: StoreEvent) -> StoreState {
    dispatchPrecondition(condition: .onQueue(sQueue))
    
    switch state {
    case .initialized:
      return Initialized(store: self)
        .reduce(state, event: event)

    case .fetchingProducts:
      return FetchingProducts(store: self)
        .reduce(state, event: event)
      
    case .offline:
      return Offline(store: self)
        .reduce(state, event: event)
      
    case .interested:
      return Interested(store: self)
        .reduce(state, event: event)

    case .subscribed:
      return Subscribed()
        .reduce(state, event: event)
    
    case let .restoring(nextState):
      return Restoring(store: self, nextState: nextState)
        .reduce(state, event: event)

    case .purchasing(let productIdentifier, let nextState):
      return Purchasing(store: self, nextState: nextState, productIdentifier: productIdentifier)
        .reduce(state, event: event)
    }
  }

  /// Synchronously handles event using `sQueue`, our event queue. Obviously,
  /// a store with one cashier works sequentially.
  func event(_ e: StoreEvent) {
    sQueue.sync {
      os_log("handling event: %{public}@", log: log, type: .debug, e.description)

      state = updatedState(after: e)
    }
  }
}

// MARK: - Shopping

extension Store: Shopping {
  public func online() {
    DispatchQueue.global(qos: .utility).async {
      self.event(.online)
    }
  }
  
  public func update() {
    DispatchQueue.global(qos: .utility).async {
      self.event(.update)
    }
  }
  
  public func resume() {
    os_log("resuming: %@", log: log, type: .debug, String(describing: version))
    DispatchQueue.global(qos: .utility).async {
      self.event(.resume)
    }
  }
  
  func pause() {
    DispatchQueue.global(qos: .utility).async {
      self.event(.pause)
    }
  }

  public func payProduct(matching productIdentifier: String) {
    DispatchQueue.global(qos: .userInitiated).async {
      self.event(.pay(productIdentifier))
    }
  }

  public var canMakePayments: Bool {
    return SKPaymentQueue.canMakePayments()
  }
  
  public func restore() {
    DispatchQueue.global().async {
      self.event(.restore)
    }
  }
}

// MARK: - Rating

extension Store: Rating {
  public func considerReview() {
    DispatchQueue.global().async {
      self.event(.considerReview)
    }
  }

  public func cancelReview(resetting: Bool) {
    DispatchQueue.global().async {
      self.event(.cancelReview(resetting))
    }
  }

  public func cancelReview() {
    DispatchQueue.global().async {
      self.event(.cancelReview(false))
    }
  }
}

// MARK: - Expiring

extension Store: Expiring {
  public func isExpired() -> Bool {
    return sQueue.sync {
      switch state {
      case .offline(let free), .interested(let free):
        let expired = !free
        
        if expired {
          // Preventing overlapping alerts.
          reviewRequester?.invalidate()
          reviewRequester = nil
        }
        
        delegateQueue.async {
          self.subscriberDelegate?.store(self, isExpired: expired)
        }
        
        return expired
      case .fetchingProducts, .initialized, .purchasing, .subscribed, .restoring:
        return false
      }
    }
  }
}
