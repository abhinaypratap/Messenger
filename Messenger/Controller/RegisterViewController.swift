import UIKit
import FirebaseAuth
import JGProgressHUD

final class RegisterViewController: UIViewController {

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle")
        imageView.tintColor = .gray
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        return imageView
    }()

    private let firstNameField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .words
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "First Name"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()

    private let lastNameField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .words
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Last Name"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()

    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()

    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password"
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()

    private let createAccountButton: UIButton = {
        let button = UIButton()
        button.setTitle("Create Account", for: [])
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: [])
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    private let spinner = JGProgressHUD(style: .dark)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Create Account"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Login",
            style: .done,
            target: self,
            action: #selector(didTapLogin)
        )
        configureHierarchy()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        imageView.layer.cornerRadius = imageView.width / 2.0

        firstNameField.frame = CGRect(x: 30,
                                      y: imageView.bottom + 10,
                                      width: scrollView.width - 60,
                                      height: 52)

        lastNameField.frame = CGRect(x: 30,
                                     y: firstNameField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)

        emailField.frame = CGRect(x: 30,
                                  y: lastNameField.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)

        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)

        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)

        createAccountButton.frame = CGRect(x: 30,
                                           y: passwordField.bottom + 10,
                                           width: scrollView.width - 60,
                                           height: 52)
    }
}

extension RegisterViewController {
    fileprivate func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(lastNameField)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(createAccountButton)

        let gesture = UITapGestureRecognizer(target: self,
                                             action: #selector(didTapChangeProfilePicture))
        imageView.addGestureRecognizer(gesture)

        firstNameField.delegate = self
        lastNameField.delegate = self
        emailField.delegate = self
        passwordField.delegate = self
        createAccountButton.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
    }

    @objc
    fileprivate func didTapLogin() {
        navigationController?.popViewController(animated: true)
    }

    @objc
    fileprivate func didTapChangeProfilePicture() {
        presentPhotoActionSheet()
    }

    @objc
    // TODO: Fix it, rather than suppressing it.
    // swiftlint:disable:next function_body_length
    fileprivate func registerButtonTapped() {
        firstNameField.resignFirstResponder()
        lastNameField.resignFirstResponder()
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()

        guard
            let firstName = firstNameField.text,
            let lastName = lastNameField.text,
            let email = emailField.text,
            let password = passwordField.text,
            !firstName.isEmpty,
            !lastName.isEmpty,
            !email.isEmpty,
            !password.isEmpty,
            password.count >= 6
        else {
            presentRegistrationErrorAlert()
            return
        }

        spinner.show(in: view)

        DatabaseManager.shared.isRegistered(with: email) { [weak self] registered in
            guard let strongSelf = self else { return }

            DispatchQueue.main.async {
                strongSelf.spinner.dismiss(animated: true)
            }

            guard !registered else {
                /// User already registered with this email
                strongSelf.presentRegistrationErrorAlert(
                    message: "Looks like a user is already registered with this email."
                )
                return
            }

            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password) { result, error in
                guard result != nil, error == nil else {
                    debugPrint("Failed: \(#function)")
                    return
                }

                UserDefaults.standard.setValue(email, forKey: "email")
                UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")

                let user = User(
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                )

                DatabaseManager.shared.insertUser(with: user) { success in
                    if success {
                        // upload image
                        guard let image = strongSelf.imageView.image, let data = image.pngData() else { return }
                        let fileName = user.profilePictureFileName
                        StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                            switch result {
                            case .success(let downloadURL):
                                UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
                                debugPrint(downloadURL)
                            case .failure(let error):
                                debugPrint("Storage manager error: \(error)")
                            }
                        }
                    }
                }

                strongSelf.navigationController?.dismiss(animated: true)
            }
        }
    }

    func presentRegistrationErrorAlert(message: String = "Please enter all information to create account.") {
        let alertController = UIAlertController(
            title: "Oops",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(
            title: "Dismiss",
            style: .cancel)
        )
        present(alertController, animated: true)
    }
}

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == firstNameField {
            lastNameField.becomeFirstResponder()
        } else if textField == lastNameField {
            emailField.becomeFirstResponder()
        } else if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            registerButtonTapped()
        }
        return true
    }
}

extension RegisterViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func presentPhotoActionSheet() {
        let actionSheetController = UIAlertController(title: "Profile Picture",
                                                      message: "How would you like to select a picture?",
                                                      preferredStyle: .actionSheet)
        actionSheetController.addAction(UIAlertAction(title: "Cancel",
                                                      style: .cancel,
                                                      handler: nil))
        actionSheetController.addAction(UIAlertAction(title: "Take Photo",
                                                      style: .default,
                                                      handler: { [weak self] _ in
            self?.presentCamera()
        }))
        actionSheetController.addAction(UIAlertAction(title: "Choose Photo",
                                                      style: .default,
                                                      handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))
        present(actionSheetController, animated: true)
    }

    // TODO: Provide reasonable fallback behavior in situations where
    // the user doesn’t grant access to the requested data.

    /// - Important: Requesting access to protected resources
    /// Supply a usage description string in your app’s `Info.plist` file
    /// that the system can present to a user explaining why your app needs
    /// access. The first time your app attempts to access a protected resource,
    /// the system prompts the person using the app for permission.
    /// Camera:
    /// Key: Include the `NSCameraUsageDescription` key in your app’s
    /// `Info.plist` file. (`Privacy - Camera Usage Description`)
    /// Value: Provide `usage description string`
    func presentCamera() {
        let viewController = UIImagePickerController()
        viewController.sourceType = .camera
        viewController.delegate = self
        viewController.allowsEditing = true
        present(viewController, animated: true)
    }

    func presentPhotoPicker() {
        let viewController = UIImagePickerController()
        viewController.sourceType = .photoLibrary
        viewController.delegate = self
        viewController.allowsEditing = true
        present(viewController, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard
            let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        else {
            return
        }
        imageView.image = selectedImage
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
