// deskflip-display — soft-disconnect and reconnect displays on macOS.
//
// Build:  swiftc -O src/deskflip-display.swift -o deskflip-display
//
// Usage:  deskflip-display list
//         deskflip-display off <UUID|ID>
//         deskflip-display on  <UUID|ID>
//
// A unique UUID prefix of a few characters is enough (e.g. "3A7F").
//
// Uses the private API CGSConfigureDisplayEnabled, which Apple may change or
// remove in any macOS update. Changes apply to the current session only:
// logging out or restarting reconnects every display.

import Foundation
import CoreGraphics
import AppKit

typealias ConfigureFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

let cacheDir = (NSHomeDirectory() as NSString).appendingPathComponent(".cache/deskflip")
let cachePath = (cacheDir as NSString).appendingPathComponent("display-ids.json")

func fail(_ msg: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(("deskflip-display: " + msg + "\n").data(using: .utf8)!)
    exit(code)
}

func loadConfigure() -> ConfigureFn? {
    let libs = ["/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
                "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"]
    for lib in libs {
        if let h = dlopen(lib, RTLD_LAZY), let sym = dlsym(h, "CGSConfigureDisplayEnabled") {
            return unsafeBitCast(sym, to: ConfigureFn.self)
        }
    }
    return nil
}

func onlineDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

func isActive(_ id: CGDirectDisplayID) -> Bool { CGDisplayIsActive(id) != 0 }

func uuidString(_ id: CGDirectDisplayID) -> String {
    guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "?" }
    return CFUUIDCreateString(nil, u) as String
}

func screenName(_ id: CGDirectDisplayID) -> String {
    for s in NSScreen.screens {
        if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           n.uint32Value == id { return s.localizedName }
    }
    return "(disconnected)"
}

// UUID -> display ID cache, so a disconnected display can still be found
// if macOS drops it from the online list.
func loadCache() -> [String: UInt32] {
    guard let d = FileManager.default.contents(atPath: cachePath),
          let obj = try? JSONSerialization.jsonObject(with: d) as? [String: UInt32] else { return [:] }
    return obj
}

func refreshCache() {
    var c = loadCache()
    for id in onlineDisplays() { c[uuidString(id)] = id }
    try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
    if let d = try? JSONSerialization.data(withJSONObject: c, options: [.sortedKeys]) {
        FileManager.default.createFile(atPath: cachePath, contents: d)
    }
}

func resolve(_ arg: String) -> CGDirectDisplayID {
    let needle = arg.uppercased()
    let online = onlineDisplays()
    if let n = UInt32(arg), online.contains(n) { return n }
    let hits = online.filter { uuidString($0).uppercased().hasPrefix(needle) }
    if hits.count == 1 { return hits[0] }
    if hits.count > 1 { fail("'\(arg)' matches more than one display, use a longer UUID") }
    let cached = loadCache().filter { $0.key.uppercased().hasPrefix(needle) }
    if cached.count == 1 { return cached.first!.value }
    if let n = UInt32(arg) { return n }
    fail("display '\(arg)' not found. Run 'deskflip-display list' first.")
}

func setEnabled(_ id: CGDirectDisplayID, _ enabled: Bool) {
    guard let configure = loadConfigure() else {
        fail("CGSConfigureDisplayEnabled is not available on this macOS version.")
    }
    if isActive(id) == enabled {
        print("Display \(id) is already \(enabled ? "connected" : "disconnected").")
        return
    }
    if !enabled {
        let active = onlineDisplays().filter(isActive)
        if active.count <= 1 && active.contains(id) {
            fail("refusing to disconnect the last active display.", 2)
        }
    }
    var cfg: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&cfg) == .success else { fail("could not begin display configuration.") }
    let err = configure(cfg, id, enabled)
    guard err == .success else {
        CGCancelDisplayConfiguration(cfg)
        fail("CGSConfigureDisplayEnabled returned error \(err.rawValue).")
    }
    guard CGCompleteDisplayConfiguration(cfg, .forSession) == .success else {
        fail("could not apply display configuration.")
    }
    Thread.sleep(forTimeInterval: 1.0)
    let nowActive = isActive(id)
    if nowActive != enabled {
        fail("the call succeeded but macOS ignored it (display is still \(nowActive ? "connected" : "disconnected")).", 3)
    }
    print("Display \(id) \(enabled ? "connected" : "disconnected").")
}

let usage = "Usage: deskflip-display list | on <UUID|ID> | off <UUID|ID>"
let args = CommandLine.arguments
guard args.count >= 2 else { fail(usage) }

switch args[1] {
case "list":
    refreshCache()
    print("ID          UUID                                  STATE  POSITION           NAME")
    for id in onlineDisplays() {
        let b = CGDisplayBounds(id)
        let pos = "\(Int(b.origin.x)),\(Int(b.origin.y)) \(Int(b.width))x\(Int(b.height))"
        let state = isActive(id) ? "on" : "off"
        let line = String(id).padding(toLength: 11, withPad: " ", startingAt: 0) + " "
            + uuidString(id).padding(toLength: 37, withPad: " ", startingAt: 0) + " "
            + state.padding(toLength: 6, withPad: " ", startingAt: 0) + " "
            + pos.padding(toLength: 18, withPad: " ", startingAt: 0) + " "
            + screenName(id)
        print(line)
    }
case "on", "off":
    guard args.count >= 3 else { fail("specify a display UUID or ID.\n" + usage) }
    refreshCache()
    setEnabled(resolve(args[2]), args[1] == "on")
case "-h", "--help", "help":
    print(usage)
default:
    fail("unknown command '\(args[1])'.\n" + usage)
}
