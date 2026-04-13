//
//  PanarRunWidgetLiveActivity.swift
//  PanarRunWidget
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes (requis par le package live_activities)
// Ce struct doit s'appeler exactement LiveActivitiesAppAttributes.

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// MARK: - Widget

struct PanarRunWidgetLiveActivity: Widget {
    let appGroupId = "group.com.panar.run"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            PanarLockScreenView(context: context, appGroupId: appGroupId)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            let ud = UserDefaults(suiteName: appGroupId)
            let distance = ud?.string(forKey: context.attributes.prefixedKey("distance")) ?? "0.00"
            let duration = ud?.string(forKey: context.attributes.prefixedKey("duration")) ?? "00:00"
            let pace     = ud?.string(forKey: context.attributes.prefixedKey("pace"))     ?? "--:--"

            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 20) {
                        Image(systemName: "figure.run").foregroundColor(.green)
                        PanarMetricCell(value: distance, unit: "km")
                        PanarMetricCell(value: duration, unit: "durée")
                        PanarMetricCell(value: pace,     unit: "/km")
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundColor(.green)
            } compactTrailing: {
                Text(distance + "km").font(.caption2.bold().monospacedDigit())
            } minimal: {
                Image(systemName: "figure.run").foregroundColor(.green)
            }
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen View

struct PanarLockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    let appGroupId: String

    var body: some View {
        let ud       = UserDefaults(suiteName: appGroupId)
        let distance = ud?.string(forKey: context.attributes.prefixedKey("distance")) ?? "0.00"
        let duration = ud?.string(forKey: context.attributes.prefixedKey("duration")) ?? "00:00"
        let pace     = ud?.string(forKey: context.attributes.prefixedKey("pace"))     ?? "--:--"

        HStack(spacing: 0) {
            Image(systemName: "figure.run")
                .font(.title)
                .foregroundColor(.green)
                .frame(width: 48)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 36)
                .padding(.horizontal, 12)

            HStack(spacing: 0) {
                PanarMetricCell(value: distance, unit: "km")
                Spacer()
                PanarMetricCell(value: duration, unit: "durée")
                Spacer()
                PanarMetricCell(value: pace,     unit: "/km")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct PanarMetricCell: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(.white)
            Text(unit)
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.6))
        }
    }
}
