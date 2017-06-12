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
import RxCocoa
import RxSwift

enum VCError : Error {
  case CouldntOpenPdfToRead(url: URL)
//  case FailedToCreateGraphicsContext
//  case FailedToCropImage
//  case FailedToOpenPage(pageNum: Int)
//  case FailedToRenderImage
  case NoCurrentDocument
//  case PageOutOfRange(pageNum: Int)
}

extension NSImage {
  convenience init?(cgimage: CGImage?) {
    guard let cgimage = cgimage else { return nil }
    self.init(cgImage: cgimage, size: CGSize.zero)
  }
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
      
      s.pageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: originalImageView.rx.image)
        .disposed(by: disposeBag)
      
      s.leftPageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: leftImageView.rx.image)
        .disposed(by: disposeBag)
      
      s.rightPageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: rightImageView.rx.image)
        .disposed(by: disposeBag)
      
      Observable.combineLatest(s.pageNumber_.asObservable(), s.numberOfPages_) {
        return String(format: "Page %d of %d", $0, $1)
        }
        .bind(to:pageNumberField.rx.text)
        .disposed(by: disposeBag)
    }
  }
  
  var pdfUrl: URL?
    
  static func NSImageFromCGImage(_ cgimage: CGImage?) -> NSImage? {
    guard let cgimage = cgimage else { return nil }
    return NSImage(cgImage: cgimage, size: CGSize.zero)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    let url = URL(string: "file:///Users/gmadrid/Dropbox/Sonata%20-%20Juan%20Tamariz.pdf")
    if url != nil {
      try! openFile(url!)
    }
  }
  
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
      s.nextPage()
    } catch {
      // XXX ERR
    }
  }
  
  @IBAction func prevPagePushed(sender: NSButton) {
    do {
      let s = try requireSplitter()
      s.prevPage()
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
}

