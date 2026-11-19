import Foundation

/// Native body, muted and link colors retained from the typography follow-up.
enum ChatTextPalette {
    static func foreground(_ dark: Bool) -> UInt32 { dark ? 0xF2F2F2 : 0x1B1C1F }
    static func muted(_ dark: Bool) -> UInt32 { dark ? 0x8F8F8F : 0x62656C }
    static func link(_ dark: Bool) -> UInt32 { dark ? 0x8CC4FF : 0x0B5CC7 }
    static func hex(_ value: UInt32) -> String { String(format: "#%06X", value) }
}
