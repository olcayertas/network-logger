import Foundation
import Testing
@testable import NetworkLogger

@Suite("Filters")
struct FiltersTests {

    @Test("status code range")
    func statusCodeRange() {
        let event200 = makeEvent(status: 200)
        let event404 = makeEvent(status: 404)
        let event500 = makeEvent(status: 500)

        let filter = StatusCodeRangeFilter.clientError
        #expect(filter.includes(event200) == false)
        #expect(filter.includes(event404) == true)
        #expect(filter.includes(event500) == false)
    }

    @Test("status code without response excluded")
    func statusCodeNoResponse() {
        let event = makeEvent(status: nil)
        #expect(!StatusCodeRangeFilter.success.includes(event))
    }

    @Test("method filter case insensitive")
    func methodFilter() {
        let get = makeEvent(method: "GET")
        let post = makeEvent(method: "POST")
        let filter = MethodFilter("get")
        #expect(filter.includes(get))
        #expect(!filter.includes(post))
    }

    @Test("host filter allow / block")
    func hostFilter() {
        let api = makeEvent(host: "api.example.com")
        let analytics = makeEvent(host: "analytics.example.com")
        #expect(HostFilter(allowing: ["api.example.com"]).includes(api))
        #expect(!HostFilter(allowing: ["api.example.com"]).includes(analytics))
        #expect(HostFilter(blocking: ["analytics.example.com"]).includes(api))
        #expect(!HostFilter(blocking: ["analytics.example.com"]).includes(analytics))
    }

    @Test("url substring filter")
    func urlSubstring() {
        let event = makeEvent(url: "https://api.example.com/v1/items/12345")
        #expect(URLSubstringFilter("items").includes(event))
        #expect(URLSubstringFilter("ITEMS").includes(event))
        #expect(!URLSubstringFilter("notfound").includes(event))
    }

    @Test("composite filter AND")
    func compositeAnd() {
        let event = makeEvent(method: "POST", host: "api.example.com", status: 201)
        let filter = CompositeFilter(
            MethodFilter("POST"),
            StatusCodeRangeFilter.success
        )
        #expect(filter.includes(event))

        let badFilter = CompositeFilter(
            MethodFilter("GET"),
            StatusCodeRangeFilter.success
        )
        #expect(!badFilter.includes(event))
    }

    @Test("anyOf filter OR")
    func anyOfOr() {
        let event = makeEvent(status: 404)
        let filter = AnyOfFilter(
            StatusCodeRangeFilter.clientError,
            StatusCodeRangeFilter.serverError
        )
        #expect(filter.includes(event))
    }

    @Test("not filter inverts")
    func notFilter() {
        let event = makeEvent(status: 200)
        let filter = NotFilter(StatusCodeRangeFilter.success)
        #expect(!filter.includes(event))
    }

    @Test("default redactor masks Authorization")
    func defaultRedactor() {
        let redactor = Redaction.makeHeaderRedactor()
        let result = redactor([
            "Authorization": "Bearer x",
            "Cookie": "session=1",
            "Accept": "json",
        ])
        #expect(result["Authorization"] == "•••redacted•••")
        #expect(result["Cookie"] == "•••redacted•••")
        #expect(result["Accept"] == "json")
    }

    private func makeEvent(
        url: String = "https://api.example.com/v1",
        method: String = "GET",
        host: String? = nil,
        status: Int? = nil
    ) -> NetworkEvent {
        let urlObject: URL = {
            if let host {
                return URL(string: "https://\(host)/v1")!
            }
            return URL(string: url)!
        }()
        var event = NetworkEvent(
            request: NetworkRequestSnapshot(url: urlObject, httpMethod: method)
        )
        if let status {
            event.response = NetworkResponseSnapshot(statusCode: status)
        }
        return event
    }
}
