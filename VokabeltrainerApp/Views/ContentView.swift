import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack { TranslatorView() }
                .tabItem { Label("Translate", systemImage: "arrow.left.arrow.right") }

            NavigationStack { VocabularyTestView() }
                .tabItem { Label("Practice", systemImage: "graduationcap.fill") }

            NavigationStack { WordListsView() }
                .tabItem { Label("Word Lists", systemImage: "list.bullet.rectangle") }

            NavigationStack { WritingPracticeView() }
                .tabItem { Label("Writing", systemImage: "pencil.and.outline") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.brandIndigo)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
