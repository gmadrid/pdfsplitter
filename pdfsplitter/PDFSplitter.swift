//
//  PDFSplitter.swift
//  pdfsplitter
//
//  Created by George Madrid on 6/8/17.
//  Copyright © 2017 George Madrid. All rights reserved.
//

import CoreGraphics
import Foundation

class PDFSplitter {
  let pdf: CGPDFDocument

  private(set) var page: CGPDFPage
  private(set) var pageNumber: Int = 1
  var numberOfPages: Int {
    get { return pdf.numberOfPages }
  }
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf: CGPDFDocument) throws {
    self.pdf = pdf
    pageNumber = 1
    page = try PDFSplitter.readPage(at: pageNumber, from:pdf)
  }
  
  private static func readPage(at pageNum: Int, from pdf: CGPDFDocument) throws -> CGPDFPage {
    guard let result = pdf.page(at: pageNum) else {
      throw VCError.FailedToOpenPage(pageNum: pageNum)
    }
    return result
  }
  
  func gotoPage(_ pageNum: Int) throws {
    if pageNum < 1 || pageNum > pdf.numberOfPages {
      throw VCError.PageOutOfRange(pageNum: pageNum)
    }
    page = try PDFSplitter.readPage(at: pageNum, from: pdf)
    pageNumber = pageNum
  }
}
