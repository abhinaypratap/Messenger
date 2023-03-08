import Foundation

struct Utility {
    static func replacePeriodAndAtWithHyphen(text: String) -> String {
        var newText = text.replacingOccurrences(of: ".", with: "-")
        newText = newText.replacingOccurrences(of: "@", with: "-")
        return newText
    }
}
