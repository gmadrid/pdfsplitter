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
  var pageImage: Observable<(CGImage?, Int?)>
  var numberOfPages: Observable<Int>
  
  private let disposeBag = DisposeBag();
  private let pdf: Observable<CGPDFDocument>
  private let pageNumber: BehaviorSubject<Int>
  private let page: Observable<CGPDFPage>
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf document: CGPDFDocument) throws {
    self.pdf = Observable.just(document).replay(1)
    self.pageNumber = BehaviorSubject(value: 1)
    self.numberOfPages = pdf.map({ return $0.numberOfPages })
    
    self.page = Observable.combineLatest(pdf, pageNumber)
      .map { (pdf, pageNumber) in
        print("MAPPING PAGE")
        return try! PDFSplitter.readPage(at: pageNumber, from: pdf)
    }
    
    self.pageImage = page.map({ page in
      print("MAPPING PAGEIMAGE")
        return (PDFSplitter.makeImageForPage(page), page.pageNumber)
    }).startWith((nil, nil)).replay(1)
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
    pageNumber.onNext(pageNum)
  }
  
  func nextPage() throws {
    print("NEXT PAGE")
    try gotoPage(pageNumber.value() + 1)
  }
  
  func prevPage() throws {
    try gotoPage(pageNumber.value() - 1)
  }
}
