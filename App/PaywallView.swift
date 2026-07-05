import SwiftUI

struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Steady Pro").font(Theme.font(32, weight: .bold))
            VStack(alignment: .leading, spacing: 12) {
                Label("PDF reports for doctor visits", systemImage: "doc.richtext")
                Label("Trends beyond the last 7 days", systemImage: "chart.xyaxis.line")
                Label("CSV export", systemImage: "tablecells")
                Label("All widgets", systemImage: "square.grid.2x2")
            }
            .font(Theme.font(16))
            Text("Pay once. Yours forever. No subscription.")
                .font(Theme.font(14)).foregroundStyle(Theme.secondaryText)
            Button {
                Task {
                    await pro.purchase()
                    if pro.isPro { dismiss() }
                }
            } label: {
                Text("Unlock for \(pro.displayPrice)")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.sun, in: RoundedRectangle(cornerRadius: 16))
            }
            Button("Restore purchase") {
                Task {
                    await pro.restore()
                    if pro.isPro { dismiss() }
                }
            }
            .font(Theme.font(14)).foregroundStyle(Theme.secondaryText)
            if let error = pro.purchaseError {
                Text(error).font(Theme.font(12)).foregroundStyle(.red)
            }
        }
        .padding(28)
        .presentationDetents([.medium, .large])
    }
}
