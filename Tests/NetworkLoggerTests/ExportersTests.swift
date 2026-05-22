import Foundation
import Testing
@testable import NetworkLogger

@Suite("Exporters")
struct ExportersTests {

    @Test("cURL exporter formats GET")
    func curlGet() {
        let event = makeEvent(
            url: "https://api.example.com/v1/items?ids=1,2",
            method: "GET",
            headers: ["Accept": "application/json"]
        )
        let curl = CurlExporter.string(for: event)
        #expect(curl.contains("curl -v"))
        #expect(curl.contains("-H \"Accept: application/json\""))
        #expect(curl.contains("\"https://api.example.com/v1/items?ids=1,2\""))
        #expect(!curl.contains("-X GET"))  // default
    }

    @Test("cURL exporter formats POST with body")
    func curlPost() {
        let event = makeEvent(
            url: "https://api.example.com/v1/create",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: Data("{\"name\":\"x\"}".utf8)
        )
        let curl = CurlExporter.string(for: event)
        #expect(curl.contains("-X POST"))
        #expect(curl.contains("-d \"{\\\"name\\\":\\\"x\\\"}\""))
    }

    @Test("Postman exporter emits valid 2.1 collection")
    func postmanValid() throws {
        let event = makeEvent(
            url: "https://api.example.com/v1/users",
            method: "GET",
            headers: ["Accept": "application/json"]
        )
        let data = PostmanExporter.collection(name: "test", from: [event])
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let info = try #require(parsed?["info"] as? [String: Any])
        #expect((info["schema"] as? String)?.contains("v2.1.0") == true)
        let items = parsed?["item"] as? [[String: Any]]
        #expect(items?.count == 1)
    }

    @Test("Plain text exporter includes all sections")
    func plainText() {
        let event = makeEvent(
            url: "https://api.example.com/v1/list",
            method: "GET",
            response: 200,
            responseHeaders: ["Content-Type": "application/json"],
            responseBody: Data("[]".utf8)
        )
        let text = PlainTextExporter.text(for: event)
        #expect(text.contains("*** Overview ***"))
        #expect(text.contains("URL: https://api.example.com/v1/list"))
        #expect(text.contains("Status: 200"))
        #expect(text.contains("*** Request Headers ***"))
        #expect(text.contains("*** Response Body ***"))
        #expect(text.contains("[]"))
    }

    @Test("HAR exporter emits valid JSON with entries")
    func harValid() throws {
        let event = makeEvent(
            url: "https://api.example.com/v1/get",
            method: "GET",
            response: 200,
            responseBody: Data("hello".utf8)
        )
        let data = HARExporter.har(from: [event])
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let log = try #require(parsed?["log"] as? [String: Any])
        #expect((log["version"] as? String) == "1.2")
        let entries = try #require(log["entries"] as? [[String: Any]])
        #expect(entries.count == 1)
        let firstResponse = entries[0]["response"] as? [String: Any]
        #expect((firstResponse?["status"] as? Int) == 200)
    }

    @Test("Exporters preserve header ordering deterministically")
    func deterministicHeaders() {
        let event = makeEvent(
            url: "https://api.example.com/v1/list",
            method: "GET",
            headers: ["B": "2", "A": "1", "C": "3"]
        )
        let curlFirst = CurlExporter.string(for: event)
        let curlSecond = CurlExporter.string(for: event)
        #expect(curlFirst == curlSecond)
        let aIdx = curlFirst.range(of: "\"A:")!
        let bIdx = curlFirst.range(of: "\"B:")!
        let cIdx = curlFirst.range(of: "\"C:")!
        #expect(aIdx.lowerBound < bIdx.lowerBound)
        #expect(bIdx.lowerBound < cIdx.lowerBound)
    }

    private func makeEvent(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        response: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: Data? = nil
    ) -> NetworkEvent {
        var event = NetworkEvent(
            startDate: Date(timeIntervalSince1970: 1_715_000_000),
            request: NetworkRequestSnapshot(
                url: URL(string: url)!,
                httpMethod: method,
                headers: headers,
                body: body.map { BodyData(data: $0) }
            )
        )
        if let response {
            event.response = NetworkResponseSnapshot(
                statusCode: response,
                headers: responseHeaders,
                body: responseBody.map { BodyData(data: $0) }
            )
        }
        return event
    }
}
