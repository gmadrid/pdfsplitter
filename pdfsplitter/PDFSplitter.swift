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
  let disposeBag = DisposeBag()
  let pageImage_: Observable<CGImage?>
  var numberOfPages_: Observable<Int> { return numberOfPages__.asObservable() }
  var pageNumber_: Observable<Int> { return pageNumber__.asObservable() }
  let leftPageImage_: Observable<CGImage?>
  let rightPageImage_: Observable<CGImage?>

  private let pdf_: Observable<CGPDFDocument>
  private let pageNumber__: Variable<Int>
  private let numberOfPages__: Variable<Int>
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf: CGPDFDocument) throws {
    pdf_ = Observable.just(pdf)
    numberOfPages__ = Variable(pdf.numberOfPages)
    
    pageNumber__ = Variable(1) // pdf pages start numbering at 1
    
    pageImage_ = Observable.combineLatest(pdf_, numberOfPages__.asObservable(), pageNumber__.asObservable()) {
      return ($0, $1, $2)
      }
      .filter { (pdf, numberOfPages, pageNumber) in
        return 1...numberOfPages ~= pageNumber
      }
      .map { (pdf, numberOfPages, pageNumber) -> CGPDFPage? in
        return pdf.page(at: pageNumber)
      }
      .map { page in
        guard let page = page else { return nil }
        return PDFSplitter.makeImageForPage(page)
    }
    
    leftPageImage_ = pageImage_.map { image in
      guard let image = image else { return nil }
      return PDFSplitter.makeLeftImageFromImage(image)
    }
    
    rightPageImage_ = pageImage_.map { image in
      guard let image = image else { return nil }
      return PDFSplitter.makeRightImageFromImage(image)
    }
  }

  private static func makeImageForPage(_ page: CGPDFPage) -> CGImage? {
    let mediaBox = page.getBoxRect(.mediaBox)
    let destBox = CGRect(origin: CGPoint.zero, size: mediaBox.size)
    
      guard let context = CGContext(data: nil, width: Int(destBox.size.width), height: Int(destBox.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
        return nil
      }
      
      context.drawPDFPage(page)
      
      guard let cgimage = context.makeImage() else {
        return nil
      }
      
      return cgimage
  }
  
  static func makeLeftImageFromImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
  
  static func makeRightImageFromImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
  
  func nextPage() {
    if pageNumber__.value < numberOfPages__.value {
      pageNumber__.value = pageNumber__.value + 1
    }
  }
  
  func prevPage() {
    if pageNumber__.value > 1 {
      pageNumber__.value = pageNumber__.value - 1
    }
  }
}
