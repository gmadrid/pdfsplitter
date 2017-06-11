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
  // Sequence of images and page numbers for the current page.
  var pageDetailsS: BehaviorSubject<(CGImage?, Int?)>
  /** Sequence of total number of pages. */
  var numberOfPagesS: BehaviorSubject<Int>
  
  private let disposeBag = DisposeBag();
  private let pdfS: Observable<CGPDFDocument>
  private let pageNumberS: BehaviorSubject<Int>
  private var pageS: BehaviorSubject<CGPDFPage>
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf document: CGPDFDocument) throws {
//    self.pdfS = BehaviorSubject(value: document)
    self.pdfS = Observable.just(document).shareReplay(1)
    self.pageNumberS = BehaviorSubject(value: 1)

    self.numberOfPagesS = BehaviorSubject(value: document.numberOfPages)
    
    let initialPage = try PDFSplitter.readPage(at: pageNumberS.value(), from: document)
    let pageS = BehaviorSubject(value: initialPage)
    Observable.combineLatest(pdfS, pageNumberS) { p, pn in
      return try! PDFSplitter.readPage(at: pn, from: p)
      }
      .bind(to: pageS)
      .disposed(by: disposeBag)
    self.pageS = pageS
      
    let pageDetailsS: BehaviorSubject<(CGImage?, Int?)> = BehaviorSubject(value: (nil, nil))
    pageS.map { page in
      return (PDFSplitter.makeImageForPage(page), page.pageNumber)
      }
      .bind(to: pageDetailsS)
      .disposed(by: disposeBag)
    self.pageDetailsS = pageDetailsS
  }
  
  private static func makeImageForPage(_ page: CGPDFPage) -> CGImage? {
    let mediaBox = page.getBoxRect(.mediaBox)
    let destBox = CGRect(origin: CGPoint.zero, size: CGSize(width: mediaBox.size.width * 1, height: mediaBox.size.height * 1))
    
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
  
  func gotoPage(_ pageNum: Int) throws {
    pageNumberS.onNext(pageNum)
  }
  
  func nextPage() throws {
    try gotoPage(pageNumberS.value() + 1)
  }
  
  func prevPage() throws {
    try gotoPage(pageNumberS.value() - 1)
  }
}
