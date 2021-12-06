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

extension UserDefaults {
  static var statusKey = "ink.codes.podest.status"
  static var expirationKey = "ink.codes.podest.expiration"
  static var lastVersionPromptedForReviewKey = "ink.codes.podest.lastVersionPromptedForReview"
}

public extension UserDefaults {
  var lastVersionPromptedForReview: String? {
    get { string(forKey: UserDefaults.lastVersionPromptedForReviewKey) }
    set { set(newValue, forKey: UserDefaults.lastVersionPromptedForReviewKey) }
  }

  static func registerTipTopDefaults(_ user: UserDefaults = UserDefaults.standard) {
    user.register(defaults: [
      lastVersionPromptedForReviewKey: "0"
    ])
  }
}


