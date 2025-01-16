import Foundation

enum Formatters {
    static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.formattingContext = .standalone
        return formatter
    }()

    static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        return formatter
    }()
}

extension Int {
    var formattedAsMegaBytes: String {
        let measurement = Measurement(value: Double(self), unit: UnitInformationStorage.megabytes)
        return Formatters.measurementFormatter.string(from: measurement)
    }
}
