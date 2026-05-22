#if os(iOS)
import SwiftUI
import Perception

public struct NetworkLoggerView: View {
    let logger: NetworkLogger
    @State private var listModel: EventListModel?

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                if let listModel {
                    RequestListView(model: listModel, logger: logger)
                } else {
                    ProgressView()
                        .task {
                            let model = EventListModel(logger: logger)
                            model.start()
                            listModel = model
                        }
                }
            }
        }
    }
}
#endif
