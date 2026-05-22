#if os(iOS)
import SwiftUI

/// Small tappable badge to surface that a captured string is a JWT and route to
/// `JWTDetailView`. Designed to slot into a header-row cell or alongside JSON body text.
struct JWTBadgeView: View {
    let jwt: JWT
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text("JWT")
                    .font(.caption.weight(.semibold))
                if case .expired = jwt.validity() {
                    Text("• expired")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                JWTDetailView(jwt: jwt)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showDetail = false }
                        }
                    }
            }
        }
    }
}
#endif
