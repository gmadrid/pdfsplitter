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
  let pageImage_: Observable<CGImage?>
  let numberOfPages_: Observable<Int>
  let pageNumber_: Variable<Int>
  let leftPageImage_: Observable<CGImage?>
  let rightPageImage_: Observable<CGImage?>

  private let disposeBag = DisposeBag()
  private let pdf_: Observable<CGPDFDocument> 
  
  convenience init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: url)
    }
    try self.init(pdf: document)
  }
  
  init(pdf: CGPDFDocument) throws {
    pdf_ = Observable.just(pdf)
    numberOfPages_ = pdf_.map { return $0.numberOfPages }
    
    pageNumber_ = Variable(1) // pdf pages start numbering at 1
    
    pageImage_ = Observable.combineLatest(pdf_, numberOfPages_, pageNumber_.asObservable()) {
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
  
  static func makeLeftImageFromImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
  
  static func makeRightImageFromImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
  
//  func nextPage() {
//    guard pageNumberS.value < _numberOfPagesS.value else { return }
//    pageNumberS.value = pageNumberS.value + 1
//  }
//  
//  func prevPage() {
//    guard pageNumberS.value > 1 else { return }
//    pageNumberS.value = pageNumberS.value - 1
//  }
}
