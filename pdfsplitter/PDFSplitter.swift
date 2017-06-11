//
//  PDFSplitter.swift
//  pdfsplitter
//
//  Created by George Madrid on 6/8/17.
//  Copyright © 2017 George Madrid. All rights reserved.
//

import CoreGraphics
import Foundation
import RxSwift
import RxCocoa

class PDFSplitter {
  /** Sequence of images and page numbers for the current page. */
  var pageDetailsS: Observable<(CGImage?, Int?)>
  
  /** Sequence of total number of pages. */
  private var _numberOfPagesS = Variable<Int>(0)
  
  private let disposeBag = DisposeBag()
  private let pdfS: Observable<CGPDFDocument>
  private var pageS: Observable<CGPDFPage>
  // TODO: As a pedagogical exercise, see if you can get rid of this variable.
  private let pageNumberS: Variable<Int>
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf document: CGPDFDocument) throws {
    self.pdfS = Observable.just(document)
    pdfS.map { $0.numberOfPages }.bind(to: self._numberOfPagesS).disposed(by: disposeBag)

    self.pageNumberS = Variable(1)

    self.pageS = Observable.combineLatest(pdfS, _numberOfPagesS.asObservable(), pageNumberS.asObservable()) {
      return ($0, $1, $2)
      }
      .filter() { (pdf, numberOfPages, pageNumber) in
        return 1...numberOfPages ~= pageNumber
      }
      .map() { (page, numberOfPages, pageNumber) in
        return try PDFSplitter.readPage(at: pageNumber, from: page)
    }
    
    self.pageDetailsS = pageS.map { page in
      return (PDFSplitter.makeImageForPage(page), page.pageNumber)
      }
      .catchErrorJustReturn((nil, nil))
  }
  
  private static func makeImageForPage(_ page: CGPDFPage) -> CGImage? {
    let mediaBox = page.getBoxRect(.mediaBox)
    let destBox = CGRect(origin: CGPoint.zero, size: mediaBox.size)
    
    do {
      guard let context = CGContext(data: nil, width: Int(destBox.size.width), height: Int(destBox.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
        throw VCError.FailedToCreateGraphicsContext
      }
      
      context.drawPDFPage(page)
      
      guard let cgimage = context.makeImage() else {
        throw VCError.FailedToRenderImage
      }
      
      return cgimage
    } catch {
      return nil
    }
  }
  
  private static func readPage(at pageNum: Int, from pdf: CGPDFDocument) throws -> CGPDFPage {
    guard let result = pdf.page(at: pageNum) else {
      throw VCError.FailedToOpenPage(pageNum: pageNum)
    }
    return result
  }
  
  func nextPage() {
    guard pageNumberS.value < _numberOfPagesS.value else { return }
    pageNumberS.value = pageNumberS.value + 1
  }
  
  func prevPage() {
    guard pageNumberS.value > 1 else { return }
    pageNumberS.value = pageNumberS.value - 1
  }
}
