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

protocol StoreReducing {
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState
}

extension StoreReducing {
  func reduce(_ state: StoreState, event: StoreEvent) -> StoreState {
    state
  }
}

struct StoreReducer: StoreReducing {
  let store: Store
}
