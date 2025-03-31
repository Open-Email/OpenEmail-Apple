extension Array {
    func distinctBy<K: Hashable>(_ selector: (Element) -> K) -> [Element] {
        var set = Set<K>()
        var result = [Element]()
        for element in self {
            let key = selector(element)
            if set.insert(key).inserted {
                result.append(element)
            }
        }
        return result
    }
}
