import Foundation

/// Native body, muted and link colors retained from the typography follow-up.
enum ChatTextPalette {
    static func foreground(_ dark: Bool) -> UInt32 { dark ? 0xF7F8F8 : 0x1B1C1F }
    static func muted(_ dark: Bool) -> UInt32 { dark ? 0x8A8F98 : 0x6B6E75 }
    static func link(_ dark: Bool) -> UInt32 { dark ? 0x8CC4FF : 0x0B5CC7 }
    static func hex(_ value: UInt32) -> String { String(format: "#%06X", value) }
}
