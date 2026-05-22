import Foundation
import Testing
@testable import NetworkLogger

@Suite("JWTDetector")
struct JWTDetectorTests {
    private static let token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.abc"

    @Test("finds a JWT in an Authorization Bearer value")
    func findsInBearerHeader() throws {
        let jwt = try #require(JWTDetector.jwtFromAuthorizationHeader("Bearer \(Self.token)"))
        #expect(jwt.claims.sub == "1")
    }

    @Test("strips lowercase bearer prefix")
    func stripsLowercaseBearer() throws {
        _ = try #require(JWTDetector.jwtFromAuthorizationHeader("bearer \(Self.token)"))
    }

    @Test("accepts a raw token without Bearer prefix")
    func acceptsRawToken() throws {
        _ = try #require(JWTDetector.jwtFromAuthorizationHeader(Self.token))
    }

    @Test("locates a JWT embedded in a JSON body")
    func locatesInJSONBody() throws {
        let body = #"{"access_token":"\#(Self.token)","scope":"read"}"#
        let jwt = try #require(JWTDetector.firstJWT(in: body))
        #expect(jwt.claims.sub == "1")
    }

    @Test("returns nil for unrelated text")
    func nilForUnrelated() {
        #expect(JWTDetector.firstJWT(in: "no jwt here") == nil)
    }

    @Test("ignores `eyJ…` substrings that aren't valid JWTs")
    func ignoresInvalidEyJ() {
        // Starts with eyJ but only two parts → not a JWT
        let fake = "eyJfakejunk.junk"
        #expect(JWTDetector.firstJWT(in: fake) == nil)
    }

    @Test("allJWTs returns multiple matches")
    func allReturnsMultiple() {
        let body = "first \(Self.token) middle \(Self.token) end"
        #expect(JWTDetector.allJWTs(in: body).count == 2)
    }
}
