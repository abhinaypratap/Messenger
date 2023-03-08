import UIKit
import FirebaseDatabase

final class DatabaseManager {
    static let shared = DatabaseManager()
    private init() {}
    private let database = Database.database().reference()
}

extension DatabaseManager {

    /// Checks if user exists for given email
    ///
    /// - Parameters:
    ///   - email: Target email to be checked
    ///   - completion: Async closure to return with result
    public func isRegistered(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }

    /// Save user to the Firebase Database
    ///
    /// - Parameters:
    ///   - user: User details
    ///   - completion: Async closure with returned result
    public func insertUser(with user: User, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { [weak self] error, _ in
            guard let strongSelf = self else { return }
            guard error == nil else {
                debugPrint("Failed to write to database")
                completion(false)
                return
            }

            strongSelf.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    strongSelf.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }

                } else {
                    // create array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
        }
    }
}
