#!/usr/bin/swift

import AppKit
import ApplicationServices
import Foundation

let accessibilityOptions = [
  kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
] as CFDictionary

guard AXIsProcessTrustedWithOptions(accessibilityOptions) else {
  print("Accessibility permission is required for Raycast or toggle-chrome-sidebar")
  exit(1)
}

let targetTitles = ["Expand Tabs", "Collapse Tabs"]

guard let chromeApp = NSRunningApplication.runningApplications(
  withBundleIdentifier: "com.google.Chrome"
).first else {
  print("Chrome is not running")
  exit(1)
}

let appElement = AXUIElementCreateApplication(chromeApp.processIdentifier)

var windowsValue: CFTypeRef?
guard AXUIElementCopyAttributeValue(
  appElement,
  kAXWindowsAttribute as CFString,
  &windowsValue
) == .success,
let windows = windowsValue as? [AXUIElement],
let window = windows.first else {
  print("No Chrome windows found")
  exit(1)
}

func findButton(element: AXUIElement, depth: Int = 0) -> AXUIElement? {
  if depth > 10 { return nil }

  var role: CFTypeRef?
  AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

  var title: CFTypeRef?
  AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)

  var desc: CFTypeRef?
  AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc)

  let roleStr = role as? String ?? ""
  let titleStr = title as? String ?? ""
  let descStr = desc as? String ?? ""

  if roleStr == (kAXButtonRole as String)
    && (targetTitles.contains(titleStr) || targetTitles.contains(descStr)) {
    return element
  }

  var children: CFTypeRef?
  AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)

  guard let childArray = children as? [AXUIElement] else { return nil }

  for child in childArray {
    if let found = findButton(element: child, depth: depth + 1) {
      return found
    }
  }

  return nil
}

guard let button = findButton(element: window) else {
  print("Sidebar toggle button not found in accessibility tree")
  exit(1)
}

let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
if result != .success {
  print("Failed to press Chrome sidebar toggle: \(result.rawValue)")
  exit(1)
}
