#if os(iOS)
import SwiftUI

/// Modal sheet for selecting a `ClosedRange<Date>` to feed into `DateRangeFilter`.
///
/// Offers a fixed set of presets via `DateRangeFilter.Preset` plus a "Custom…" path that
/// reveals two `DatePicker`s. Tap "Clear" to remove the date filter entirely.
struct DateRangePickerView: View {
    @Binding var range: ClosedRange<Date>?
    @Environment(\.dismiss) private var dismiss

    @State private var isCustomActive = false
    @State private var customStart: Date = Date().addingTimeInterval(-3600)
    @State private var customEnd: Date = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(DateRangeFilter.Preset.allCases, id: \.self) { preset in
                        Button {
                            range = preset.range()
                            dismiss()
                        } label: {
                            Label(preset.displayLabel, systemImage: "clock")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section("Custom range") {
                    DatePicker("From", selection: $customStart)
                    DatePicker("To", selection: $customEnd)
                    Button {
                        let lower = min(customStart, customEnd)
                        let upper = max(customStart, customEnd)
                        range = lower...upper
                        dismiss()
                    } label: {
                        Label("Apply custom range", systemImage: "checkmark.circle.fill")
                    }
                }

                if range != nil {
                    Section {
                        Button(role: .destructive) {
                            range = nil
                            dismiss()
                        } label: {
                            Label("Clear date filter", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let range {
                    customStart = range.lowerBound
                    customEnd = range.upperBound
                }
            }
        }
    }
}
#endif
