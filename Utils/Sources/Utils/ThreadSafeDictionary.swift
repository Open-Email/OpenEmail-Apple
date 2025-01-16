import Foundation

public class AtomicDictionary<Key: Hashable, Value>: Collection {
    private var internalDictionary: [Key: Value]
    private let queue = DispatchQueue(label: "AtomicDictionary", attributes: .concurrent)

    public var keys: Dictionary<Key, Value>.Keys {
        queue.sync {
            return self.internalDictionary.keys
        }
    }

    public var values: Dictionary<Key, Value>.Values {
        queue.sync {
            return self.internalDictionary.values
        }
    }

    public var startIndex: Dictionary<Key, Value>.Index {
        queue.sync {
            return self.internalDictionary.startIndex
        }
    }

    public var endIndex: Dictionary<Key, Value>.Index {
        queue.sync {
            return self.internalDictionary.endIndex
        }
    }

    public init(dict: [Key: Value] = [Key: Value]()) {
        internalDictionary = dict
    }

    public func index(after i: Dictionary<Key, Value>.Index) -> Dictionary<Key, Value>.Index {
        queue.sync {
            return self.internalDictionary.index(after: i)
        }
    }

    public subscript(key: Key) -> Value? {
        set(newValue) {
            queue.async(flags: .barrier) { [weak self] in
                self?.internalDictionary[key] = newValue
            }
        }

        get {
            queue.sync {
                return self.internalDictionary[key]
            }
        }
    }

    public subscript(index: Dictionary<Key, Value>.Index) -> Dictionary<Key, Value>.Element {
        queue.sync {
            return self.internalDictionary[index]
        }
    }
    
    public func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) { [weak self] in
            self?.internalDictionary.removeValue(forKey: key)
        }
    }

    public func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.internalDictionary.removeAll()
        }
    }
}
