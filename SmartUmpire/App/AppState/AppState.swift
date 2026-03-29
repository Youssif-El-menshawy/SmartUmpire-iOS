import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth



@MainActor
final class AppState: ObservableObject {


    // Global user/session
    @Published var currentRole: UserRole? = nil
    
    @Published var isLoggedIn: Bool = Auth.auth().currentUser != nil
    @Published var isAppLocked: Bool = false // For Face ID screen
    @Published var isAuthReady = false

    // Selection shared across views
    @Published var selectedTournament: Tournament? = nil
    @Published var selectedMatch: Match? = nil
    
    // Simple per-flow navigation stacks
    @Published var umpirePath: [UmpireRoute] = []
    @Published var adminPath: [AdminRoute] = []
    
    // Firestore-backed data (no more mock data)
    @Published var tournaments: [Tournament] = []
    @Published var matchesByTournament: [String: [Match]] = [:]
    @Published var umpires: [Umpire] = []

    
    @Published var isLoadingTournaments = false
    @Published var dataError: String? = nil
    
  
    
    @Published var currentUmpire: Umpire?
    
    @Published var eventsByMatch: [String: [EventItem]] = [:]
    
    @Published var isImporting: Bool = false


    private let isRunningTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    
    private var tournamentsListener: ListenerRegistration?
    
    // Firestore
    private var db: Firestore { Firestore.firestore() }
    
    // Keep active listeners per tournamentId
    private var matchListeners: [String: ListenerRegistration] = [:]
    
    private var myMatchesListener: ListenerRegistration?
    private var hasReceivedServerData = false // Track if we've gotten server data
    
    private var umpiresListener: ListenerRegistration?

    private var authListener: AuthStateDidChangeListenerHandle?
    
    let isTestMode: Bool

    
    init(testMode: Bool = false) {
        self.isTestMode = testMode

        if !testMode {
            setupAuthListener()
        }
    }

    
    // MARK: - Navigation helpers
    func login(as role: UserRole) {
        currentRole = role
        isLoggedIn = true
        isAppLocked = false
        watchCurrentUmpire()
        umpirePath.removeAll()
        adminPath.removeAll()
    }
    
    func logout() {
        stopAllListeners()
        resetUmpireState()

        // Clear Firebase session
        do {
            try Auth.auth().signOut()
        } catch {
            print("Logout error: \(error)")
        }

        // Reset app auth state
        isLoggedIn = false
        isAppLocked = false
        currentRole = nil
        selectedTournament = nil
        selectedMatch = nil
        umpirePath.removeAll()
        adminPath.removeAll()
    }

}

extension AppState {
    
    @MainActor
    func fetchTournamentsAndMatches() async {
        isLoadingTournaments = true //----------- 14/1 --------------------
        defer { isLoadingTournaments = false }
        
        do {
            let tSnap = try await db.collection("tournaments").getDocuments()
            
            // Map tournaments
            let loadedTournaments: [Tournament] = tSnap.documents.compactMap { doc in
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let dateRange = data["dateRange"] as? String,
                    let location = data["location"] as? String,
                    let statusStr = data["status"] as? String,
                    let status = TournamentStatus(rawValue: statusStr)
                else { return nil }
                
                return Tournament(
                    id: doc.documentID,
                    name: name,
                    dateRange: dateRange,
                    location: location,
                    matchesCount: 0, //----------- 14/1 --------------------
                    status: status
                )
            }
            
            self.tournaments = loadedTournaments
            
            var allMatches: [String: [Match]] = [:]
            
            try await withThrowingTaskGroup(of: (String, [Match]).self) { group in
                for t in loadedTournaments {
                    group.addTask {
                        let matchesSnap = try await self.db
                            .collection("tournaments")
                            .document(t.id)
                            .collection("matches")
                            .getDocuments()
                        
                        let matches: [Match] = matchesSnap.documents.compactMap { mdoc in
                            let m = mdoc.data()
                            guard
                                let time = m["time"] as? String,
                                let court = m["court"] as? String,
                                let p1 = m["player1"] as? String,
                                let p2 = m["player2"] as? String,
                                let round = m["round"] as? String,
                                let statusStr = m["status"] as? String,
                                let status = MatchStatus(rawValue: statusStr)
                            else { return nil }
                            
                            let score = m["score"] as? String
                            let assigned = m["assignedUmpire"] as? String
                            let assignedEmail = m["assignedUmpireEmail"] as? String
                            
                            return Match(
                                id: mdoc.documentID,
                                time: time,
                                court: court,
                                player1: p1,
                                player2: p2,
                                round: round,
                                score: score,
                                status: status,
                                assignedUmpire: assigned,
                                assignedUmpireEmail: assignedEmail
                            )
                        }
                        return (t.id, matches)
                    }
                }
                
                for try await (tid, matches) in group {
                    allMatches[tid] = matches
                }
            }
            
            self.matchesByTournament = allMatches
            self.tournaments = self.tournaments.map { t in
                Tournament(
                    id: t.id,
                    name: t.name,
                    dateRange: t.dateRange,
                    location: t.location,
                    matchesCount: allMatches[t.id]?.count ?? 0,
                    status: t.status
                )
            }
        } catch {
            self.dataError = error.localizedDescription
        }
    }
    
    func assignUmpire(_ name: String?, to match: Match, in tournament: Tournament) async throws {
        // Optimistic UI
        if var list = matchesByTournament[tournament.id],
           let idx = list.firstIndex(where: { $0.id == match.id }) {
            var m = list[idx]
            m.assignedUmpire = name
            if let email = umpires.first(where: { $0.name == name })?.email {
                m.assignedUmpireEmail = email
            }
            list[idx] = m
            matchesByTournament[tournament.id] = list
        }
        
        // Backend write
        let emailToWrite = umpires.first(where: { $0.name == name })?.email
        try await db.collection("tournaments")
            .document(tournament.id)
            .collection("matches")
            .document(match.id)
            .updateData([
                "assignedUmpire": name as Any,
                "assignedUmpireEmail": emailToWrite as Any
            ])
    }
    
    
    func watchMatches(for tournamentID: String) {
        // Remove existing listener
        matchListeners[tournamentID]?.remove()
        
        let ref = db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
        
        matchListeners[tournamentID] = ref.addSnapshotListener { [weak self] snap, err in
            
            guard let self = self, let docs = snap?.documents, err == nil else { return }
            
            
            let matches: [Match] = docs.compactMap { d in
                let m = d.data()
                guard
                    let time = m["time"] as? String,
                    let court = m["court"] as? String,
                    let p1 = m["player1"] as? String,
                    let p2 = m["player2"] as? String,
                    let round = m["round"] as? String,
                    let statusStr = m["status"] as? String,
                    let status = MatchStatus(rawValue: statusStr)
                else { return nil }
                
                let score = m["score"] as? String
                let assigned = m["assignedUmpire"] as? String
                let assignedEmail = m["assignedUmpireEmail"] as? String // may be nil
                
                return Match(
                    id: d.documentID,
                    time: time,
                    court: court,
                    player1: p1,
                    player2: p2,
                    round: round,
                    score: score,
                    status: status,
                    assignedUmpire: assigned,
                    assignedUmpireEmail: assignedEmail
                )
            }
            
            
            DispatchQueue.main.async {
                self.matchesByTournament[tournamentID] = matches
                self.recalculateTournamentStatus(
                    tournamentID: tournamentID,
                    matches: matches
                )
            }
        }
    }
    
    func stopAllMatchListeners() {
        matchListeners.values.forEach { $0.remove() }
        matchListeners.removeAll()
    }
    
    func watchTournaments() {
        tournamentsListener?.remove()
        tournamentsListener = db.collection("tournaments").addSnapshotListener { [weak self] snap, err in
            guard let docs = snap?.documents, err == nil, let self = self else { return }
            let list: [Tournament] = docs.compactMap { d in
                let x = d.data()
                guard let name = x["name"] as? String,
                      let dateRange = x["dateRange"] as? String,
                      let location = x["location"] as? String,
                      let statusStr = x["status"] as? String,
                      let status = TournamentStatus(rawValue: statusStr) else { return nil }
                return Tournament(id: d.documentID, name: name, dateRange: dateRange,
                                  location: location, matchesCount: self.matchesByTournament[d.documentID]?.count ?? 0,
                                  status: status)
            }
            DispatchQueue.main.async { self.tournaments = list }
        }
    }
    
    func stopAllListeners() {
        tournamentsListener?.remove(); tournamentsListener = nil
        stopAllMatchListeners()
        stopMyMatchesListener()
        umpiresListener?.remove(); umpiresListener = nil
    }
    
    func watchMyMatches(for email: String) {
        myMatchesListener?.remove()
        hasReceivedServerData = false // Reset when restarting listener
        print("watchMyMatches: Listening for matches with email =", email)
        // collection group query across all tournaments/*/matches
        myMatchesListener = db.collectionGroup("matches")
            .whereField("assignedUmpireEmail", isEqualTo: email)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snap, err in
                if let err = err {
                    print("watchMyMatches error:", err.localizedDescription)
                    return
                }
                
                guard let self = self, let snap = snap else { return }
                
                let isFromCache = snap.metadata.isFromCache
                let hasPendingWrites = snap.metadata.hasPendingWrites
                let docs = snap.documents
                
                print("watchMyMatches: Snapshot received (fromCache: \(isFromCache), hasPending: \(hasPendingWrites))")
                print("watchMyMatches: Found \(docs.count) match(es) for email =", email)
                
                // If this is server data, mark that we've received it
                if !isFromCache {
                    hasReceivedServerData = true
                    print("watchMyMatches: Server data received")
                }
                
                // If we've already received server data, ignore subsequent cache-only updates
                // This prevents showing stale cached data after we've gotten fresh server data
                if hasReceivedServerData && isFromCache && !hasPendingWrites {
                    print("watchMyMatches: Ignoring cache-only update (already have server data)")
                    return
                }

                // Build a map: tournamentID -> [Match]
                var grouped: [String: [Match]] = [:]
                for d in docs {
                    let m = d.data()
                    // parent path looks like: tournaments/{tid}/matches/{mid}
                    let tid = d.reference.parent.parent?.documentID ?? "unknown"
                    print("• Match ID:", d.documentID)
                      print("  Tournament ID:", tid)
                      print("  path:", d.reference.path)
                    guard
                        let time = m["time"] as? String,
                        let court = m["court"] as? String,
                        let p1 = m["player1"] as? String,
                        let p2 = m["player2"] as? String,
                        let round = m["round"] as? String,
                        let statusStr = m["status"] as? String,
                        let status = MatchStatus(rawValue: statusStr)
                    else { continue }

                    let match = Match(
                        id: d.documentID,
                        time: time, court: court,
                        player1: p1, player2: p2, round: round,
                        score: m["score"] as? String,
                        status: status,
                        assignedUmpire: m["assignedUmpire"] as? String,
                        assignedUmpireEmail: m["assignedUmpireEmail"] as? String
                    )
                    grouped[tid, default: []].append(match)
                }
                
                DispatchQueue.main.async {
                    // Merge instead of replace - only update tournaments that have matches
                    for (tid, matches) in grouped {
                        self.matchesByTournament[tid] = matches
                    }
                    // Remove tournaments that no longer have assigned matches
                    let tournamentIDsWithMatches = Set(grouped.keys)
                    self.matchesByTournament = self.matchesByTournament.filter { tournamentIDsWithMatches.contains($0.key) }
                    
                    print("watchMyMatches: Updated matchesByTournament with \(grouped.count) tournament(s)")
                }

                Task {
                    await self.fetchTournamentsForUmpire(tournamentIDs: Array(grouped.keys))
                }

            }
    }
    
    
    func watchCurrentUmpire() {
        guard let email = Auth.auth().currentUser?.email else {
            print("watchCurrentUmpire: No auth email")
            return
        }

        print("watchCurrentUmpire: Searching umpire with email =", email)

            db.collection("umpires")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("watchCurrentUmpire error:", error.localizedDescription)
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    print("watchCurrentUmpire: NO umpire found for email")
                    DispatchQueue.main.async {
                        self.currentUmpire = nil
                    }
                    return
                }
                print("watchCurrentUmpire: Found umpire doc ID =", doc.documentID)

                let x = doc.data()

                guard
                    let name = x["name"] as? String,
                    let email = x["email"] as? String,
                    let rating = x["rating"] as? Double,
                    let matchesCount = x["matchesCount"] as? Int,
                    let specialization = x["specialization"] as? String,
                    let statusStr = x["status"] as? String,
                    let status = UmpireStatus(rawValue: statusStr)
                else {
                    return
                }

                let phone = x["phone"] as? String
                let location = x["location"] as? String
                let tournaments = x["tournaments"] as? Int ?? 0
                let yearsExperience = x["yearsExperience"] as? Int ?? 0
                let avatarURL = x["avatarURL"] as? String


                // Parse performance
                var performance: UmpirePerformance? = nil
                if let perf = x["performance"] as? [String: Any],
                   let avg = perf["averageRating"] as? Double,
                   let comp = perf["completionRate"] as? Double,
                   let onTime = perf["onTime"] as? Double {
                    performance = UmpirePerformance(
                        averageRating: avg,
                        completionRate: comp,
                        onTime: onTime
                    )
                }

                // Parse certifications
                var certs: [UmpireCertification] = []
                if let arr = x["certifications"] as? [[String: Any]] {
                    for c in arr {
                        if let id = c["id"] as? String,
                           let title = c["title"] as? String,
                           let issuer = c["issuer"] as? String,
                           let year = c["year"] as? String,
                           let active = c["active"] as? Bool {
                            certs.append(
                                UmpireCertification(
                                    id: id,
                                    title: title,
                                    issuer: issuer,
                                    year: year,
                                    active: active
                                )
                            )
                        }
                    }
                }

                let umpire = Umpire(
                    id: doc.documentID,
                    name: name,
                    email: email,
                    phone: phone,
                    location: location,
                    specialization: specialization,
                    rating: rating,
                    matchesCount: matchesCount,
                    tournaments: tournaments,
                    yearsExperience: yearsExperience,
                    status: status,
                    performance: performance,
                    certifications: certs.isEmpty ? nil : certs,
                    avatarURL: avatarURL
                )

                DispatchQueue.main.async {
                    let previousURL = self.currentUmpire?.avatarURL
                    self.currentUmpire = umpire

                    // If avatar URL changed, clear cached image
                    if previousURL != umpire.avatarURL {
                        AvatarCache.shared.clearAvatar(umpireID: umpire.id)
                    }
                }
            }
    }

    
    func stopMyMatchesListener() {
        myMatchesListener?.remove()
        myMatchesListener = nil
    }
    
    func watchUmpires() {
        umpiresListener?.remove()

        umpiresListener = db.collection("umpires").addSnapshotListener { [weak self] snap, err in
            guard let self = self,
                  let docs = snap?.documents,
                  err == nil else { return }

            let list: [Umpire] = docs.compactMap { d in
                let x = d.data()

                guard
                    let name = x["name"] as? String,
                    let email = x["email"] as? String,
                    let rating = x["rating"] as? Double,
                    let matchesCount = x["matchesCount"] as? Int,
                    let specialization = x["specialization"] as? String,
                    let statusStr = x["status"] as? String,
                    let status = UmpireStatus(rawValue: statusStr)
                else { return nil }

                let phone = x["phone"] as? String
                let location = x["location"] as? String
                let tournaments = x["tournaments"] as? Int ?? 0
                let yearsExperience = x["yearsExperience"] as? Int ?? 0
                let avatarURL = x["avatarURL"] as? String

                // PERFORMANCE
                var performance: UmpirePerformance? = nil
                if let perf = x["performance"] as? [String: Any],
                   let avg = perf["averageRating"] as? Double,
                   let comp = perf["completionRate"] as? Double,
                   let onTime = perf["onTime"] as? Double {
                    performance = UmpirePerformance(
                        averageRating: avg,
                        completionRate: comp,
                        onTime: onTime
                    )
                }

                // CERTIFICATIONS
                var certs: [UmpireCertification] = []
                if let arr = x["certifications"] as? [[String: Any]] {
                    for c in arr {
                        if let id = c["id"] as? String,
                           let title = c["title"] as? String,
                           let issuer = c["issuer"] as? String,
                           let year = c["year"] as? String,
                           let active = c["active"] as? Bool {
                            certs.append(
                                UmpireCertification(
                                    id: id,
                                    title: title,
                                    issuer: issuer,
                                    year: year,
                                    active: active
                                )
                            )
                        }
                    }
                }

                return Umpire(
                    id: d.documentID,
                    name: name,
                    email: email,
                    phone: phone,
                    location: location,
                    specialization: specialization,
                    rating: rating,
                    matchesCount: matchesCount,
                    tournaments: tournaments,
                    yearsExperience: yearsExperience,
                    status: status,
                    performance: performance,
                    certifications: certs.isEmpty ? nil : certs,
                    avatarURL: avatarURL
                )
            }

            DispatchQueue.main.async {
                self.umpires = list
            }
        }
    }


    
    func createTournament(_ t: Tournament) async throws {
        try await db.collection("tournaments").document(t.id).setData([
            "name": t.name,
            "dateRange": t.dateRange,
            "location": t.location,
            "status": t.status.rawValue
        ])
    }
    
    
    func updateTournament(_ t: Tournament) async throws {
        try await db.collection("tournaments").document(t.id).setData([
            "name": t.name,
            "dateRange": t.dateRange,
            "location": t.location,
            "status": t.status.rawValue
        ], merge: true)

        await MainActor.run {
            if let idx = tournaments.firstIndex(where: { $0.id == t.id }) {
                // keep matchesCount as is (or recompute from matchesByTournament)
                let updated = Tournament(
                    id: t.id,
                    name: t.name,
                    dateRange: t.dateRange,
                    location: t.location,
                    matchesCount: matchesByTournament[t.id]?.count ?? tournaments[idx].matchesCount,
                    status: t.status
                )
                tournaments[idx] = updated
            }
        }
    }
    
    func deleteTournament(_ t: Tournament) async throws {
        
        try await db.collection("tournaments").document(t.id).delete()

        await MainActor.run {
            tournaments.removeAll { $0.id == t.id }
            matchesByTournament.removeValue(forKey: t.id)
        }
    }

    @MainActor
    func deleteUmpire(_ u: Umpire) async throws {
        try await db.collection("umpires").document(u.id).delete()
        if let idx = umpires.firstIndex(where: { $0.id == u.id }) {
            umpires.remove(at: idx)
        }
    }
    
    @MainActor
    func createUmpire(
        name: String,
        email: String,
        phone: String?,
        location: String?,
        rating: Double,
        matchesCount: Int,
        status: UmpireStatus,
        specialization: String
    ) async throws {

        let id = UUID().uuidString

        let data: [String: Any] = [
            "name": name,
            "email": email,
            "phone": phone ?? "",
            "location": location ?? "",
            "specialization": specialization,
            "rating": rating,
            "matchesCount": matchesCount,
            "status": status.rawValue,
            "tournaments": 0,
            "yearsExperience": 0
        ]

        try await db.collection("umpires")
            .document(id)
            .setData(data, merge: true)

        // Local cache (instant UI feedback)
        let u = Umpire(
            id: id,
            name: name,
            email: email,
            phone: phone,
            location: location,
            specialization: specialization,
            rating: rating,
            matchesCount: matchesCount,
            tournaments: 0,
            yearsExperience: 0,
            status: status,
            performance: nil,
            certifications: nil,
            avatarURL: nil
        )

        if !umpires.contains(where: { $0.id == id }) {
            umpires.insert(u, at: 0)
        }
    }

    @MainActor
    func createMatch(
        tournamentID: String,
        time: String,
        court: String,
        player1: String,
        player2: String,
        round: String
    ) async throws {

        let data: [String: Any] = [
            "time": time,
            "court": court,
            "player1": player1,
            "player2": player2,
            "round": round,
            "status": MatchStatus.upcoming.rawValue
        ]

        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .addDocument(data: data)
    }
    
    func deleteMatch(
        tournamentID: String,
        matchID: String
    ) async throws {
        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .delete()
    }
    
    @MainActor
    func updateMatch(
        tournamentID: String,
        matchID: String,
        time: String,
        court: String,
        player1: String,
        player2: String,
        round: String,
        status: MatchStatus
    ) async throws {

        // Firestore
        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .updateData([
                "time": time,
                "court": court,
                "player1": player1,
                "player2": player2,
                "round": round,
                "status": status.rawValue
            ])

        // Local cache (instant UI update)
        if var list = matchesByTournament[tournamentID],
           let idx = list.firstIndex(where: { $0.id == matchID }) {

            var m = list[idx]
            m.time = time
            m.court = court
            m.player1 = player1
            m.player2 = player2
            m.round = round
            m.status = status

            list[idx] = m
            matchesByTournament[tournamentID] = list
        }
    }


    @MainActor
    func updateUmpire(_ umpire: Umpire) async throws {
        var data: [String: Any] = [
            "name": umpire.name,
            "email": umpire.email,
            "phone": umpire.phone ?? "",
            "location": umpire.location ?? "",
            "specialization": umpire.specialization,
            "rating": umpire.rating,
            "matchesCount": umpire.matchesCount,
            "tournaments": umpire.tournaments,
            "yearsExperience": umpire.yearsExperience,
            "status": umpire.status.rawValue
        ]

        if let url = umpire.avatarURL {
            data["avatarURL"] = url
        }

        if let perf = umpire.performance {
            data["performance"] = [
                "averageRating": perf.averageRating,
                "completionRate": perf.completionRate,
                "onTime": perf.onTime
            ]
        }

        if let certs = umpire.certifications {
            data["certifications"] = certs.map { c in
                [
                    "id": c.id,
                    "title": c.title,
                    "issuer": c.issuer,
                    "year": c.year,
                    "active": c.active
                ]
            }
        }

        try await db.collection("umpires")
            .document(umpire.id)
            .setData(data, merge: true)
    }

    
    func saveLiveMatchState(
        tournamentID: String,
        matchID: String,
        score: MatchScore,
        context: TimerContext,
        remaining: Int
    ) async throws {

        let data: [String: Any] = [
            "scoreState": [
                "player1Sets": score.player1Sets,
                "player2Sets": score.player2Sets,
                "player1Games": score.player1Games,
                "player2Games": score.player2Games,
                "player1Points": score.player1Points,
                "player2Points": score.player2Points,
                "player1Warnings": score.player1Warnings,
                "player2Warnings": score.player2Warnings,
                "isPlayer1Serving": score.isPlayer1Serving,
                "isTiebreak": score.isTiebreak
            ],
            "timer": [
                "context": context.rawValue,
                "remaining": remaining
            ],
            "status": MatchStatus.live.rawValue
        ]

        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .setData(data, merge: true)
    }

    func saveMatchEvent(
        tournamentID: String,
        matchID: String,
        event: EventItem
    ) async throws {

        let data: [String: Any] = [
            "time": event.time,
            "type": event.type,
            "description": event.description,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .collection("events")
            .addDocument(data: data)
    }
    
    func markMatchLive(tournamentID: String, matchID: String) async throws {
        try await db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .setData([
                "status": MatchStatus.live.rawValue,
                "startedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func completeMatch(
        tournamentID: String,
        matchID: String,
        summary: MatchSummary
    ) async throws {

        let ref = db.collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)

        try await ref.updateData([
            "status": MatchStatus.completed.rawValue,
            "score": summary.finalScore,
            "summary": [
                "finalScore": summary.finalScore,
                "durationSeconds": summary.durationSeconds,
                "totalWarningsP1": summary.totalWarningsP1,
                "totalWarningsP2": summary.totalWarningsP2,
                "tiebreaksPlayed": summary.tiebreaksPlayed,
                "endedAt": Timestamp(date: summary.endedAt)
            ]
        ])
    }

    
 
    
    @MainActor
    private func recalculateTournamentStatus(
        tournamentID: String,
        matches: [Match]
    ) {
        guard !matches.isEmpty else { return }

        let hasLive = matches.contains { $0.status == .live }
        let allCompleted = matches.allSatisfy { $0.status == .completed }

        let newStatus: TournamentStatus
        if allCompleted {
            newStatus = .completed
        } else if hasLive {
            newStatus = .live
        } else {
            newStatus = .upcoming
        }

        // Update local cache
        if let idx = tournaments.firstIndex(where: { $0.id == tournamentID }),
           tournaments[idx].status != newStatus {

            let t = tournaments[idx]
            tournaments[idx] = Tournament(
                id: t.id,
                name: t.name,
                dateRange: t.dateRange,
                location: t.location,
                matchesCount: matches.count,
                status: newStatus
            )

            // Persist to Firestore (single source of truth)
            Task {
                try? await db.collection("tournaments")
                    .document(tournamentID)
                    .updateData([
                        "status": newStatus.rawValue
                    ])
            }
        }
    }
    func derivedTournamentStatus(for tournament: Tournament) -> TournamentStatus {
        let matches = matchesByTournament[tournament.id] ?? []

        guard !matches.isEmpty else {
            return tournament.status
        }

        if matches.allSatisfy({ $0.status == .completed }) {
            return .completed
        }

        if matches.contains(where: { $0.status == .live }) {
            return .live
        }

        return .upcoming
    }
    
    func loadEvents(
        tournamentID: String,
        matchID: String
    ) async {
        let snap = try? await db
            .collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .document(matchID)
            .collection("events")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let items = snap?.documents.compactMap { d -> EventItem? in
            let data = d.data()
            guard
                let type = data["type"] as? String,
                let description = data["description"] as? String,
                let ts = data["createdAt"] as? Timestamp
            else { return nil }

            let df = DateFormatter()
            df.dateFormat = "HH:mm"

            return EventItem(
                id: d.documentID,
                time: df.string(from: ts.dateValue()),
                type: type,
                description: description,
                color: EventItem.defaultColor(for: type),
                source: data["source"] as? String,
                createdAt: ts.dateValue()
            )
        } ?? []

        await MainActor.run {
            eventsByMatch[matchID] = items
        }
    }
    
    @MainActor
    func updateUmpireCertifications(
        umpireID: String,
        certifications: [UmpireCertification]
    ) async throws {
        try await db.collection("umpires")
            .document(umpireID)
            .updateData([
                "certifications": certifications.map { $0.asDictionary }
            ])

        // update local cache if needed
        if let index = umpires.firstIndex(where: { $0.id == umpireID }) {
            umpires[index].certifications = certifications
        }
    }
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            self.isAuthReady = true

            guard let user = user else {
                self.stopAllListeners()
                return
            }

            guard let email = user.email else {return}
            self.startUmpireSession(email: email)
        }
    }

    
        // Starts all data listeners for a logged-in umpire
        func startUmpireSession(email: String) {
            stopAllListeners()
            resetUmpireState()
            watchUmpires()
            watchMyMatches(for: email)
        }
    
    @MainActor
    func fetchTournamentsForUmpire(tournamentIDs: [String]) async {

        guard !tournamentIDs.isEmpty else {
            self.tournaments = []
            return
        }


        // Firestore 'in' query has a limit of 10 items, so we need to batch
        let batchSize = 10
        var allFetchedTournaments: [Tournament] = []
        
        for i in stride(from: 0, to: tournamentIDs.count, by: batchSize) {
            let batch = Array(tournamentIDs[i..<min(i + batchSize, tournamentIDs.count)])
            
            let snap = try? await db
                .collection("tournaments")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()
            
            let batchTournaments: [Tournament] = snap?.documents.compactMap { d in
                let data = d.data()
                guard
                    let name = data["name"] as? String,
                    let dateRange = data["dateRange"] as? String,
                    let location = data["location"] as? String,
                    let statusStr = data["status"] as? String,
                    let status = TournamentStatus(rawValue: statusStr)
                else { return nil }

                return Tournament(
                    id: d.documentID,
                    name: name,
                    dateRange: dateRange,
                    location: location,
                    matchesCount: self.matchesByTournament[d.documentID]?.count ?? 0,
                    status: status
                )
            } ?? []
            
            allFetchedTournaments.append(contentsOf: batchTournaments)
        }

        // Merge/deduplicate instead of replacing
        var updatedTournaments = self.tournaments
        
        for fetchedTournament in allFetchedTournaments {
            if let existingIndex = updatedTournaments.firstIndex(where: { $0.id == fetchedTournament.id }) {
                // Update existing tournament
                updatedTournaments[existingIndex] = fetchedTournament
            } else {
                // Add new tournament
                updatedTournaments.append(fetchedTournament)
            }
        }
        
        // Remove tournaments that no longer have matches assigned
        let tournamentIDsWithMatches = Set(tournamentIDs)
        updatedTournaments = updatedTournaments.filter { tournamentIDsWithMatches.contains($0.id) }
        
        self.tournaments = updatedTournaments
    }
    
    @MainActor
    func refreshMatchesForKnownTournament(
        tournamentID: String,
        email: String
    ) async {

        let snap = try? await db
            .collection("tournaments")
            .document(tournamentID)
            .collection("matches")
            .whereField("assignedUmpireEmail", isEqualTo: email)
            .getDocuments()

        guard let docs = snap?.documents else { return }

        let matches: [Match] = docs.compactMap { d in
            let data = d.data()
            guard
                let time = data["time"] as? String,
                let court = data["court"] as? String,
                let p1 = data["player1"] as? String,
                let p2 = data["player2"] as? String,
                let round = data["round"] as? String,
                let statusStr = data["status"] as? String,
                let status = MatchStatus(rawValue: statusStr)
            else { return nil }

            return Match(
                id: d.documentID,
                time: time,
                court: court,
                player1: p1,
                player2: p2,
                round: round,
                score: data["score"] as? String,
                status: status,
                assignedUmpire: data["assignedUmpire"] as? String,
                assignedUmpireEmail: data["assignedUmpireEmail"] as? String
            )
        }

        // Replace ONLY this tournament’s matches
        self.matchesByTournament[tournamentID] = matches
    }

    
    @MainActor
    func resetUmpireState() {
        tournaments = []
        matchesByTournament = [:]
        eventsByMatch = [:]
        selectedTournament = nil
        selectedMatch = nil
    }
    
    
    
   
    @MainActor
    func importFromExcel(rows: [[String]]) async {
        
        /*
         Expected columns:
         0 Tournament Name
         1 Date Range
         2 Location
         3 Court
         4 Time
         5 Round
         6 Player1
         7 Player2
         8 Status
         9 Umpire Email (optional)
         */

        isImporting = true
        defer { isImporting = false }

        for row in rows {

            guard row.count >= 9 else { continue }

            let tournamentName = row[0]
            let dateRange = row[1]
            let location = row[2]
            let court = row[3]
            let time = row[4]
            let round = row[5]
            let player1 = row[6]
            let player2 = row[7]

            let statusString = row[8]
            let umpireEmail = row.count > 9 ? row[9] : nil

            let matchStatus = MatchStatus(rawValue: statusString) ?? .upcoming

            // 1️⃣ Find or create tournament
            let tournamentID: String

            if let existing = tournaments.first(where: {
                $0.name == tournamentName &&
                $0.dateRange == dateRange &&
                $0.location == location
            }) {
                tournamentID = existing.id
            } else {
                let newTournament = Tournament(
                    id: UUID().uuidString,
                    name: tournamentName,
                    dateRange: dateRange,
                    location: location,
                    matchesCount: 0,
                    status: .upcoming
                )

                try? await createTournament(newTournament)
                tournaments.append(newTournament)
                tournamentID = newTournament.id
            }

            // 2️⃣ Prevent duplicates
            let existingMatches = matchesByTournament[tournamentID] ?? []

            let duplicateExists = existingMatches.contains {
                $0.time == time &&
                $0.court == court &&
                $0.player1 == player1 &&
                $0.player2 == player2
            }

            if duplicateExists { continue }

            // 3️⃣ Prepare match data
            var matchData: [String: Any] = [
                "time": time,
                "court": court,
                "player1": player1,
                "player2": player2,
                "round": round,
                "status": matchStatus.rawValue
            ]

            // 4️⃣ If umpire email exists, attach it BEFORE creation
            if let email = umpireEmail?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
               !email.isEmpty,
               let umpire = umpires.first(where: {
                   $0.email.trimmingCharacters(in: .whitespacesAndNewlines)
                   .lowercased() == email
               }) {

                matchData["assignedUmpire"] = umpire.name
                matchData["assignedUmpireEmail"] = umpire.email
            }

            // 5️⃣ Create match (with assignment included)
            try? await db.collection("tournaments")
                .document(tournamentID)
                .collection("matches")
                .addDocument(data: matchData)
        }

        await fetchTournamentsAndMatches()
        print("✅ Import complete")
    }



    
    
    

    func ensureTournamentExists(
        name: String,
        dateRange: String,
        location: String
    ) async -> String {

        if let existing = tournaments.first(where: { $0.name == name }) {
            return existing.id
        }

        let newID = UUID().uuidString

        try? await db.collection("tournaments")
            .document(newID)
            .setData([
                "name": name,
                "dateRange": dateRange,
                "location": location,
                "status": TournamentStatus.upcoming.rawValue
            ])

        return newID
    }
    
    
    func assignUmpireByEmail(
        tournamentID: String,
        time: String,
        court: String,
        email: String
    ) async {

        guard let umpire = umpires.first(where: { $0.email == email }) else { return }

        let matches = matchesByTournament[tournamentID] ?? []

        guard let match = matches.first(where: {
            $0.time == time && $0.court == court
        }) else { return }

        try? await assignUmpire(
            umpire.name,
            to: match,
            in: tournaments.first(where: { $0.id == tournamentID })!
        )
    }

    
}
