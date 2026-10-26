import SwiftUI

/// Five tabs (iOS shows a "Más" tab beyond five), Ajustes opens from the
/// gear button in Inicio.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(AppTab.home)

            WardrobeView()
                .tabItem { Label("Mi armario", systemImage: "hanger") }
                .tag(AppTab.wardrobe)

            StylistView()
                .tabItem { Label("Crear outfit", systemImage: "wand.and.stars") }
                .tag(AppTab.stylist)

            InspirationView()
                .tabItem { Label("Inspiración", systemImage: "sparkles") }
                .tag(AppTab.inspiration)

            LooksView()
                .tabItem { Label("Mis looks", systemImage: "square.grid.2x2") }
                .tag(AppTab.looks)
        }
    }
}
