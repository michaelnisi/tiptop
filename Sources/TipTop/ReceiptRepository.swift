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

class ReceiptRepository {
  /// Returns different key for store and sandbox `environment`.
  private static func receiptsKey(suiting environment: BuildVersion.Environment) -> String {
    environment == .sandbox ? "receiptsSandbox" : "receipts"
  }
  
  /// The version of the app.
  private let version: BuildVersion
  /// A date formatting block.
  public var formatDate: ((Date) -> String)?
  
  /// The (default) iCloud key-value store object.
  private let db: NSUbiquitousKeyValueStore
  
  static var unsealedKey = "ink.codes.podest.store.unsealed"
  
  public init(
    db: NSUbiquitousKeyValueStore = .default,
    version: BuildVersion = BuildVersion()
  ) {
    self.db = db
    self.version = version
  }
  
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
  
  public func removeReceipts(forcing: Bool = false) -> Bool {
    switch (version.env, forcing) {
    case (.sandbox, _), (.store, true), (.simulator, _):
      os_log("removing receipts", log: log)
      db.removeObject(forKey: ReceiptRepository.receiptsKey(suiting: version.env))
      ReceiptRepository.unseal(db, env: version.env)
      
      return true
      
    case (.store, _):
      os_log("not removing production receipts without force", log: log)
      
      return false
    }
  }

  private func loadReceipts() -> [PodestReceipt] {
    dispatchPrecondition(condition: .notOnQueue(.main))

    let r = ReceiptRepository.receiptsKey(suiting: version.env)

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
    let r = ReceiptRepository.receiptsKey(suiting: version.env)

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
      let expiration = ReceiptRepository.makeExpiration(date: unsealed, period: Period.trial)
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

  func validateReceipts(productIdentifiers: Set<String>) -> StoreState {
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
}
