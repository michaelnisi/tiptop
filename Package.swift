// swift-tools-version:5.5
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

import PackageDescription

let package = Package(
  name: "TipTop",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    .library(
      name: "TipTop",
      targets: ["TipTop"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "TipTop",
      dependencies: []),
    .testTarget(
      name: "TipTopTests",
      dependencies: ["TipTop"],
      resources: [.process("Resources")])
  ]
)
