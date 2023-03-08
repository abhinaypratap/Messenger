import UIKit

final class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Conversations"
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        /// `bool(forKey:)`: The Boolean value associated with the specified key.
        /// If the specified key doesn‘t exist, this method returns `false`.
        let isLoggedIn = UserDefaults.standard.bool(forKey: "logged_in")

        if !isLoggedIn {
            let viewController = LoginViewController()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: false)
        }
    }
}
