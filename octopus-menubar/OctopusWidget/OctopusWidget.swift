import WidgetKit
import SwiftUI

@main
struct OctopusWidgetBundle: WidgetBundle {
    var body: some Widget {
        OctopusWidget()
        ForecastWidget()
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

struct ForecastWidget: Widget {
    let kind: String = "com.callum.OctopusForecastWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: RegionAppIntent.self,
            provider: ForecastWidgetProvider()
        ) { entry in
            ForecastWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Agile 7-Day Forecast")
        .description("Predicted Agile prices for the week ahead, from agilepredict.com.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
