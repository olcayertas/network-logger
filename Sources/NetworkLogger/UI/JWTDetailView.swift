#if os(iOS)
import SwiftUI
import UIKit

/// jwt.io-style three-section view of a decoded JWT.
///
/// Header, payload, and signature each get their own coloured section; standard claims
/// are surfaced as human-readable rows; expiry / not-yet-valid status appears in an
/// informational banner. Signature is shown as base64url — no verification.
public struct JWTDetailView: View {
    public let jwt: JWT
    @Environment(\.networkLoggerAppearance) private var appearance

    public init(jwt: JWT) {
        self.jwt = jwt
    }

    public var body: some View {
        List {
            validitySection
            claimsSection
            Section {
                Text(jwt.headerPrettyJSON)
                    .font(.system(size: appearance.bodyFontSize, design: .monospaced))
                    .foregroundStyle(Color.red)
                    .textSelection(.enabled)
            } header: {
                Label("Header", systemImage: "1.circle.fill")
                    .foregroundStyle(Color.red)
            }
            Section {
                Text(jwt.payloadPrettyJSON)
                    .font(.system(size: appearance.bodyFontSize, design: .monospaced))
                    .foregroundStyle(Color.purple)
                    .textSelection(.enabled)
            } header: {
                Label("Payload", systemImage: "2.circle.fill")
                    .foregroundStyle(Color.purple)
            }
            Section {
                Text(jwt.rawSignature.isEmpty ? "<empty>" : jwt.rawSignature)
                    .font(.system(size: appearance.bodyFontSize, design: .monospaced))
                    .foregroundStyle(Color.teal)
                    .textSelection(.enabled)
                Text("Signature is shown as raw base64url — NetworkLogger does not verify it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Signature", systemImage: "3.circle.fill")
                    .foregroundStyle(Color.teal)
            }
            Section("Raw") {
                Text("\(jwt.rawHeader).\(jwt.rawPayload).\(jwt.rawSignature)")
                    .font(.system(size: appearance.bodyFontSize - 1, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("JWT")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIPasteboard.general.string = "\(jwt.rawHeader).\(jwt.rawPayload).\(jwt.rawSignature)"
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("Copy raw token")
            }
        }
    }

    @ViewBuilder
    private var validitySection: some View {
        let status = jwt.validity()
        switch status {
        case .valid:
            Section {
                Label("Within validity window", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Time-window check only — signature was NOT verified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .expired(since):
            Section {
                Label("Expired", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Expired \(since.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .notYetValid(until):
            Section {
                Label("Not yet valid", systemImage: "hourglass")
                    .foregroundStyle(.yellow)
                Text("Becomes valid \(until.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var claimsSection: some View {
        Section("Standard claims") {
            if let alg = jwt.claims.alg { claimRow("Algorithm", value: alg) }
            if let typ = jwt.claims.typ { claimRow("Type", value: typ) }
            if let kid = jwt.claims.kid { claimRow("Key ID", value: kid) }
            if let iss = jwt.claims.iss { claimRow("Issuer (iss)", value: iss) }
            if let sub = jwt.claims.sub { claimRow("Subject (sub)", value: sub) }
            if !jwt.claims.aud.isEmpty { claimRow("Audience (aud)", value: jwt.claims.aud.joined(separator: ", ")) }
            if let iat = jwt.claims.iat { claimRow("Issued at (iat)", value: iat.formatted(date: .abbreviated, time: .standard)) }
            if let nbf = jwt.claims.nbf { claimRow("Not before (nbf)", value: nbf.formatted(date: .abbreviated, time: .standard)) }
            if let exp = jwt.claims.exp { claimRow("Expires at (exp)", value: exp.formatted(date: .abbreviated, time: .standard)) }
            if let jti = jwt.claims.jti { claimRow("ID (jti)", value: jti) }
            if !jwt.claims.customKeys.isEmpty {
                claimRow("Other claims", value: jwt.claims.customKeys.joined(separator: ", "))
            }
        }
    }

    private func claimRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.callout.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
#endif
