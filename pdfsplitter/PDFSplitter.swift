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

class PDFSplitter {
  // Sequence of images and page numbers for the current page.
  var pageImage: BehaviorSubject<(CGImage?, Int?)> = BehaviorSubject(value: (nil, nil))
  
  private let disposeBag = DisposeBag();

  private let pdf: CGPDFDocument
  private var page: BehaviorSubject<CGPDFPage>;
  
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
    page = BehaviorSubject(value: try PDFSplitter.readPage(at: 1, from:pdf))
    page.asObservable().subscribe(onNext: { [weak self] p in
      self?.pageOnNext(p)
    }).disposed(by: disposeBag)
  }
  
  private func pageOnNext(_ page: CGPDFPage) {
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
      
      pageImage.onNext((cgimage, page.pageNumber))
    } catch {
      pageImage.onNext((nil, nil))
    }
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
    page.onNext(try PDFSplitter.readPage(at: pageNum, from: pdf))
  }
  
  func nextPage() throws {
    try gotoPage(page.value().pageNumber + 1)
  }
  
  func prevPage() throws {
    try gotoPage(page.value().pageNumber - 1)
  }
}
