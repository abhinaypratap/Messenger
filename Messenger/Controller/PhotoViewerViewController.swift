import UIKit
import SDWebImage

final class PhotoViewerViewController: UIViewController {

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let url: URL

    init(with url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
}

extension PhotoViewerViewController {
    fileprivate func configure() {
        title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        view.addSubview(imageView)
        imageView.sd_setImage(with: url, completed: nil)
        imageView.frame = view.bounds
    }
}
