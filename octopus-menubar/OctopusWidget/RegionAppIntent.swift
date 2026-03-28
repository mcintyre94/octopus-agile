import AppIntents

extension Region: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Region" }

    static let caseDisplayRepresentations: [Region: DisplayRepresentation] = [
        .a: "A – Eastern England",
        .b: "B – East Midlands",
        .c: "C – London",
        .d: "D – Merseyside & N. Wales",
        .e: "E – Midlands",
        .f: "F – North Eastern",
        .g: "G – North Western",
        .h: "H – Southern England",
        .j: "J – South Eastern",
        .k: "K – South Western",
        .l: "L – South Wales",
        .m: "M – Yorkshire",
        .n: "N – Southern Scotland",
        .p: "P – Northern Scotland"
    ]
}

struct RegionAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Agile Region"
    static var description = IntentDescription("Choose your UK electricity region.")

    @Parameter(title: "Region")
    var region: Region?

    init() { region = .c }
    init(region: Region) { self.region = region }
}
