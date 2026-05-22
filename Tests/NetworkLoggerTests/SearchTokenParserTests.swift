import Foundation
import Testing
@testable import NetworkLogger

@Suite("SearchTokenParser")
struct SearchTokenParserTests {
    @Test("parses host token")
    func parsesHost() {
        let result = SearchTokenParser.parse("host:api.example.com")
        #expect(result.tokens == [.host("api.example.com")])
        #expect(result.freeText == "")
    }

    @Test("uppercases method values")
    func uppercasesMethod() {
        let result = SearchTokenParser.parse("method:post")
        #expect(result.tokens == [.method("POST")])
    }

    @Test("parses path token")
    func parsesPath() {
        let result = SearchTokenParser.parse("path:/users")
        #expect(result.tokens == [.path("/users")])
    }

    @Test("parses single status code")
    func parsesSingleStatus() {
        let result = SearchTokenParser.parse("statusCode:200")
        #expect(result.tokens == [.statusCode(StatusCodeRange(lower: 200, upper: 200))])
    }

    @Test("parses XX class")
    func parsesXXClass() {
        let result = SearchTokenParser.parse("statusCode:2XX")
        #expect(result.tokens == [.statusCode(StatusCodeRange(lower: 200, upper: 299))])
    }

    @Test("parses half-open range")
    func parsesHalfOpen() {
        let result = SearchTokenParser.parse("statusCode:200..<300")
        #expect(result.tokens == [.statusCode(StatusCodeRange(lower: 200, upper: 299))])
    }

    @Test("parses closed range")
    func parsesClosedRange() {
        let result = SearchTokenParser.parse("statusCode:400...499")
        #expect(result.tokens == [.statusCode(StatusCodeRange(lower: 400, upper: 499))])
    }

    @Test("accepts shorthand keys: status, code")
    func acceptsShorthandKeys() {
        let a = SearchTokenParser.parse("status:200")
        let b = SearchTokenParser.parse("code:200")
        #expect(a.tokens == [.statusCode(StatusCodeRange(lower: 200, upper: 200))])
        #expect(b.tokens == [.statusCode(StatusCodeRange(lower: 200, upper: 200))])
    }

    @Test("collects free text remainder")
    func collectsFreeText() {
        let result = SearchTokenParser.parse("host:foo method:GET cats and dogs")
        #expect(result.tokens.count == 2)
        #expect(result.freeText == "cats and dogs")
    }

    @Test("unknown keys fall through to free text")
    func unknownKeyFallsThrough() {
        let result = SearchTokenParser.parse("foo:bar baz")
        #expect(result.tokens.isEmpty)
        #expect(result.freeText == "foo:bar baz")
    }

    @Test("malformed status code stays as free text")
    func malformedStatus() {
        let result = SearchTokenParser.parse("statusCode:abc")
        #expect(result.tokens.isEmpty)
        #expect(result.freeText == "statusCode:abc")
    }

    @Test("empty value falls through")
    func emptyValueFallsThrough() {
        let result = SearchTokenParser.parse("host:")
        #expect(result.tokens.isEmpty)
        #expect(result.freeText == "host:")
    }

    @Test("token rawSpelling round-trips for simple forms")
    func tokenRawSpellingRoundTrip() {
        let spellings = ["host:api.example.com", "method:POST", "path:/users", "statusCode:200", "statusCode:2XX"]
        for spelling in spellings {
            let parsed = SearchTokenParser.parse(spelling)
            #expect(parsed.tokens.count == 1, "expected one token for \(spelling)")
            #expect(parsed.tokens.first?.rawSpelling == spelling, "rawSpelling mismatch for \(spelling)")
        }
    }

    @Test("rawSpelling collapses ranges to the canonical XX form when possible")
    func canonicalRawSpelling() {
        // 200...299 round-trips to the more compact 2XX form
        let parsed = SearchTokenParser.parse("statusCode:200...299")
        #expect(parsed.tokens.first?.rawSpelling == "statusCode:2XX")
    }

    @Test("rawSpelling preserves explicit irregular ranges")
    func irregularRangeRawSpelling() {
        let parsed = SearchTokenParser.parse("statusCode:204...207")
        #expect(parsed.tokens.first?.rawSpelling == "statusCode:204...207")
    }
}
