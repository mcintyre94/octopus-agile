import WidgetKit
import SwiftUI

@main
struct OctopusWidgetBundle: WidgetBundle {
    var body: some Widget {
        OctopusWidget()
    }
}

struct OctopusWidget: Widget {
    let kind: String = "com.callum.OctopusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: RegionAppIntent.self,
            provider: WidgetProvider()
        ) { entry in
            OctopusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Agile Prices")
        .description("Half-hourly Octopus Agile electricity prices.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
