import OSLog

/// Central loggers. Never log user content (names, notes, photos);
/// only technical events and counts.
enum AppLogger {
    private static let subsystem = "com.angiemarz.looksy"
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let images = Logger(subsystem: subsystem, category: "images")
    static let backup = Logger(subsystem: subsystem, category: "backup")
    static let stylist = Logger(subsystem: subsystem, category: "stylist")
}
