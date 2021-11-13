// This source file is part of the TipTop open source project
//
// Copyright (c) 2021 Michael Nisi and collaborators
// Licensed under MIT License
//
// See https://github.com/michaelnisi/tiptop/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

import StoreKit

/// Enumerates possible presentation layer error types, grouping StoreKit and
/// other errors into five simplified buckets.
public enum ShoppingError: Error {
  case invalidProduct(String?)
  case offline
  case serviceUnavailable
  case cancelled
  case failed

  init(underlyingError: Error, productIdentifier: String? = nil, restoring: Bool = false) {
    switch underlyingError {
    case let skError as SKError:
      switch skError.code {
      case .clientInvalid,
           .unknown,
           .paymentInvalid,
           .paymentNotAllowed,
           .privacyAcknowledgementRequired,
           .unauthorizedRequestData,
           .unsupportedPlatform,
           .overlayPresentedInBackgroundScene:
        self = .failed
        
      case .cloudServicePermissionDenied,
           .cloudServiceRevoked:
        self = .serviceUnavailable
        
      case .cloudServiceNetworkConnectionFailed:
        self = .offline
        
      case .paymentCancelled:
        self = .cancelled
        
      case .storeProductNotAvailable,
           .invalidOfferIdentifier,
           .invalidOfferPrice,
           .missingOfferParams,
           .ineligibleForOffer,
           .overlayTimeout,
           .overlayCancelled,
           .overlayInvalidConfiguration,
           .invalidSignature:
        self = .invalidProduct(productIdentifier)
          
      @unknown default:
        fatalError("unknown case in switch: \(skError.code)")
      }
      
    default:
      let nsError = underlyingError as NSError
      
      let domain = nsError.domain
      let code = nsError.code
      
      switch  (domain, code) {
      case (NSURLErrorDomain, -1001), (NSURLErrorDomain, -1005):
        self = .serviceUnavailable
        
      default:
        self = .failed
      }
    }
  }
}
