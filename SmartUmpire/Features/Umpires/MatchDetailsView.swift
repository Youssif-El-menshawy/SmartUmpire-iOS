import SwiftUI

struct MatchDetailsView: View {
    let match: Match
    let tournament: Tournament

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match Details")
                        .font(.system(size: 22, weight: .semibold))
                }
                MatchSummaryView(
                    match: match,
                    tournament: tournament
                )
            }
            .padding(16)
        }
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
