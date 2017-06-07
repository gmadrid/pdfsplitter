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
      openFile(url)
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
      gotoPage(page.pageNumber + 1)
    }
  }
  
  @IBAction func prevPagePushed(sender: NSButton) {
    guard let page = currentPage else {
      return
    }
    
    if page.pageNumber > 1 {
      gotoPage(page.pageNumber - 1)
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
    
    
    
    splitCurrentDocument(url)
  }
  
  func splitCurrentDocument(_ destUrl: URL) {
    guard let doc = document else {
      return
    }
    
    guard let firstPage = doc.page(at: 1) else {
      return
    }
    let mediaBox = firstPage.getBoxRect(.mediaBox)
    var docBox = CGRect(origin: mediaBox.origin, size: CGSize(width: mediaBox.size.width / 2, height: mediaBox.size.height))

    guard let context = CGContext(destUrl as CFURL, mediaBox: &docBox, nil) else {
      return
    }

    for pageNum in 1...doc.numberOfPages {
      guard let page = doc.page(at: pageNum) else {
        print("Failed to load page: ", pageNum)
        return
      }
      
      guard let image = imageForPage(page) else {
        print("Failed to get image for page", pageNum)
        return
      }
      guard let leftImage = leftImageForImage(image) else {
        print("Failed to get left image for page", pageNum)
        return
      }
      
      guard let rightImage = rightImageForImage(image) else {
        print("Failed to get right image for page", pageNum)
        return
      }
     
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
  
  func openFile(_ fileURL: URL) {
    closeFile();
    
    pdfUrl = fileURL
    filenameField.stringValue = fileURL.path
    
    guard let doc = CGPDFDocument(fileURL as CFURL) else {
      NSLog("Failed to open pdf.");
      return
    }
    
    document = doc
    numberOfPages = doc.numberOfPages
    
    gotoPage(1)
  }
  
  func closeFile() {
    pdfUrl = nil
    filenameField.stringValue = ""
    numberOfPages = 0
    currentPage = nil
    document = nil
  }
  
  func gotoPage(_ pageNum: size_t) {
    guard let doc = document else {
      return
    }
    guard let page = doc.page(at: pageNum) else {
      NSLog("Couldn't open page.")
      return
    }
    
    let pageDisplay = String(format: "Page %d of %d", pageNum, doc.numberOfPages)
    pageNumberField.stringValue = pageDisplay
    
    currentPage = page;
    let image = imageForPage(page)
    if let cgimage = image {
      originalImageView.image = NSImage(cgImage: cgimage, size: CGSize(width: cgimage.width, height: cgimage.height))

      if let leftImage = leftImageForImage(cgimage) {
        leftImageView.image = NSImage(cgImage: leftImage, size: CGSize(width: leftImage.width, height: leftImage.height))
      } else {
        leftImageView.image = nil
      }
      
      if let rightImage = rightImageForImage(cgimage) {
        rightImageView.image = NSImage(cgImage: rightImage, size: CGSize(width: rightImage.width, height: rightImage.height))
      } else {
        rightImageView.image = nil
      }
    }
  }
  
  func imageForPage(_ page: CGPDFPage) -> CGImage? {
    let mediaBox = page.getBoxRect(.mediaBox)
    let destBox = CGRect(origin: CGPoint.zero, size: CGSize(width: mediaBox.size.width * 1, height: mediaBox.size.height * 1))
    
    guard let context = CGContext(data: nil, width: Int(destBox.size.width), height: Int(destBox.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
      print("Could not create graphics context")
      return nil
    }
    
    context.drawPDFPage(page)
    
    guard let cgimage = context.makeImage() else {
      print("Could not draw image")
      return nil
    }
    return cgimage
  }
  
  func leftImageForImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
  
  func rightImageForImage(_ image: CGImage) -> CGImage? {
    let rect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
    return image.cropping(to: rect)
  }
}

