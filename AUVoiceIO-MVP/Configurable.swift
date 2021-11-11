import UIKit

/// A marker protocol providing the `configure(_:)` method to conforming types.
public protocol BlockConfigurable {}

extension BlockConfigurable {
    /// Returns a copy of the value with the provided configuration closure applied.
    public func configure(_ callback: (inout Self) throws -> Void) rethrows -> Self {
        var output = self
        try callback(&output)
        return output
    }
}

extension BlockConfigurable where Self: AnyObject {
    /// Returns the object with the provided configuration closure applied.
    public func configure(_ callback: (Self) throws -> Void) rethrows -> Self {
        try callback(self)
        return self
    }
}

extension UIView: BlockConfigurable {}
