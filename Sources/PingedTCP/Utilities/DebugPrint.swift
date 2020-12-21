import Foundation

public func print(_ object: AnyObject) {
    #if DEBUG
    Swift.print(object)
    #endif
}
