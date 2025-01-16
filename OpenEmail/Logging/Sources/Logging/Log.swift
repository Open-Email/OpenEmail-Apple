import SwiftyBeaver
import Combine
import Foundation

fileprivate let log = SwiftyBeaver.self

public class Log {
    private init() {}

    private static let memoryDestination = MemoryDestination()
    public static let messagesPublisher: AnyPublisher<String, Never> = Log.memoryDestination.messagesSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    public static var messages: [String] {
        memoryDestination.messages
    }

    private static var didStart = false

    public class func start() {
        guard !didStart else { return }

        // set up logging

        let console = ConsoleDestination()  // log to Xcode Console
        console.levelColor.verbose = "🟣 "
        console.levelColor.debug = "🟢 "
        console.levelColor.info = "🔵 "
        console.levelColor.warning = "🟡 "
        console.levelColor.error = "🔴 "

        log.addDestination(console)

        Self.memoryDestination.minLevel = .info
        log.addDestination(Self.memoryDestination)
    }

    public class func clear() {
        Self.memoryDestination.clear()
    }

    /// log something generally unimportant (lowest priority)
    public class func verbose(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        log.verbose(message(), file: file, function: function, line: line, context: context)
    }

    /// log something which help during debugging (low priority)
    public class func debug(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        log.debug(message(), file: file, function: function, line: line, context: context)
    }

    /// log something which you are really interested but which is not an issue or error (normal priority)
    public class func info(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        log.info(message(), file: file, function: function, line: line, context: context)
    }

    /// log something which may cause big trouble soon (high priority)
    public class func warning(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        log.warning(message(), file: file, function: function, line: line, context: context)

    }

    /// log something which will keep you awake at night (highest priority)
    public class func error(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        log.error(message(), file: file, function: function, line: line, context: context)
    }
}

private class MemoryDestination: BaseDestination {
    private let lock = NSLock()
    private(set) var messages: [String] = []
    let messagesSubject = PassthroughSubject<String, Never>()

    override init() {
        super.init()
        levelColor.verbose = "🟣 "
        levelColor.debug = "🟢 "
        levelColor.info = "🔵 "
        levelColor.warning = "🟡 "
        levelColor.error = "🔴 "
    }

    func clear() {
        messages = []
    }

    public override func send(_ level: SwiftyBeaver.Level, msg: String, thread: String, file: String, function: String, line: Int, context: Any? = nil) -> String? {
        guard let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context) else { return nil }

        lock.withLock {
            messages.append(formattedString)
            messagesSubject.send(formattedString)
        }

        return formattedString
    }
}
