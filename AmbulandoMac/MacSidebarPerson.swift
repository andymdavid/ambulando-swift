import AmbulandoCore
import SwiftUI

/// UX lab: the foot of the Mac sidebar is you, a sidebar row with your avatar and name that opens Settings (it was the
/// avatar at the end of the window toolbar). The workspace switcher moved to the top of the sidebar.
struct MacSidebarPerson: View {
    @Environment(AppModel.self) private var model
    @Environment(MacUI.self) private var ui

    var body: some View {
        let me = model.me.value?.person
        SidebarRow(label: me?.name ?? "Settings", identifier: "settings", accessibilityLabel: "Settings",
                   action: { ui.showSettings = true }) {
            if let me {
                PersonAvatar(person: me, size: Amb.SidebarLayout.iconSlot)
            } else {
                Image(systemName: "person.crop.circle").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            }
        }
        .accessibilityValue(me?.name ?? "")
        .padding(Amb.SidebarLayout.gutter)
    }
}
