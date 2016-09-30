//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Main on 9/26/16.
//  Copyright © 2016 Michael Main. All rights reserved.
//

import MapKit
import UIKit

class PhotoCollectionItem : UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
}

class PhotoCollectionView : UICollectionView {
}

class PhotoCollectionViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    
    var lat : Double!
    var lon : Double!
    
    var photos : Array<FlickrPhoto> = []
    var photosLoaded = 0
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: PhotoCollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    func updatePhotos(lat lat: Double, lon: Double) {
        self.photosLoaded = 0
        
        service.searchByLocation(
            FlickrAccuracy.Street,
            lat: "\(lat)",
            lon: "\(lon)",
            page: 1,
            perPage: 10,
            onComplete: {(photos: Array<FlickrPhoto>!) -> Void in
                for photo in photos {
                    print("\(photo.name) => \(photo.url)")
                }
                
                self.photos = photos
                dispatch_async(dispatch_get_main_queue(), {
                    self.collectionView.reloadData()
                })
            },
            onError: {(statusCode: Int, payload: Any) -> Void in
                print("Status: \(statusCode) => \(payload)")
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        // We will create an MKPointAnnotation for each dictionary in "locations". The
        // point annotations will be stored in this array, and then provided to the map view.
        var annotations = [MKPointAnnotation]()
        
        // The lat and long are used to create a CLLocationCoordinates2D instance.
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        // Here we create the annotation and set its coordiate
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        
        // Finally we place the annotation in an array of annotations.
        annotations.append(annotation)
        
        // Add annotation and then center on pin
        self.mapView.addAnnotations(annotations)
        self.mapView.setCenterCoordinate(coordinate, animated: true)
        
        self.newCollectionButton.enabled = false
        
        updatePhotos(lat: self.lat, lon: self.lon)
    }
    
    override func viewDidLoad() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionCell", forIndexPath:  indexPath) as! PhotoCollectionItem
        let photo = photos[indexPath.row]
        
        // Set image view to load image keeping aspect ratio
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        // Set image to loading image
        cell.imageView.image = UIImage(named: "loading")
        
        // Load image asynchronously
        let url = NSURL(string: photo.url)
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        dispatch_async(queue) { () -> Void in
            let data = NSData(contentsOfURL: url!)
            let img = UIImage(data: data!)!
            self.photosLoaded += 1
            dispatch_async(dispatch_get_main_queue(), {
                cell.imageView.image = img
                
                if (self.photosLoaded == self.photos.count) {
                    self.newCollectionButton.enabled = true
                }
            })
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    @IBAction func newCollectionButtonPressed(sender: AnyObject) {
        updatePhotos(lat: self.lat, lon: self.lon)
    }
}

class MapViewController : UIViewController, UIGestureRecognizerDelegate {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MapViewController.handleTap(_:)))
        gestureRecognizer.delegate = self
        mapView.addGestureRecognizer(gestureRecognizer)
        
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func handleTap(gestureReconizer: UILongPressGestureRecognizer) {
        let location = gestureReconizer.locationInView(mapView)
        let coordinate = mapView.convertPoint(location, toCoordinateFromView: mapView)
        
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoCollectionViewController") as! PhotoCollectionViewController
        viewController.lat = coordinate.latitude
        viewController.lon = coordinate.longitude
        
        self.navigationController?.pushViewController(viewController, animated: true)
        
        // Add annotation:
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
}