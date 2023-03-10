import UIKit
import FirebaseDatabase
import MessageKit
import CoreLocation

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

extension DatabaseManager {

    /// Returns dictionary note at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }

    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }

    public enum DatabaseError: Error {
        case failedToFetch
        public var localizedDescription: String {
            switch self {
            case .failedToFetch:
                return "This means --- failed"
            }
        }
    }
}

extension DatabaseManager {
    /// Creates a new conversation with target user email & first message sent
    // TODO: Fix it, rather than suppressing it.
    // swiftlint:disable:next function_body_length
    public func createNewConversation(
        with otherUserEmail: String,
        name: String,
        firstMessage: Message,
        completion: @escaping (Bool) -> Void
    ) {
        guard
            let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
            let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else {
            return
        }
        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: currentEmail)
        let reference = database.child("\(safeEmail)")
        reference.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                debugPrint("User not found: \(#function)")
                return
            }

            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""

            // swiftlint:disable empty_enum_arguments
            switch firstMessage.kind {

            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            // swiftlint:enable empty_enum_arguments


            let conversationID = "conversation_\(firstMessage.messageId)"

            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]

            let recipientNewConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]

            // Update recipient conversation entry

            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    // Append
                    conversations.append(recipientNewConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    // Create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipientNewConversationData])
                }
            }

            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(
                        name: name,
                        conversationID: conversationID,
                        firstMessage: firstMessage,
                        completion: completion
                    )
                }

            } else {
                // conversation array does not exist, create it
                userNode["conversations"] = [
                    newConversationData
                ]

                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(
                        name: name,
                        conversationID: conversationID,
                        firstMessage: firstMessage,
                        completion: completion
                    )
                }
            }
        }
    }

    private func finishCreatingConversation(
        name: String,
        conversationID: String,
        firstMessage: Message,
        completion: @escaping (Bool) -> Void
    ) {
//        {
//            "id": String,
//            "type": text, photo, video,
//            "content":  String,
//            "date": Date()
//            "sender_email": String,
//            "is_read": Bool
//        }

        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        var message = ""

        // swiftlint:disable empty_enum_arguments
        switch firstMessage.kind {

        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        // swiftlint:enable empty_enum_arguments

        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }

        let currentUserEmail = Utility.replacePeriodAndAtWithHyphen(text: myEmail)

        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]

        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]

        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }

    /// Fetches & returns all conversations for the user with passed in email
    public func getAllConversations(
        for email: String,
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let conversations: [Conversation] = value.compactMap { dictionary in
                guard
                    let conversationID = dictionary["id"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool
                else {
                    return nil
                }

                let latestMessageObject = LatestMessage(
                    date: date,
                    text: message,
                    isRead: isRead
                )

                return  Conversation(
                    id: conversationID,
                    name: name,
                    otherUserEmail: otherUserEmail,
                    latestMessage: latestMessageObject
                )
            }
            completion(.success(conversations))
        }
    }

    /// Gets all messages for a given conversation
    public func getAllMessagsForConversations(
        with id: String,
        completion: @escaping (Result<[Message], Error>
        ) -> Void
    ) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let messages: [Message] = value.compactMap { dictionary in
                guard
                    let name = dictionary["name"] as? String,
//                    let isRead = dictionary["is_read"] as? Bool,
                    let messageID = dictionary["id"] as? String,
                    let content = dictionary["content"] as? String,
                    let senderEmail = dictionary["sender_email"] as? String,
                    let type = dictionary["type"] as? String,
                    let dateString = dictionary["date"] as? String,
                    let date = ChatViewController.dateFormatter.date(from: dateString)
                else {
                    return nil
                }

                var kind: MessageKind?

                if type == "photo" {
                    guard
                        let imageURL = URL(string: content),
                        let placeholder = UIImage(systemName: "plus")
                    else {
                        return nil
                    }
                    let media = Media(
                        url: imageURL,
                        image: nil,
                        placeholderImage: placeholder,
                        size: CGSize(
                            width: 300,
                            height: 300
                        )
                    )
                    kind = .photo(media)
                } else if type == "video" {
                    guard
                        let videoURL = URL(string: content),
                        let placeholder = UIImage(systemName: "play.circle")
                    else {
                        return nil
                    }
                    let media = Media(
                        url: videoURL,
                        image: nil,
                        placeholderImage: placeholder,
                        size: CGSize(
                            width: 300,
                            height: 300
                        )
                    )
                    kind = .video(media)
                } else if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard
                        let longitude = Double(locationComponents[0]),
                        let latitude = Double(locationComponents[1])
                    else {
                        return nil
                    }
                    let location = Location(
                        location: CLLocation(latitude: latitude, longitude: longitude),
                        size: CGSize(width: 300, height: 300)
                    )
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }

                guard let kind else { return nil }

                let sender = Sender(
                    photoURL: "",
                    senderId: senderEmail,
                    displayName: name
                )

                return Message(
                    sender: sender,
                    messageId: messageID,
                    sentDate: date,
                    kind: kind
                )
            }
            completion(.success(messages))
        }
    }

    // TODO: Fix it, rather than suppressing it.
    // swiftlint:disable cyclomatic_complexity

    /// Sends a message with target conversation & message
    // TODO: Fix it, rather than suppressing it.
    // swiftlint:disable:next function_body_length
    public func sendMessage(
        to conversation: String,
        otherUserEmail: String,
        name: String,
        newMessage: Message,
        completion: @escaping (Bool) -> Void
    ) {
        // Add new message to messages

        // Update sender latest message

        // Update recipient latest message
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }

        let currentEmail = Utility.replacePeriodAndAtWithHyphen(text: myEmail)

        database.child("\(conversation)/messages").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let strongSelf = self else { return }

            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }

            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""

            // swiftlint:disable empty_enum_arguments
            switch newMessage.kind {

            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
            case .video(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            // swiftlint:enable empty_enum_arguments

            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }

            let currentUserEmail = Utility.replacePeriodAndAtWithHyphen(text: myEmail)

            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]

            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }

                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0

                        for conversationDictionary in currentUserConversations {
                            if let currentID = conversationDictionary["id"] as? String, currentID == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }

                        if var targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": Utility.replacePeriodAndAtWithHyphen(text: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": Utility.replacePeriodAndAtWithHyphen(text: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }

                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }

                        // Update latest message for recipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in

                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]

                            var databaseEntryConversations = [[String: Any]]()
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }

                            if var otherUserConversations = snapshot.value as? [[String: Any]] {

                                var targetConversation: [String: Any]?

                                var position = 0

                                for conversationDictionary in otherUserConversations {
                                    if
                                        let currentID = conversationDictionary["id"] as? String,
                                        currentID == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }

                                if var targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    // Failed to find in current collection
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": Utility.replacePeriodAndAtWithHyphen(text: currentEmail),
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                            } else {
                                // Current collection does not exists
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": Utility.replacePeriodAndAtWithHyphen(text: currentEmail),
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }

                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
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
    }

    // swiftlint:enable cyclomatic_complexity

    public func deleteConversation(conversationID: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)

        debugPrint("Deleting conversation with id: \(conversationID)")
        // Get all conversations for current user

        // Delete conversation in collection with target ID

        // Reset those conversations for the user in database
        let reference = database.child("\(safeEmail)/conversations")
        reference.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationID {
                        debugPrint("Found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                reference.setValue(conversations) { error, _ in
                    guard error == nil else {
                        completion(false)
                        debugPrint("Failed to write new conversations array")
                        return
                    }
                    debugPrint("Deleted conversation")
                    completion(true)
                }
            }
        }
    }

    public func conversationExists(
        with targetRecipientEmail: String,
        completion: @escaping (Result<String, Error>
        ) -> Void) {
        let safeRecipientEmail = Utility.replacePeriodAndAtWithHyphen(text: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = Utility.replacePeriodAndAtWithHyphen(text: senderEmail)
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            // Iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // Get ID
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }

                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        }
    }
}
