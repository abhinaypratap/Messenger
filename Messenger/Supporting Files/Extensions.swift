import UIKit

extension UIView {

    public var width: CGFloat {
        frame.size.width
    }

    public var height: CGFloat {
        frame.size.height
    }

    public var top: CGFloat {
        frame.origin.y
    }

    public var bottom: CGFloat {
        frame.size.height + frame.origin.y
    }

    public var left: CGFloat {
        frame.origin.x
    }

    public var right: CGFloat {
        frame.size.width + frame.origin.x
    }
}

extension Notification.Name {
    /// Notification when the user logs in.
    static let didLogInNotification = Notification.Name("didLogInNotification")
}
