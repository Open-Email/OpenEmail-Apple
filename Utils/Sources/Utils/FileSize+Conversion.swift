import Foundation

public extension Int {
    func megabytesToBytes() -> Int {
        let megabytes = Measurement(value: Double(self), unit: UnitInformationStorage.megabytes)
        let bytes = megabytes.converted(to: .bytes)
        return Int(bytes.value)
    }
}
