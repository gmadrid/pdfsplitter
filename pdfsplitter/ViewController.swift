//
//  ViewController.swift
//  pdfsplitter
//
//  Created by George Madrid on 6/6/17.
//  Copyright © 2017 George Madrid. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage
import RxSwift

enum VCError : Error {
  case CouldntOpenPdfToRead(url: URL)
  case FailedToCreateGraphicsContext
  case FailedToCropImage
  case FailedToOpenPage(pageNum: Int)
  case FailedToRenderImage
  case NoCurrentDocument
  case PageOutOfRange(pageNum: Int)
}

class ViewController: NSViewController {
  @IBOutlet var filenameField: NSTextField!
  @IBOutlet var pageNumberField: NSTextField!
  @IBOutlet var originalImageView: NSImageView!
  @IBOutlet var leftImageView: NSImageView!
  @IBOutlet var rightImageView: NSImageView!
  
  @IBOutlet var nextPageButton: NSButton!
  
  private let disposeBag = DisposeBag()
  
  var splitter: PDFSplitter? {
    didSet {
      guard let s = splitter else { return }
      
      s.pageDetailsS.subscribe(onNext: { [weak self] (image, pageNumber) in
        guard let _self = self, let image = image, let pageNumber = pageNumber else {
          self?.originalImageView.image = nil
          self?.leftImageView.image = nil
          self?.rightImageView.image = nil
          return
        }

        _self.originalImageView.image =
          NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        
        // XXX !!! TODO get the number of pages here.
        let pageDisplay = String(format: "Page %d of %d", pageNumber, 100)
        self?.pageNumberField.stringValue = pageDisplay

        do {
          let leftImage = try ViewController.leftImageForImage(image)
          let nsi = NSImage(cgImage: leftImage, size: CGSize(width: leftImage.width, height: leftImage.height))
          _self.leftImageView.image = nsi
        } catch {
          _self.leftImageView.image = nil
        }
        
        do {
          let rightImage = try ViewController.rightImageForImage(image)
          let nsi = NSImage(cgImage: rightImage, size: CGSize(width: rightImage.width, height: rightImage.height))
          _self.rightImageView.image = nsi
        } catch {
          _self.rightImageView = nil
        }
        
      })
      .disposed(by: disposeBag)
    }
  }
  
  var pdfUrl: URL?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    let url = URL(string: "file:///Users/gmadrid/Dropbox/Sonata%20-%20Juan%20Tamariz.pdf")
    if url != nil {
      try! openFile(url!)
    }
  }
  
  
  
  //  func updatePage() throws {
  //    let doc = try requireSplitter()
  //
  //    let pageDisplay = String(format: "Page %d of %d", doc.pageNumber, doc.numberOfPages)
  //    pageNumberField.stringValue = pageDisplay
  //
  //    let page = doc.page
  //    let cgimage = try imageForPage(page)
  //    let leftImage = try leftImageForImage(cgimage)
  //    let rightImage = try rightImageForImage(cgimage)
  //
  //    // XXX TODO !!! error handling
  //    originalImageView.image = imageForCGImage(cgimage: cgimage)
  //    leftImageView.image = imageForCGImage(cgimage: leftImage)
  //    rightImageView.image = imageForCGImage(cgimage: rightImage)
  //  }
  
  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }
  
  @IBAction func openFilePushed(sender: NSButton) {
    let dialog = NSOpenPanel()
    
    dialog.title = "Choose a .pdf file"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.canChooseDirectories = false
    dialog.canChooseFiles = true
    dialog.canCreateDirectories = false
    dialog.allowsMultipleSelection = false
    dialog.allowedFileTypes = ["pdf"]
    
    if (dialog.runModal() == NSModalResponseOK) {
      guard let url = dialog.url else {
        // !!! ERR XXX
        return
      }
      do {
        print(url)
        try openFile(url)
      } catch {
        // DO SOMETHING HERE TODO !!! XXX
      }
    } else {
      // User clicked "Cancel"
      return
    }
  }
  
  @IBAction func nextPagePushed(sender: NSButton) {
    // You should probably do something more graceful than throwing here.
    // At least disable the button.
    do {
      let s = try requireSplitter()
      try s.nextPage()
    } catch {
      // XXX ERR
    }
  }
  
  @IBAction func prevPagePushed(sender: NSButton) {
    do {
      let s = try requireSplitter()
      try s.prevPage()
    } catch {
      // XXX ERR
    }
  }
  
  @IBAction func splitPushed(sender: NSButton) {
    //    guard document != nil else {
    //      return
    //    }
    //
    //    let dialog = NSSavePanel()
    //    dialog.title = "Save the .pdf file"
    //    dialog.showsResizeIndicator = true
    //    dialog.showsHiddenFiles = false
    //    dialog.canCreateDirectories = true
    //    dialog.allowedFileTypes = ["pdf"]
    //
    //    if dialog.runModal() != NSModalResponseOK {
    //      return
    //    }
    //
    //    guard let url = dialog.url else {
    //      return
    //    }
    //
    //    try! splitCurrentDocument(url)
  }
  
  //  func splitCurrentDocument(_ destUrl: URL) throws {
  //    let doc = try checkForCurrentDocument()
  //
  //    guard let firstPage = doc.page(at: 1) else {
  //      return
  //    }
  //    let mediaBox = firstPage.getBoxRect(.mediaBox)
  //    var docBox = CGRect(origin: mediaBox.origin, size: CGSize(width: mediaBox.size.width / 2, height: mediaBox.size.height))
  //
  //    guard let context = CGContext(destUrl as CFURL, mediaBox: &docBox, nil) else {
  //      return
  //    }
  //
  //    for pageNum in 1...doc.numberOfPages {
  //      let page = try getPageFromDocument(pageNum, fromDoc: doc)
  //
  //      let image = try imageForPage(page)
  //      let leftImage = try leftImageForImage(image)
  //      let rightImage = try rightImageForImage(image)
  //
  //      let leftPageRect = CGRect(origin: CGPoint.zero, size: CGSize(width: leftImage.width, height: leftImage.height))
  //      let leftPageDict: [String:Any] = [
  //        kCGPDFContextMediaBox as String: leftPageRect
  //      ]
  //      context.beginPDFPage(leftPageDict as CFDictionary)
  //      context.draw(leftImage, in: leftPageRect)
  //      context.endPage()
  //
  //      let rightPageRect = CGRect(origin: CGPoint.zero, size: CGSize(width: rightImage.width, height: rightImage.height))
  //      let rightPageDict: [String:Any] = [
  //        kCGPDFContextMediaBox as String: rightPageRect
  //      ]
  //      context.beginPDFPage(rightPageDict as CFDictionary)
  //      context.draw(rightImage, in: rightPageRect)
  //      context.endPage()
  //    }
  //  }
  
  func openFile(_ fileURL: URL) throws {
    closeFile();
    
    pdfUrl = fileURL
    filenameField.stringValue = fileURL.path
    
    splitter = try PDFSplitter(url: fileURL)
  }
  
  func closeFile() {
    pdfUrl = nil
    filenameField.stringValue = ""
    originalImageView.image = nil
    leftImageView.image = nil
    rightImageView.image = nil
    splitter = nil
  }
  
  func requireSplitter() throws -> PDFSplitter {
    guard let s = splitter else {
      throw VCError.NoCurrentDocument
    }
    return s
  }
  
  func getPageFromDocument(_ pageNum: Int, fromDoc doc: CGPDFDocument) throws -> CGPDFPage {
    guard let page = doc.page(at: pageNum) else {
      throw VCError.FailedToOpenPage(pageNum: pageNum)
    }
    return page
  }
  
  func imageForCGImage(cgimage: CGImage) -> NSImage? {
    return NSImage(cgImage: cgimage, size: CGSize(width: cgimage.width, height: cgimage.height))
  }
  
  //  func imageForPage(_ page: CGPDFPage) throws -> CGImage {
  //    let mediaBox = page.getBoxRect(.mediaBox)
  //    let destBox = CGRect(origin: CGPoint.zero, size: CGSize(width: mediaBox.size.width * 1, height: mediaBox.size.height * 1))
  //
  //    guard let context = CGContext(data: nil, width: Int(destBox.size.width), height: Int(destBox.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
  //      throw VCError.FailedToCreateGraphicsContext
  //    }
  //
  //    context.drawPDFPage(page)
  //
  //    guard let cgimage = context.makeImage() else {
  //      throw VCError.FailedToRenderImage
  //    }
  //    return cgimage
  //  }
  
  static func leftImageForImage(_ image: CGImage) throws -> CGImage {
    let rect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    guard let result = image.cropping(to: rect) else {
      throw VCError.FailedToCropImage
    }
    return result
  }
  
  static func rightImageForImage(_ image: CGImage) throws -> CGImage {
    let rect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
    guard let result = image.cropping(to: rect) else {
      throw VCError.FailedToCropImage
    }
    return result
  }
}

