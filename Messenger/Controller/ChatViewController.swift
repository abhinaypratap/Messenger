import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVKit
import CoreLocation

final class ChatViewController: MessagesViewController {

    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?

    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    public let otherUserEmail: String
    private var conversationID: String?
    public var isNewConversation = false
    var messages = [Message]()

    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)
        return Sender(photoURL: "", senderId: safeEmail, displayName: "Me")
    }

    init(with email: String, id: String?) {
        self.otherUserEmail = email
        self.conversationID = id
        super.init(nibName: nil, bundle: nil)
        if let conversationID {
            listenForMessages(id: conversationID, shouldScrollToBottom: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        setupInputButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        messageInputBar.inputTextView.becomeFirstResponder()
    }

    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }

    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagsForConversations(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                debugPrint("Total messages: \(messages.count)")

                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                debugPrint("Failed to get messages: \(error)")
            }
        }
    }
}

extension ChatViewController {
    fileprivate func configure() {
        view.backgroundColor = .darkGray
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
//        messagesCollectionView.reloadData()
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard
            let messageID = createMessageID(),
            let conversationID,
            let name = title,
            let selfSender
        else {
            return
        }

        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            //
            let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".png"

            // Upload image
            StorageManager.shared.uploadPhoto(with: imageData, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else { return}
                switch result {
                case .success(let urlString):
                    // Send message
                    debugPrint("Uploaded photo message: \(urlString)")

                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus")
                    else {
                        return
                    }

                    let media = Media(
                        url: url,
                        image: nil,
                        placeholderImage: placeholder,
                        size: .zero
                    )

                    let message = Message(
                        sender: selfSender,
                        messageId: messageID,
                        sentDate: Date(),
                        kind: .photo(media)
                    )

                    DatabaseManager.shared.sendMessage(
                        to: conversationID,
                        otherUserEmail: strongSelf.otherUserEmail,
                        name: name,
                        newMessage: message) { success in
                            debugPrint(success == true ? "Photo message sent" : "Failed to send photo message")
//                            if success {
//                                debugPrint("Photo message sent")
//                            }
//
//                            if !success {
//                                debugPrint("Failed to send photo message")
//                            }
                        }
                case .failure(let error):
                    debugPrint("Failed to upload photo message: \(error)")
                }
            }
        } else if let videoURL = info[.mediaURL] as? URL {
            let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".mov"

            // Upload video
            StorageManager.shared.uploadVideo(with: videoURL, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else { return}
                switch result {
                case .success(let urlString):
                    // Send message
                    debugPrint("Uploaded video message: \(urlString)")

                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus")
                    else {
                        return
                    }

                    let media = Media(
                        url: url,
                        image: nil,
                        placeholderImage: placeholder,
                        size: .zero
                    )

                    let message = Message(
                        sender: selfSender,
                        messageId: messageID,
                        sentDate: Date(),
                        kind: .video(media)
                    )

                    DatabaseManager.shared.sendMessage(
                        to: conversationID,
                        otherUserEmail: strongSelf.otherUserEmail,
                        name: name,
                        newMessage: message) { success in
                            debugPrint(success == true ? "Video message sent" : "Failed to send video message")
//                            if success {
//                                debugPrint("Video message sent")
//                            } else {
//                                debugPrint("Failed to send video message")
//                            }
                        }
                case .failure(let error):
                    debugPrint("Failed to upload video message: \(error)")
                }
            }
        }
    }
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach media",
            message: "What would you like to attach?",
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))

        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))

        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { _ in

        }))

        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(actionSheet, animated: true)
    }

    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach photo",
            message: "What would you like to attach a photo from?",
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))

        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(actionSheet, animated: true)
    }

    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach video",
            message: "What would you like to attach a video from?",
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))

        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(actionSheet, animated: true)
    }

    private func presentLocationPicker() {
        let viewController = LocationPickerViewController(coordinates: nil, isPickable: true)
        viewController.title = "Pick a Location"
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.completion = { [weak self] selectedCoordinates in
            guard let strongSelf = self else { return }
            guard
                let messageID = strongSelf.createMessageID(),
                let conversationID = strongSelf.conversationID,
                let name = strongSelf.title,
                let selfSender = strongSelf.selfSender
            else {
                return
            }
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            debugPrint("Longitude: \(longitude)\nLatitude: \(latitude)")

            let location = Location(
                location: CLLocation(
                    latitude: latitude,
                    longitude: longitude
                ),
                size: .zero
            )

            let message = Message(
                sender: selfSender,
                messageId: messageID,
                sentDate: Date(),
                kind: .location(location)
            )

            DatabaseManager.shared.sendMessage(
                to: conversationID,
                otherUserEmail: strongSelf.otherUserEmail,
                name: name,
                newMessage: message) { success in
                    if success {
                        debugPrint("Locationmessage sent")
                    } else {
                        debugPrint("Failed to send location message")
                    }
                }
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
}

extension ChatViewController: MessagesDataSource {
    var currentSender: SenderType {
        if let selfSender { return selfSender }

        fatalError("selfSender is nil, email should be cached")
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messages.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messages[indexPath.section]
    }
}

extension ChatViewController: MessagesLayoutDelegate {}

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let viewController = LocationPickerViewController(coordinates: coordinates, isPickable: false)
            viewController.title = "Location"
            navigationController?.pushViewController(viewController, animated: true)
        default:
            break
        }
    }
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let media):
            guard let imageURL = media.url else { return }
            let viewController = PhotoViewerViewController(with: imageURL)
            navigationController?.pushViewController(viewController, animated: true)
        case .video(let media):
            guard let videoURL = media.url else { return }
            let viewController = AVPlayerViewController()
            viewController.player = AVPlayer(url: videoURL)
            present(viewController, animated: true)
        default:
            break
        }
    }
}

extension ChatViewController: MessagesDisplayDelegate {
    func configureMediaMessageImageView(
        _ imageView: UIImageView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        guard let message = message as? Message else { return }
        switch message.kind {
        case .photo(let media):
            guard let imageURL = media.url else { return }
            imageView.sd_setImage(with: imageURL, completed: nil)
        default:
            break
        }
    }

    func backgroundColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // Our message that we've sent
            return .link
        } else {
            return .secondarySystemBackground
        }
    }

    func configureAvatarView(
        _ avatarView: AvatarView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            if let currentUserImageURL = self.senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL)
            } else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
                let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        debugPrint("\(error)")
                    }
                }
            }
        } else {
            if let otherUserImageURL = self.otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserImageURL)
            } else {
                let email = self.otherUserEmail
                let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        debugPrint("\(error)")
                    }
                }
            }
        }
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        messageInputBar.inputTextView.resignFirstResponder()
        messageInputBar.inputTextView.text = ""
        guard
            !text.replacingOccurrences(of: " ", with: "").isEmpty,
            let selfSender = self.selfSender,
            let messageID = createMessageID()
        else {
            return
        }

        debugPrint("Sending: \(text)")

        let message = Message(sender: selfSender, messageId: messageID, sentDate: Date(), kind: .text(text))

        // Send Message
        if isNewConversation {
            // Create conversation in the database
            DatabaseManager.shared.createNewConversation(
                with: otherUserEmail,
                name: self.title ?? "User",
                firstMessage: message
            ) { [weak self] success in
                if success {
                    self?.isNewConversation = false
                    let newConversationID = "conversation_\(message.messageId)"
                    self?.conversationID = newConversationID
                    self?.listenForMessages(id: newConversationID, shouldScrollToBottom: true)
                    debugPrint("Message sent")
                } else {
                    debugPrint("Message failed to send")
                }
            }
        } else {
            // Append to existing conversation
            guard
                let conversationID,
                let name = title
            else { return }
            DatabaseManager.shared.sendMessage(
                to: conversationID,
                otherUserEmail: otherUserEmail,
                name: name,
                newMessage: message
            ) { success in
                    if success {
                        debugPrint("Message sent")
                    } else {
                        debugPrint("Message failed to send")
                    }
                }
        }
    }

    private func createMessageID() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        let dateString = Self.dateFormatter.string(from: Date())
        guard
            let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
        else {
            return nil
        }

        let safeCurrentEmail = Utility.replacePeriodAndAtWithHyphen(text: currentUserEmail)
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        debugPrint("Message ID: \(newIdentifier)")
        return newIdentifier
    }
}
