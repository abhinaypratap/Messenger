struct User {
    let firstName: String
    let lastName: String
    let email: String

    /// `/images/abhinay-gmail-com_profile_picture.png`
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }

    var safeEmail: String {
        Utility.replacePeriodAndAtWithHyphen(text: email)
    }
}
