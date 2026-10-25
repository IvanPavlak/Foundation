// Input-source helper - macOS keyboard layouts through the Text Input Sources API (Carbon), the
// InputMethodTips of Get-WinUserLanguageList on Windows. Run only by lib/drivers/inputsource.sh,
// through the swift interpreter of the Command Line Tools.
//
// Usage: swift inputsource.swift list | apply ID...
//
//   list        every enabled keyboard layout as ID<TAB>SELECTED(0/1)<TAB>NAME, one per line
//               (input methods such as the Character Palette are left out)
//   apply ID... enables the keyboard layouts ID... (input-source ids), selects the first and
//               then disables every other enabled keyboard layout; input methods are untouched.
//               An id macOS does not have fails (exit 3) before anything changes; a step macOS
//               refuses is reported on stderr and fails (exit 1) after the rest is done.
import Carbon

func text(_ source: TISInputSource, _ key: CFString) -> String {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return "" }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
}

// Keyboard layouts only; INCLUDE-ALL adds the installed ones that are not enabled.
func layouts(includeAll: Bool) -> [TISInputSource] {
    let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, includeAll)?.takeRetainedValue() as? [TISInputSource] else { return [] }
    return list
}

func warn(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "list":
    for source in layouts(includeAll: false) {
        let selected = flag(source, kTISPropertyInputSourceIsSelected) ? "1" : "0"
        print("\(text(source, kTISPropertyInputSourceID))\t\(selected)\t\(text(source, kTISPropertyLocalizedName))")
    }
case "apply":
    let wanted = Array(arguments.dropFirst())
    guard !wanted.isEmpty else {
        warn("apply needs at least one input-source id")
        exit(2)
    }
    let installed = layouts(includeAll: true)
    var sources: [TISInputSource] = []
    for id in wanted {
        guard let source = installed.first(where: { text($0, kTISPropertyInputSourceID) == id }) else {
            warn("No keyboard layout [\(id)] on this Mac")
            exit(3)
        }
        sources.append(source)
    }
    var failed = false
    for (id, source) in zip(wanted, sources) where !flag(source, kTISPropertyInputSourceIsEnabled) {
        if TISEnableInputSource(source) != noErr { warn("Could not enable [\(id)]"); failed = true }
    }
    if TISSelectInputSource(sources[0]) != noErr { warn("Could not select [\(wanted[0])]"); failed = true }
    // Disabled last, so the Mac is never left without an enabled layout.
    for source in layouts(includeAll: false) {
        let id = text(source, kTISPropertyInputSourceID)
        if wanted.contains(id) { continue }
        if TISDisableInputSource(source) != noErr { warn("Could not disable [\(id)]"); failed = true }
    }
    exit(failed ? 1 : 0)
default:
    warn("Usage: inputsource.swift list | apply ID...")
    exit(2)
}
