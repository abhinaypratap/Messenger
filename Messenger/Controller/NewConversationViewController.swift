import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {

    public var completion: ((SearchResult) -> Void)?

    private var users = [[String: String]]()
    private var results = [SearchResult]()
    private var hasFetched = false

    private let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search for users"
        return bar
    }()

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return tableView
    }()

    private let spinner = JGProgressHUD(style: .dark)

    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(noResultsLabel)
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width / 4, y: (view.height - 200) / 2, width: view.width / 2, height: 200)
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        searchBar.becomeFirstResponder()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
    }
}

extension NewConversationViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard
            let text = searchBar.text,
            !text.replacingOccurrences(of: " ", with: "").isEmpty
        else {
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        searchUsers(query: text)
    }

    func searchUsers(query: String) {
        // Check if array has Firebase results
        if hasFetched {
            // If it does: filter
            filterUsers(with: query)
        } else {
            // If not: fetch then filter
            DatabaseManager.shared.getAllUsers { [weak self] result in
                switch result {
                case .success(let usersCollection):
                    self?.hasFetched = true
                    self?.users = usersCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    debugPrint("Failed to get users: \(error)")
                }
            }

        }
    }

    func filterUsers(with term: String) {
        // Update the UI: either show results or show `noResultsLabel`
        guard
            hasFetched,
            let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
        else {
            return
        }

        let safeEmail = Utility.replacePeriodAndAtWithHyphen(text: currentUserEmail)

        spinner.dismiss(animated: true)

        let results: [SearchResult] = users.filter({
            guard
                let email = $0["email"],
                email != safeEmail
            else {
                return false
            }

            guard
                let name = $0["name"]?.lowercased()
            else {
                return false
            }

            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard
                let email = $0["email"],
                let name = $0["name"]
            else {
                return nil
            }
            return SearchResult(name: name, email: email)
        })

        self.results = results
        updateUI()
    }

    func updateUI() {
        if results.isEmpty {
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        } else {
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
}

extension NewConversationViewController {
    @objc
    fileprivate func dismissSelf() {
        dismiss(animated: true)
    }
}

extension NewConversationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        // TODO: Fix it, rather than suppressing it.
        // swiftlint:disable:next force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        90
    }
}

extension NewConversationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Start conversation
        let targetUserData = results[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.completion?(targetUserData)
        }
    }
}
