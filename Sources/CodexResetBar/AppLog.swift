import OSLog

enum AppLog {
    static let subsystem = "com.lcc.codexresetbar"
    static let app = Logger(subsystem: Self.subsystem, category: "app")
    static let providers = Logger(subsystem: Self.subsystem, category: "providers")
    static let codexbar = Logger(subsystem: Self.subsystem, category: "codexbar")
}
