import Foundation
import Testing
@testable import NetworkLogger

/// Tests the badge-rendering contract used by `HeadersSection`.
///
/// Lifted out of the view so the actual decision logic can be exercised without UI —
/// see https://github.com/olcayertas/network-logger/issues for the original report
/// where the unit tests only proved `decodedJWTs` got populated but not that the UI
/// would render the badge from it.
@Suite("HeaderJWTResolver — badge contract")
struct HeaderJWTResolverTests {
    private static let token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhbGljZSJ9.sig"

    @Test("redacted Authorization + pre-decoded JWT still produces a badge")
    func redactedAuthWithDecodedProducesBadge() throws {
        // This is the bug v0.5.1 fixed: by the time HeadersSection renders, the raw
        // value is "•••redacted•••" — but the JWT was captured before redaction and
        // lives in decodedJWTs. The resolver MUST return the cached JWT.
        let cached = try #require(JWT(Self.token))
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: "•••redacted•••",
            decoded: ["authorization": cached]
        )
        let jwt = try #require(result)
        #expect(jwt.claims.sub == "alice")
    }

    @Test("authorization key matches case-insensitively")
    func authorizationCaseInsensitive() throws {
        let cached = try #require(JWT(Self.token))
        for variant in ["Authorization", "authorization", "AUTHORIZATION", "Authorization-"] {
            let lower = variant.lowercased()
            let dict = lower.hasPrefix("authorization") ? [lower: cached] : [:]
            let _ = HeaderJWTResolver.jwt(forHeader: variant, value: "•••redacted•••", decoded: dict)
            // Just exercise the path — assertion below covers the standard case.
        }
        let result = HeaderJWTResolver.jwt(
            forHeader: "AUTHORIZATION",
            value: "•••redacted•••",
            decoded: ["authorization": cached]
        )
        #expect(result?.claims.sub == "alice")
    }

    @Test("non-redacted Bearer header parses live without a cache")
    func nonRedactedBearerLiveParse() throws {
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: "Bearer \(Self.token)",
            decoded: [:]
        )
        let jwt = try #require(result)
        #expect(jwt.claims.sub == "alice")
    }

    @Test("non-redacted bare token parses live without a cache")
    func nonRedactedBareTokenLiveParse() throws {
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: Self.token,
            decoded: [:]
        )
        let jwt = try #require(result)
        #expect(jwt.claims.sub == "alice")
    }

    @Test("custom header with embedded token is detected live")
    func customHeaderLiveDetection() throws {
        let result = HeaderJWTResolver.jwt(
            forHeader: "X-Access-Token",
            value: Self.token,
            decoded: [:]
        )
        let jwt = try #require(result)
        #expect(jwt.claims.sub == "alice")
    }

    @Test("non-token header value returns nil")
    func nonTokenReturnsNil() {
        let result = HeaderJWTResolver.jwt(
            forHeader: "X-Request-ID",
            value: "abc-123-def",
            decoded: [:]
        )
        #expect(result == nil)
    }

    @Test("cached JWT wins over live-parseable value")
    func cachedWinsOverLive() throws {
        // The cached token has sub="alice"; the visible value has sub="bob".
        // Resolver MUST prefer the cached version.
        let bob = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJib2IifQ.sig"
        let aliceJWT = try #require(JWT(Self.token))
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: "Bearer \(bob)",
            decoded: ["authorization": aliceJWT]
        )
        #expect(result?.claims.sub == "alice")
    }

    @Test("nil value with no cache returns nil")
    func nilValueNoCache() {
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: nil,
            decoded: [:]
        )
        #expect(result == nil)
    }

    @Test("nil value WITH cache still returns cached JWT")
    func nilValueWithCacheReturnsCache() throws {
        let cached = try #require(JWT(Self.token))
        let result = HeaderJWTResolver.jwt(
            forHeader: "Authorization",
            value: nil,
            decoded: ["authorization": cached]
        )
        #expect(result?.claims.sub == "alice")
    }

    @Test("full flow: NetworkLogger → snapshot → resolver renders badge")
    func endToEndFlow() async throws {
        // End-to-end contract: record a request with a Bearer JWT, read back the
        // sanitised event, and ask the resolver whether it would render a badge.
        let logger = NetworkLogger()
        let event = NetworkEvent(
            request: NetworkRequestSnapshot(
                url: URL(string: "https://api.example.com/x")!,
                httpMethod: "POST",
                headers: ["Authorization": "Bearer \(Self.token)"]
            )
        )
        await logger.record(event)
        let stored = try #require(await logger.snapshot().first)

        // What HeadersSection sees:
        let value = stored.request.headers["Authorization"]
        let decoded = stored.request.decodedJWTs
        let result = HeaderJWTResolver.jwt(forHeader: "Authorization", value: value, decoded: decoded)

        #expect(value == "•••redacted•••",
                "default redactor must hide the raw token")
        #expect(result?.claims.sub == "alice",
                "badge contract must still resolve a JWT from decodedJWTs")
    }
}
