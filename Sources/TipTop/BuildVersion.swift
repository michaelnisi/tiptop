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

/// Version and environment of a bundle.
public struct BuildVersion {
  /// Enumerates three possible bundle environments.
  enum Environment {
    case store, sandbox, simulator
    
    /// Creates a new informal environment using `bundle`.
    init(bundle: Bundle) {
      #if targetEnvironment(simulator)
      self = .simulator
      #else
      let c = bundle.appStoreReceiptURL?.lastPathComponent
      self = c == "sandboxReceipt" ? .sandbox : .store
      #endif
    }
  }

  /// The bundle version.
  let build: String

  /// The bundle environment.
  let env: Environment

  /// Creates a new version.
  ///
  /// - Parameter bundle: The bundle to draw version from.
  ///
  /// If this returns `nil`, the main bundle has no version.
  public init(bundle: Bundle = .main) {
    dispatchPrecondition(condition: .onQueue(.main))

    let infoDictionaryKey = kCFBundleVersionKey as String

    guard let build = bundle.object(
      forInfoDictionaryKey: infoDictionaryKey) as? String else {
      fatalError("bundle version not found")
    }

    self.build = build
    self.env = Environment(bundle: bundle)
  }
}

extension BuildVersion: CustomStringConvertible {
  public var description: String {
    "BuildVersion: ( \(env), \(build) )"
  }
}
