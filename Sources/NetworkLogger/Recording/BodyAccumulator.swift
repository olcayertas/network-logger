import Foundation

struct BodyAccumulator {
    let limit: Int
    private(set) var data = Data()
    private(set) var originalSize: Int64 = 0
    private(set) var truncated = false

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    mutating func append(_ chunk: Data) {
        originalSize += Int64(chunk.count)
        guard limit > 0, data.count < limit else {
            truncated = truncated || !chunk.isEmpty
            return
        }
        let remaining = limit - data.count
        if chunk.count <= remaining {
            data.append(chunk)
        } else {
            data.append(chunk.prefix(remaining))
            truncated = true
        }
    }

    func body(contentType: String?) -> BodyData {
        BodyData(
            data: data,
            originalSize: originalSize,
            truncated: truncated,
            contentType: contentType
        )
    }
}
