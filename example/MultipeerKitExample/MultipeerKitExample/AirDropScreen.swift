import SwiftUI
import MultipeerKit

struct AirDropScreen: View {
    var body: some View {
        Text("AirDrop")
    }
}

#Preview {
    AirDropScreen()
        .environmentObject(MultipeerDataSource.example)
}
