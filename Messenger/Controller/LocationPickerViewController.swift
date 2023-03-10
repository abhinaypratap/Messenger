import UIKit
import MapKit
import CoreLocation

final class LocationPickerViewController: UIViewController {

    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private var isPickable = true

    private let mapView: MKMapView = {
        let view = MKMapView()
        return view
    }()

    init(coordinates: CLLocationCoordinate2D?, isPickable: Bool) {
        self.coordinates = coordinates
        self.isPickable = isPickable
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

extension LocationPickerViewController {
    fileprivate func configure() {
        view.backgroundColor = .systemBackground
        view.addSubview(mapView)
        mapView.frame = view.bounds
        mapView.isUserInteractionEnabled = true
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Send",
                style: .done,
                target: self,
                action: #selector(didTapSend)
            )
            let gesture = UITapGestureRecognizer(
                target: self,
                action: #selector(didTapMap(_:))
            )
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            mapView.addGestureRecognizer(gesture)
        } else {
            // Just showing location
            guard let coordinates = self.coordinates else { return }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            mapView.addAnnotation(pin)
        }
    }

    @objc
    fileprivate func didTapSend() {
        guard let coordinates else { return }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }

    @objc
    fileprivate func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: mapView)
        let coordinates = mapView.convert(locationInView, toCoordinateFrom: mapView)
        self.coordinates = coordinates
        for annotation in mapView.annotations {
            mapView.removeAnnotation(annotation)
        }
        // Drop a pin on that location
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        mapView.addAnnotation(pin)
    }
}
