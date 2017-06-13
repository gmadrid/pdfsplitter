//
//  Errors.swift
//  pdfsplitter
//
//  Created by George Madrid on 6/13/17.
//  Copyright © 2017 George Madrid. All rights reserved.
//

import Foundation

enum Errors : Error {
  case CouldntOpenPdfToRead(url: URL)
  case FailedToCreateGraphicsContext
  case FailedToCropImage
  case FailedToOpenPage(pageNum: Int)
  case FailedToRenderImage
  case NoCurrentDocument
}
