import UIKit

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let color: UIColor
    let alignment: NSTextAlignment
    let handler: (() -> Void)?
}
