import AppIntents

struct RegionAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Agile Region"
    static var description = IntentDescription("Choose your UK electricity region.")

    @Parameter(title: "Region", optionsProvider: RegionOptionsProvider())
    var regionCode: String

    init() {
        regionCode = "C"
    }

    init(regionCode: String) {
        self.regionCode = regionCode
    }
}

struct RegionOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        IntentItemCollection(items: Region.allCases.map { region in
            IntentItem(region.rawValue, title: LocalizedStringResource(stringLiteral: region.displayName))
        })
    }

    func defaultResult() async -> String? { "C" }
}
