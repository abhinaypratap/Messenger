import UIKit
import SDWebImage
import FirebaseAuth

final class ProfileViewController: UIViewController {

    var data = [ProfileViewModel]()

    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.tableHeaderView = createTableaHeader()
    }

    func createTableaHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/" + fileName

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame: CGRect(x: (view.width - 150) / 2, y: 75, width: 150, height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)

        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
            case  .success(let url):
                imageView.sd_setImage(with: url)
            case .failure(let error):
                debugPrint("Failed to get download URL: \(error)")
            }
        }

        return headerView
    }
}

extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        // TODO: Fix it, rather than suppressing it.
        // swiftlint:disable:next force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setup(with: viewModel)
//
//        if #available(iOS 14.0, *) {
//            var contentConfig = cell.defaultContentConfiguration()
//            contentConfig.text = data[indexPath.row]
//            contentConfig.textProperties.alignment = .center
//            contentConfig.textProperties.color = .red
//            cell.contentConfiguration = contentConfig
//            return cell
//        } else {
//            cell.textLabel?.text = data[indexPath.row]
//            cell.textLabel?.textAlignment = .center
//            cell.textLabel?.textColor = .red
//            return cell
//        }
        return cell
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}

extension ProfileViewController {
    fileprivate func configure() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.showsVerticalScrollIndicator = false
        data.append(
            ProfileViewModel(
                viewModelType: .info,
                title: "Name: \((UserDefaults.standard.value(forKey: "name") as? String) ?? "No name")",
                color: UIColor.secondarySystemBackground,
                alignment: .center,
                handler: nil
            )
        )
        data.append(
            ProfileViewModel(
                viewModelType: .info,
                title: "Email: \((UserDefaults.standard.value(forKey: "email") as? String) ?? "No email")",
                color: UIColor.secondarySystemBackground,
                alignment: .center,
                handler: nil
            )
        )
        data.append(
            ProfileViewModel(
                viewModelType: .logout,
                title: "Log Out",
                color: UIColor.yellow,
                alignment: .center,
                handler: { [weak self] in
                    guard let strongSelf = self else { return }
                    let sheetController = UIAlertController(title: "Log Out",
                                                            message: "Do you want to log out?",
                                                            preferredStyle: .actionSheet)
                    sheetController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    sheetController.addAction(UIAlertAction(title: "Log Out",
                                                            style: .destructive,
                                                            handler: { [weak self] _ in
                        guard let strongSelf = self else { return }
                        UserDefaults.standard.setValue(nil, forKey: "email")
                        UserDefaults.standard.setValue(nil, forKey: "name")
                        do {
                            try FirebaseAuth.Auth.auth().signOut()

                            let viewController = LoginViewController()
                            let navigationController = UINavigationController(rootViewController: viewController)
                            navigationController.modalPresentationStyle = .fullScreen
                            strongSelf.present(navigationController, animated: true)
                        } catch {
                            debugPrint("Failed to log out: \(#function)")
                        }

                    }))
                    strongSelf.present(sheetController, animated: true)
                })
        )
    }
}

class ProfileTableViewCell: UITableViewCell {
    static let identifier = "ProfileTableViewCell"
    public func setup(with viewModel: ProfileViewModel) {
        textLabel?.text = viewModel.title
        textLabel?.textAlignment = viewModel.alignment
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
        }
    }
}
