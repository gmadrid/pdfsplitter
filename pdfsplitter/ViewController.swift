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
  case FailedToOpenPage(pageNum: Int)
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
  @IBOutlet var pageNumberSlider: NSSlider!
  
  @IBOutlet var nextPageButton: NSButton!
  @IBOutlet var prevPageButton: NSButton!
  @IBOutlet var openFileButton: NSButton!
  @IBOutlet var splitButton: NSButton!

  var disposeBag = DisposeBag()
  var processing = BehaviorSubject(value: false)
  
  // TODO: make this a sequence, OR make this document-based.
  var splitter: PDFSplitter? {
    didSet {
      splitButton.isEnabled = splitter != nil
      pageNumberSlider.isEnabled = splitter != nil
      
      guard let s = splitter else { return }
      
      // Set the max/min values for the slider.
      // (Dispose immediately. We're just unwrapping this to set these initial values.)
      s.numberOfPages_.subscribe(onNext: { [weak self] numberOfPages in
        self?.pageNumberSlider.minValue = 1.0
        self?.pageNumberSlider.maxValue = Double(numberOfPages)
      })
        .dispose()
      
      // Set the original image view from the splitter.
      s.pageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: originalImageView.rx.image)
        .disposed(by: s.disposeBag)
      
      // Set the left page image from the splitter.
      s.leftPageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: leftImageView.rx.image)
        .disposed(by: s.disposeBag)
      
      // Set the right page view from the splitter.
      s.rightPageImage_
        .map { return NSImage(cgimage: $0) }
        .bind(to: rightImageView.rx.image)
        .disposed(by: s.disposeBag)
      
      // Display the page number.
      Observable.combineLatest(s.pageNumber_, s.numberOfPages_) {
        return String(format: "Page %d of %d", $0, $1)
        }
        .bind(to:pageNumberField.rx.text)
        .disposed(by: s.disposeBag)
      
      // Enable/disable the next/prev buttons based on the page number.
      s.pageNumber_.map { $0 > 1 }
        .bind(to:prevPageButton.rx.isEnabled).disposed(by: s.disposeBag)
      Observable.combineLatest(s.pageNumber_, s.numberOfPages_) { pageNumber, numberOfPages in
        return pageNumber < numberOfPages
        }
        .bind(to: nextPageButton.rx.isEnabled).disposed(by: s.disposeBag)
      
      // Two-way update of the page number slider.
      s.pageNumber_.distinctUntilChanged()
        .map { Double($0) }
        .bind(to: pageNumberSlider.rx.value)
        .disposed(by: s.disposeBag)
      pageNumberSlider.rx.value.distinctUntilChanged()
        .map { Int($0) }
        .subscribe(onNext: { pageNumber in
          s.gotoPage(pageNumber)
        })
        .disposed(by: s.disposeBag)
      
      // Disable the split button and open file button while processing a split.
      let p = processing
        .map { !$0 }
        .asDriver(onErrorJustReturn: false)
      p.drive(splitButton.rx.isEnabled).disposed(by: disposeBag)
      p.drive(openFileButton.rx.isEnabled).disposed(by: disposeBag)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    let url = URL(string: "file:///Users/gmadrid/Dropbox/Sonata%20-%20Juan%20Tamariz.pdf")
    if url != nil {
      try! openFile(url!)
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
    guard let splitter = splitter else {
      return
    }
    
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
    
    let url = URL(string: "file:///Users/gmadrid/Desktop/Sonata-test.pdf")!
    
    processing.onNext(true)
    splitter.split(destUrl: url)
      .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
      .subscribe(onNext: { pageNum in
      }, onError: { [weak self] error in
        print(error)
        self?.processing.onNext(false)
      }, onCompleted: { [weak self] in
        print("COMPLETED CONVERSION")
        self?.processing.onNext(false)
      })
      .disposed(by: splitter.disposeBag)
  }
  
  func openFile(_ fileURL: URL) throws {
    closeFile();
    
    filenameField.stringValue = fileURL.path
    
    splitter = try PDFSplitter(url: fileURL)
  }
  
  func closeFile() {
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
  
  override func viewDidDisappear() {
    // When the user closes the window, close the app.
    super.viewDidDisappear()
    NSApplication.shared().terminate(nil)
  }
}

