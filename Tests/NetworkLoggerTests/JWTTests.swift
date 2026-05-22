import Foundation
import Testing
@testable import NetworkLogger

@Suite("JWT")
struct JWTTests {
    // header: {"alg":"HS256","typ":"JWT"}
    // payload: {"sub":"1234567890","name":"John Doe","iat":1516239022,"exp":1516239322}
    // signature: SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
    private static let exampleJWT =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
        ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkzMjJ9" +
        ".SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    @Test("decodes a well-formed JWT")
    func decodesWellFormed() throws {
        let jwt = try #require(JWT(Self.exampleJWT))
        #expect(jwt.claims.alg == "HS256")
        #expect(jwt.claims.typ == "JWT")
        #expect(jwt.claims.sub == "1234567890")
        #expect(jwt.claims.iat == Date(timeIntervalSince1970: 1516239022))
        #expect(jwt.claims.exp == Date(timeIntervalSince1970: 1516239322))
        #expect(jwt.claims.customKeys == ["name"])
    }

    @Test("expired status detected by exp claim")
    func expiredStatus() throws {
        let jwt = try #require(JWT(Self.exampleJWT))
        // exp is 1516239322 → Jan 2018. So `Date()` is well past it.
        if case .expired = jwt.validity() {
            // ok
        } else {
            Issue.record("Expected expired validity")
        }
    }

    @Test("notYetValid status detected by nbf claim")
    func notYetValidStatus() throws {
        // Synthesize a JWT with nbf in the far future
        let future = Date(timeIntervalSince1970: 4_000_000_000)
        let token = makeJWT(claims: ["nbf": future.timeIntervalSince1970])
        let jwt = try #require(JWT(token))
        if case .notYetValid = jwt.validity() {
            // ok
        } else {
            Issue.record("Expected notYetValid validity")
        }
    }

    @Test("rejects malformed input")
    func rejectsMalformed() {
        #expect(JWT("") == nil)
        #expect(JWT("not.a.jwt") == nil)
        #expect(JWT("one.two") == nil)
        #expect(JWT("a.b.c.d") == nil)
    }

    @Test("decodes audience as either string or array")
    func decodesAudience() throws {
        let singleAudToken = makeJWT(claims: ["aud": "https://example.com"])
        let multiAudToken = makeJWT(claims: ["aud": ["a", "b"]])
        let single = try #require(JWT(singleAudToken))
        let multi = try #require(JWT(multiAudToken))
        #expect(single.claims.aud == ["https://example.com"])
        #expect(multi.claims.aud == ["a", "b"])
    }

    @Test("accepts empty signature segment")
    func acceptsEmptySignature() throws {
        let token = makeJWT(claims: ["sub": "x"], signature: "")
        let jwt = try #require(JWT(token))
        #expect(jwt.signature.isEmpty)
    }

    private func makeJWT(claims: [String: Any], signature: String = "abc") -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        let payload = try! String(data: JSONSerialization.data(withJSONObject: claims), encoding: .utf8)!
        return [
            base64url(Data(header.utf8)),
            base64url(Data(payload.utf8)),
            signature,
        ].joined(separator: ".")
    }

    private func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
