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

public extension UserDefaults {
  static var lastVersionPromptedForReviewKey = "ink.codes.podest.lastVersionPromptedForReview"

  var lastVersionPromptedForReview: String? {
    string(forKey: UserDefaults.lastVersionPromptedForReviewKey)
  }

  static func registerDefaults(_ user: UserDefaults = UserDefaults.standard) {
    user.register(defaults: [
      lastVersionPromptedForReviewKey: "0"
    ])
  }
}

extension UserDefaults {
  static var statusKey = "ink.codes.podest.status"
  static var expirationKey = "ink.codes.podest.expiration"
}

