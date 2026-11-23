import AmbulandoCore
import SwiftUI

/// UX lab (Mac): Pin where you look for it. The only control was a pin in the window's title bar, far from the record;
/// tasks, documents and their lists now offer Pin to Deck in their ••• menus, and the crumb row shows the pin too.
/// Pins appear in the Deck's Pinned drawer (in their place, and at Home).
extension AppModel {
    func pinAction(_ type: PinRecord.ResourceType, _ id: String, in workspace: WorkspaceRecord) -> NativeMessageAction {
        let pinned = pins.value.isPinned(type, id)
        return NativeMessageAction(pinned ? "Unpin from Deck" : "Pin to Deck", pinned ? "pin.slash" : "pin") { [self] in
            setPinned(!pinned, type: type, id: id, in: workspace)
        }
    }
}
