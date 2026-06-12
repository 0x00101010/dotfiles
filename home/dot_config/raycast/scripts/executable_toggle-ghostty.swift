#!/usr/bin/swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Toggle Ghostty
// @raycast.mode silent

// Optional parameters:
// @raycast.packageName Ghostty

import AppKit
import Foundation

let bundleID = "com.mitchellh.ghostty"

func runningGhostty() -> NSRunningApplication? {
  NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
}

if let app = runningGhostty() {
  if app.isActive {
    app.hide()
  } else {
    app.unhide()
    _ = app.activate(options: [.activateAllWindows])
  }
  exit(0)
}

guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
  print("Ghostty.app not found")
  exit(1)
}

let config = NSWorkspace.OpenConfiguration()
config.activates = true
NSWorkspace.shared.openApplication(at: appURL, configuration: config)
