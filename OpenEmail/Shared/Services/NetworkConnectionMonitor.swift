import Foundation
import Network
import Logging

public class NetworkConnectionMonitor {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")

    public private(set) var isOnCellular = false

    public func start() {
        guard monitor == nil else { return }

        Log.debug("start monitoring network")

        monitor = NWPathMonitor()

        monitor?.pathUpdateHandler = { [weak self] path in
            if path.usesInterfaceType(.cellular) {
                self?.isOnCellular = true
                Log.debug("on cellular network")
            } else {
                self?.isOnCellular = false
                Log.debug("not on cellular network")
            }
        }

        monitor?.start(queue: queue)
    }

    public func stop() {
        Log.debug("stop monitoring network")
        monitor?.cancel()
        monitor = nil
    }
}
