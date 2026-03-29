//
//  AdminUmpirevIEW.swift
//  SmartUmpire
//
//  Created by Youssef on 15/12/2025.
//


import SwiftUI

struct AdminUmpireDetailView: View {
    
    @State private var confirmDelete = false
    @State private var cannotDeleteAlert = false
    @State private var editingUmpire: Umpire? = nil


    @EnvironmentObject private var appState: AppState
    let umpireID: String
    
    private var umpire: Umpire? {
        appState.umpires.first { $0.id == umpireID }
    }
    
    
    var body: some View {
        Group {
            if let umpire = umpire {
                content(umpire)
            } else {
                ProgressView()
                    .navigationTitle("Umpire")
            }
        }
    }

    @ViewBuilder
    private func content(_ umpire: Umpire) -> some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(umpire)
                    profileSection(umpire)
                    performanceSection(umpire)
                    certificationsSection(umpire)
                }
                .padding(16)
            }

            let count = officiatedMatches.count
            AppButton(
                count == 0 ? "No Assigned Matches" : "View Assigned Matches (\(count))",
                variant: .primary,
                isFullWidth: true
            ) {
                appState.adminPath.append(.viewUmpireMatches(umpireID: umpireID))
            }
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1.0)
            .padding(16)
            .background(Color.appBackground)
        }
        .navigationTitle("Umpire")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar { toolbarMenu(umpire) }
        .alert("Delete Umpire?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Cannot Delete Umpire", isPresented: $cannotDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This umpire has assigned matches.")
        }
        .sheet(item: $editingUmpire) { umpire in
            UmpireForm(mode: .edit(existing: umpire)) { result in
                if case .saved(let updated) = result {
                    Task {
                        try? await appState.updateUmpire(updated)
                    }
                }
            }
        }
    }


    
    
    private func toolbarMenu(_ umpire: Umpire) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    editingUmpire = umpire
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                }

                Button {
                    appState.adminPath.append(.editUmpireCertifications(umpireID: umpire.id))
                } label: {
                    Label("Edit Certifications", systemImage: "checkmark.seal")
                }

                Divider()

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete Umpire", systemImage: "trash")
                }
                .disabled(hasActiveAssignments)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.accentColor)
            }
        }
    }


    private func header(_ umpire: Umpire) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(umpire.name)
                    .font(.system(size: 22, weight: .semibold))

                Text(umpire.email)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            StatusPill(
                text: umpire.status.rawValue.capitalized,
                color: statusColor(umpire.status).opacity(0.15),
                textColor: statusColor(umpire.status)
            )
        }
    }

    private func profileSection(_ umpire: Umpire) -> some View {
        VStack(spacing: 12) {
            infoRow(title: "Phone", value: umpire.phone ?? "—")
            infoRow(title: "Location", value: umpire.location ?? "—")
            infoRow(title: "Specialization", value: umpire.specialization)
        }
        .cardStyle()
    }


    
    private func performanceSection(_ umpire: Umpire) -> some View {
        VStack(spacing: 14) {
            if let perf = umpire.performance {
                infoRow(title: "Avg Rating", value: String(format: "%.2f", perf.averageRating))
                infoRow(title: "Completion Rate", value: "\(Int(perf.completionRate * 100))%")
                infoRow(title: "On-Time Rate", value: "\(Int(perf.onTime * 100))%")
            } else {
                HStack {
                    Text("No performance data yet.")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 14))
                    Spacer()
                }
            }
        }
        .cardStyle()
    }


    private func certificationsSection(_ umpire: Umpire) -> some View {
        Group {
            if let certs = umpire.certifications, !certs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {

                    Text("Certifications & Qualifications")
                        .font(.headline)

                    ForEach(certs) { cert in
                        HStack(alignment: .top, spacing: 12) {

                            Image(systemName: "rosette")
                                .foregroundColor(.primaryBlue)
                                .frame(width: 36, height: 36)
                                .background(Color.primaryBlue.opacity(0.12))
                                .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(cert.title)
                                    .font(.system(size: 15, weight: .semibold))

                                Text("\(cert.issuer) • \(cert.year)")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            StatusPill(
                                text: cert.active ? "Active" : "Inactive",
                                color: cert.active ? Color.successGreen.opacity(0.15) : Color.textSecondary.opacity(0.15),
                                textColor: cert.active ? .successGreen : .textSecondary
                            )
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(10)
                    }
                }
                .cardStyle()
            } else {
                HStack(spacing: 8) {
                    Text("No certifications added yet.")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 14))
                    Spacer()
                }
                .cardStyle()
            }
        }
    }


    private func delete() {
        guard let umpire = umpire else { return }
        if officiatedMatches.contains(where: { $0.status != .completed }) {
            cannotDeleteAlert = true
            return
        }

        Task {
            try? await appState.deleteUmpire(umpire)
            if !appState.adminPath.isEmpty {
                appState.adminPath.removeLast()
            }
        }
    }

    private var officiatedMatches: [Match] {
        guard let email = umpire?.email else { return [] }
        return appState.matchesByTournament.values
            .flatMap { $0 } // flatten into one list like this [m1, m2, m3]
            .filter { $0.assignedUmpireEmail == email }
    }
    
    private var hasActiveAssignments: Bool {
        officiatedMatches.contains { $0.status != .completed }
    }


    // MARK: - Helpers
    
    private func statusColor(_ status: UmpireStatus) -> Color {
        switch status {
        case .available: return .successGreen
        case .assigned: return .warningYellow
        case .unavailable: return .errorRed
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
    }
}
