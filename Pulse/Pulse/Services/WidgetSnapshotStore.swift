import Foundation
import SwiftUI
import WidgetKit

/// Write-side store used by the main app. The widget extension has its own read-only
/// mirror in `Pulse Widget/WidgetSnapshotStore.swift`.
enum WidgetSnapshotStore {
    private static let key = "pulse.widget.snapshot.v1"

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder.snapshot.encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
        // Nudge WidgetKit so timelines refresh promptly instead of waiting up to ~15 min.
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder.snapshot.decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}

private extension JSONEncoder {
    static let snapshot: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let snapshot: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension Color {
    /// Renders an SRGB color to a "RRGGBB" hex string (no alpha, no leading hash).
    /// Used to hand the EventCategory accent across to the widget without dragging the
    /// whole Color/Theme machinery into the extension.
    func hexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let to255 = { (c: CGFloat) -> Int in max(0, min(255, Int(round(c * 255)))) }
        return String(format: "%02X%02X%02X", to255(r), to255(g), to255(b))
    }
}
