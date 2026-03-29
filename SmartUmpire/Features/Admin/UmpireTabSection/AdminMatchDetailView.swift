import SwiftUI

struct AdminMatchDetailView: View {
    let match: Match
    let tournament: Tournament

    var body: some View {
        ScrollView {
            MatchSummaryView(
                match: match,
                tournament: tournament
            )
            .padding(16)
        }
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
