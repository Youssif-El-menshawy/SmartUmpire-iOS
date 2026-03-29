import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import UIKit


struct UmpireProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?
    @State private var avatarImage: UIImage?


    var body: some View {
        let umpire = appState.currentUmpire   // ← REAL DATA

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Profile card
                VStack(alignment: .center, spacing: 16) {

                    ZStack(alignment: .bottomTrailing) {

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ){
                            Group {
                                if let image = avatarImage {
                                    Image(uiImage: image)
                                        .resizable()
                                } else {
                                    AvatarCircle(initials: initials(from: umpire?.name ?? ""))
                                }
                            }
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        }
                        .disabled(isUploadingAvatar)

                        // Camera icon overlay
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.primaryBlue)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                        if isUploadingAvatar {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                    }



                    Text(umpire?.name ?? "Unknown Umpire")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    CapsuleBadge(text: umpire?.specialization ?? "Not specified")

                    VStack(spacing: 10) {
                        IconTextRow(systemName: "envelope",
                                    text: umpire?.email ?? "Not available")
                        IconTextRow(systemName: "phone",
                                    text: umpire?.phone ?? "No phone listed")
                        IconTextRow(systemName: "mappin.and.ellipse",
                                    text: umpire?.location ?? "No location added")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .cardStyle()

                // Stats
                BigStatCard(systemIcon: "target",
                            value: "\(umpire?.matchesCount ?? 0)",
                            label: "Matches Officiated",
                            tint: .primaryBlue)

                BigStatCard(systemIcon: "trophy.fill",
                            value: "\(umpire?.tournaments ?? 0)",
                            label: "Tournaments",
                            tint: .successGreen)

                BigStatCard(systemIcon: "rosette",
                            value: "\(umpire?.yearsExperience ?? 0)",
                            label: "Years Experience",
                            tint: .purple)


                // Performance section
                if let stats = umpire?.performance {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Performance Statistics")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        ProgressRow(
                            title: "Match Completion Rate",
                            valueText: "\(stats.completionRate)%",
                            value: stats.completionRate / 100,
                            tint: .primaryBlue
                        )

                        ProgressRow(
                            title: "Average Match Rating",
                            valueText: "\(stats.averageRating)/5.0",
                            value: stats.averageRating / 5,
                            tint: .primaryBlue
                        )

                        ProgressRow(
                            title: "On-time Performance",
                            valueText: "\(stats.onTime)%",
                            value: stats.onTime / 100,
                            tint: .purple
                        )
                    }
                    .cardStyle()
                }

                // Certifications
                if let certs = umpire?.certifications, !certs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {

                        Text("Certifications & Qualifications")
                            .font(.system(size: 16, weight: .semibold))


                        // List of cert rows
                        ForEach(certs) { c in
                            CertRow(
                                title: c.title,
                                subtitle: "\(c.issuer) • \(c.year)",
                                status: c.active ? "Active" : "Expired",
                                tint: .blue600.opacity(0.15),
                                icon: "rosette"
                            )
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else { return }
            Task { await uploadAvatar(item) }
        }
        .onAppear {
            loadAvatarIfNeeded()
        }
        .onChange(of: appState.currentUmpire?.avatarURL) { _, _ in
            loadAvatarIfNeeded()
        }
        .alert("Avatar Upload Failed", isPresented: .constant(avatarError != nil)) {
            Button("OK") { avatarError = nil }
        } message: {
            Text(avatarError ?? "")
        }
    }
    
    private func loadAvatarIfNeeded() {
        guard let umpire = appState.currentUmpire else { return }

        Task {
            avatarImage = await AvatarCache.shared.loadAvatar(
                umpireID: umpire.id,
                remoteURL: umpire.avatarURL
            )
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
    }
    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard let umpire = appState.currentUmpire else {
            avatarError = "Umpire not loaded."
            return
        }

        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "ImageError", code: 0)
            }
            
            AvatarCache.shared.saveAvatar(
                umpireID: umpire.id,
                data: jpegData
            )

            let ref = Storage.storage()
                .reference()
                .child("avatars/\(umpire.id).jpg")

            _ = try await ref.putDataAsync(jpegData)

            let url = try await ref.downloadURL()

            // Save URL to Firestore
            try await Firestore.firestore()
                .collection("umpires")
                .document(umpire.id)
                .updateData([
                    "avatarURL": url.absoluteString
                ])

        } catch {
            avatarError = error.localizedDescription
        }
    }
}


// MARK: - Pieces that create the new look

private struct AvatarCircle: View {
    @Environment(\.colorScheme) var scheme
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primaryBlue.opacity(scheme == .dark ? 0.20 : 1.0),
                            Color.appBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 120, height: 120)

            Text(initials)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
    }
}


private struct CapsuleBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primaryBlue)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.primaryBlue.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct BigStatCard: View {
    let systemIcon: String
    let value: String
    let label: String
    let tint: Color
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct ProgressRow: View {
    let title: String
    let valueText: String
    let value: Double     // 0...1
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(valueText).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.border).frame(height: 6)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6).fill(tint)
                        .frame(width: max(0, min(1, value)) * geo.size.width, height: 6)
                }
                .frame(height: 6)
            }
        }
    }
}

private struct CertRow: View {
    let title: String
    let subtitle: String
    let status: String
    let tint: Color
    let icon: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .frame(width: 36, height: 36)
                .background(tint)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(.textSecondary)
            }
            Spacer()
            StatusPill(text: status, color: Color.successGreen.opacity(0.12), textColor: .successGreen)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

}

