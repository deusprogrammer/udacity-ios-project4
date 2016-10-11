//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Main on 9/26/16.
//  Copyright © 2016 Michael Main. All rights reserved.
//

import MapKit
import UIKit
import CoreData

class PhotoCollectionItem : UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
}

class PhotoCollectionView : UICollectionView {
}

class PhotoCollectionViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    
    var pin : AlbumPin!
    
    var photos : Array<FlickrPhoto> = []
    var photosLoaded = 0
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: PhotoCollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    func updatePhotos(lat lat: Double, lon: Double) {
        self.photosLoaded = 0
        
        // If pin has no photos, then retrieve them
        if (pin.photos == nil || pin.photos?.count == 0) {
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
    }
    
    override func viewWillAppear(animated: Bool) {
        // We will create an MKPointAnnotation for each dictionary in "locations". The
        // point annotations will be stored in this array, and then provided to the map view.
        var annotations = [MKPointAnnotation]()
        
        // The lat and long are used to create a CLLocationCoordinates2D instance.
        let coordinate = CLLocationCoordinate2D(latitude: Double(pin.latitude!), longitude: Double(pin.longitude!))
        
        // Here we create the annotation and set its coordiate
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        
        // Finally we place the annotation in an array of annotations.
        annotations.append(annotation)
        
        // Add annotation and then center on pin
        self.mapView.addAnnotations(annotations)
        self.mapView.setCenterCoordinate(coordinate, animated: true)
        
        self.newCollectionButton.enabled = false
        
        updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
    }
    
    override func viewDidLoad() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionCell", forIndexPath:  indexPath) as! PhotoCollectionItem
        
        // Set image view to load image keeping aspect ratio
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        // Set image to loading image
        cell.imageView.image = UIImage(named: "loading")
        
        // If the photo is persisted, then load it from core data
        var pinPhotos : [AlbumPinPhoto] = pin.photos?.allObjects as! [AlbumPinPhoto]
        if (pinPhotos.count > indexPath.row) {
            cell.imageView.image = UIImage(data: pinPhotos[indexPath.row].image!)
            return cell
        }
        
        // Otherwise look in the flickr images loaded earlier
        let photo = photos[indexPath.row]
        
        // Load image asynchronously
        let url = NSURL(string: photo.url)
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        dispatch_async(queue) { () -> Void in
            let data = NSData(contentsOfURL: url!)
            
            let img = UIImage(data: data!)!
            
            self.photosLoaded += 1
            dispatch_async(dispatch_get_main_queue(), {
                cell.imageView.image = img
                
                // Create image managed object and save it
                let pinPhoto : AlbumPinPhoto = DataLayerService.createObjectForName("AlbumPinPhoto") as! AlbumPinPhoto
                pinPhoto.title = photo.name
                pinPhoto.image = data
                pinPhoto.pin = self.pin
                
                DataLayerService.saveContext()
                
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
        updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
    }
}

class MapViewController : UIViewController, UIGestureRecognizerDelegate {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    var pins : [AlbumPin]!
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewWillAppear(animated: Bool) {
        self.pins = DataLayerService.getObjectForEntityName("AlbumPin") as! [AlbumPin]
        
        for pin in pins {
            var coordinate = CLLocationCoordinate2D()
            coordinate.latitude = Double(pin.latitude!)
            coordinate.longitude = Double(pin.longitude!)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }
    }
    
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
        
        let pin = DataLayerService.createObjectForName("AlbumPin") as! AlbumPin
        pin.longitude = coordinate.longitude
        pin.latitude  = coordinate.latitude
        
        self.pins.append(pin)
        
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoCollectionViewController") as! PhotoCollectionViewController
        viewController.pin = pin
        
        DataLayerService.saveContext()
        
        self.navigationController?.pushViewController(viewController, animated: true)
        
        // Add annotation:
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
}
