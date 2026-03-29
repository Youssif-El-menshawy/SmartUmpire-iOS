import SwiftUI

struct SelectUmpireView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let tournament: Tournament
    let match: Match?

    @State private var selectedUmpire: Umpire? = nil
    @State private var search: String = ""
    @State private var showConfirm = false


    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredUmpires) { umpire in
                        UmpireSelectableCard(
                            umpire: umpire,
                            isSelected: selectedUmpire?.id == umpire.id
                        ) {
                            withAnimation {
                                selectedUmpire =
                                (selectedUmpire?.id == umpire.id) ? nil : umpire
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            AppButton(
                "Assign Umpire",
                variant: .primary,
                icon: "checkmark.seal.fill",
                isFullWidth: true
            ) {
                showConfirm = true
            }
            .disabled(selectedUmpire == nil || match == nil)
            .padding()
        }
        .navigationTitle("Select Umpire")
        .task {
            appState.watchUmpires()
        }
        .alert("Confirm Assignment", isPresented: $showConfirm) {
            Button("Assign", role: .destructive) {
                assign()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            Assign \(selectedUmpire?.name ?? "")
            to match:
            \(match?.player1 ?? "") vs \(match?.player2 ?? "")
            """)
        }
    }

    private func assign() {
        guard let match, let umpire = selectedUmpire else { return }

        Task {
            do {
                try await appState.assignUmpire(
                    umpire.name,
                    to: match,
                    in: tournament
                )
                dismiss()
            } catch {
                print("Assign failed:", error.localizedDescription)
            }
        }
    }

    private var filteredUmpires: [Umpire] {
        let q = search.lowercased()
        return appState.umpires
            .filter { $0.status == .available }
            .filter {
                q.isEmpty ||
                $0.name.lowercased().contains(q) ||
                $0.specialization.lowercased().contains(q)
            }
    }
}
