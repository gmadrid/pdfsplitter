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

enum VCError : Error {
  case CouldntOpenPdfToRead(url: URL)
  case FailedToCreateGraphicsContext
  case FailedToCropImage
  case FailedToOpenPage(pageNum: Int)
  case FailedToRenderImage
  case NoCurrentDocument
}

class ViewController: NSViewController {
  @IBOutlet var filenameField: NSTextField!
  @IBOutlet var pageNumberField: NSTextField!
  @IBOutlet var originalImageView: NSImageView!
  @IBOutlet var leftImageView: NSImageView!
  @IBOutlet var rightImageView: NSImageView!
  
  var pdfUrl: URL?

  var document: CGPDFDocument?
  var numberOfPages: size_t = 0
  
  var currentPage: CGPDFPage?
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
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
        return
      }
      do {
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
    guard let doc = document, let page = currentPage else {
      return
    }
    
    if page.pageNumber < doc.numberOfPages {
      do {
        try gotoPage(page.pageNumber + 1)
      } catch {
        // XXX ERR
      }
    }
  }
  
  @IBAction func prevPagePushed(sender: NSButton) {
    guard let page = currentPage else {
      return
    }
    
    if page.pageNumber > 1 {
      do {
        try gotoPage(page.pageNumber - 1)
      } catch {
        // XXX ERR
      }
    }
  }
  
  @IBAction func splitPushed(sender: NSButton) {
    guard document != nil else {
      return
    }

    let dialog = NSSavePanel()
    dialog.title = "Save the .pdf file"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.canCreateDirectories = true
    dialog.allowedFileTypes = ["pdf"]
    
    if dialog.runModal() != NSModalResponseOK {
      return
    }
    
    guard let url = dialog.url else {
      return
    }

    try! splitCurrentDocument(url)
  }
  
  func splitCurrentDocument(_ destUrl: URL) throws {
    let doc = try checkForCurrentDocument()
    
    guard let firstPage = doc.page(at: 1) else {
      return
    }
    let mediaBox = firstPage.getBoxRect(.mediaBox)
    var docBox = CGRect(origin: mediaBox.origin, size: CGSize(width: mediaBox.size.width / 2, height: mediaBox.size.height))

    guard let context = CGContext(destUrl as CFURL, mediaBox: &docBox, nil) else {
      return
    }

    for pageNum in 1...doc.numberOfPages {
      let page = try getPageFromDocument(pageNum, fromDoc: doc)
      
      let image = try imageForPage(page)
      let leftImage = try leftImageForImage(image)
      let rightImage = try rightImageForImage(image)
      
      let leftPageRect = CGRect(origin: CGPoint.zero, size: CGSize(width: leftImage.width, height: leftImage.height))
      let leftPageDict: [String:Any] = [
        kCGPDFContextMediaBox as String: leftPageRect
      ]
      context.beginPDFPage(leftPageDict as CFDictionary)
      context.draw(leftImage, in: leftPageRect)
      context.endPage()
      
      let rightPageRect = CGRect(origin: CGPoint.zero, size: CGSize(width: rightImage.width, height: rightImage.height))
      let rightPageDict: [String:Any] = [
        kCGPDFContextMediaBox as String: rightPageRect
      ]
      context.beginPDFPage(rightPageDict as CFDictionary)
      context.draw(rightImage, in: rightPageRect)
      context.endPage()
    }
  }
  
  func openFile(_ fileURL: URL) throws {
    closeFile();
    
    pdfUrl = fileURL
    filenameField.stringValue = fileURL.path
    
    guard let doc = CGPDFDocument(fileURL as CFURL) else {
      throw VCError.CouldntOpenPdfToRead(url: fileURL)
    }
    
    document = doc
    numberOfPages = doc.numberOfPages
    
    try gotoPage(1)
  }
  
  func closeFile() {
    pdfUrl = nil
    filenameField.stringValue = ""
    numberOfPages = 0
    currentPage = nil
    document = nil
  }
  
  func checkForCurrentDocument() throws -> CGPDFDocument {
    guard let doc = document else {
      throw VCError.NoCurrentDocument
    }
    return doc
  }
  
  func getPageFromDocument(_ pageNum: Int, fromDoc doc: CGPDFDocument) throws -> CGPDFPage {
    guard let page = doc.page(at: pageNum) else {
      throw VCError.FailedToOpenPage(pageNum: pageNum)
    }
    return page
  }
  
  func gotoPage(_ pageNum: size_t) throws {
    let doc = try checkForCurrentDocument()
    let page = try getPageFromDocument(pageNum, fromDoc: doc)
    
    let pageDisplay = String(format: "Page %d of %d", pageNum, doc.numberOfPages)
    pageNumberField.stringValue = pageDisplay
    
    currentPage = page;
    do {
      let cgimage = try imageForPage(page)
      originalImageView.image = NSImage(cgImage: cgimage, size: CGSize(width: cgimage.width, height: cgimage.height))
      
      do {
        let leftImage = try leftImageForImage(cgimage)
        leftImageView.image = NSImage(cgImage: leftImage, size: CGSize(width: leftImage.width, height: leftImage.height))
        let rightImage = try rightImageForImage(cgimage)
        rightImageView.image = NSImage(cgImage: rightImage, size: CGSize(width: rightImage.width, height: rightImage.height))
      } catch {
        leftImageView.image = nil
        rightImageView.image = nil
      }
    } catch {
      originalImageView.image = nil
      leftImageView.image = nil
      rightImageView.image = nil
    }
  }
  
  func imageForPage(_ page: CGPDFPage) throws -> CGImage {
    let mediaBox = page.getBoxRect(.mediaBox)
    let destBox = CGRect(origin: CGPoint.zero, size: CGSize(width: mediaBox.size.width * 1, height: mediaBox.size.height * 1))
    
    guard let context = CGContext(data: nil, width: Int(destBox.size.width), height: Int(destBox.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
      throw VCError.FailedToCreateGraphicsContext
    }
    
    context.drawPDFPage(page)
    
    guard let cgimage = context.makeImage() else {
      throw VCError.FailedToRenderImage
    }
    return cgimage
  }
  
  func leftImageForImage(_ image: CGImage) throws -> CGImage {
    let rect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    guard let result = image.cropping(to: rect) else {
      throw VCError.FailedToCropImage
    }
    return result
  }
  
  func rightImageForImage(_ image: CGImage) throws -> CGImage {
    let rect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
    guard let result = image.cropping(to: rect) else {
      throw VCError.FailedToCropImage
    }
    return result
  }
}

