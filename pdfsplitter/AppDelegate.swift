//
//  AppDelegate.swift
//  pdfsplitter
//
//  Created by George Madrid on 6/6/17.
//  Copyright © 2017 George Madrid. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBAction func openNewWindow(sender: Any?) {
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
      print(url)
      //        try openFile(url)
    } else {
      // User clicked "Cancel"
      return
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }


}

