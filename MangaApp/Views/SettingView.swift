import SwiftUI

struct SettingView: View {
    @ObservedObject private var serviceProvider = ServiceProvider.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("API Source", selection: $serviceProvider.currentSource) {
                        ForEach(ServiceProvider.Source.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                } header: {
                    Text("Data Source")
                } footer: {
                    Text("Changing the source will reload all manga data.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.lightPink.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}
