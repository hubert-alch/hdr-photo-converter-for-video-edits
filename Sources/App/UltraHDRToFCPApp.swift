import SwiftUI

@main
struct UltraHDRToFCPApp: App {
    @StateObject private var store = ConversionStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 660)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Start Conversion") {
                    store.startConversion()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!store.canConvert)
            }
        }
    }
}
