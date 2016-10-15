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
    var loadingImageData = UIImagePNGRepresentation(UIImage(named: "loading")!)
    
    var pin : AlbumPin!
    
    var photos : Array<FlickrPhoto> = []
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: PhotoCollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    func loadAndPersistPhoto(photo : FlickrPhoto, queue : dispatch_queue_t, asyncGroup : dispatch_group_t) {
        // Create image managed object
        let pinPhoto : AlbumPinPhoto = DataLayerService.createObjectForName("AlbumPinPhoto") as! AlbumPinPhoto
        pinPhoto.title = photo.name
        pinPhoto.image = loadingImageData
        pinPhoto.createdOn = NSDate()
        pinPhoto.pin = pin
        
        // Load image asynchronously
        let url = NSURL(string: photo.url)
        dispatch_group_async(asyncGroup, queue) { () -> Void in
            let data = NSData(contentsOfURL: url!)
            
            dispatch_async(dispatch_get_main_queue(), {
                pinPhoto.image = data
                
                DataLayerService.saveContext()
                self.collectionView.reloadData()
            })
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            DataLayerService.saveContext()
        })
    }
    
    func loadAndPersistPhotos(photos: Array<FlickrPhoto>) {
        let group = dispatch_group_create()
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        for photo in photos {
            self.loadAndPersistPhoto(photo, queue: queue, asyncGroup: group)
        }
        dispatch_group_notify(group, queue, {() -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.newCollectionButton.enabled = true
            })
        })
    }
    
    func updatePhotos(lat lat: Double, lon: Double) {
        service.getRandomPhotosFromLocation(
            FlickrAccuracy.Street,
            lat: "\(lat)",
            lon: "\(lon)",
            pageSize: 10,
            onComplete: {(photos: Array<FlickrPhoto>!) -> Void in
                if photos.count == 0 {
                    let alertController = UIAlertController(title: "No images found", message: "No images found at this location, try placing a pin elsewhere.", preferredStyle: .Alert)
                    let OKAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) in
                        dispatch_async(dispatch_get_main_queue(), {
                            DataLayerService.deleteObject(self.pin)
                            DataLayerService.saveContext()
                            self.navigationController?.popViewControllerAnimated(true)
                        })
                    })
                    alertController.addAction(OKAction)
                    
                    self.presentViewController(alertController, animated: true, completion: nil)
                    return
                }
                
                self.loadAndPersistPhotos(photos)

                dispatch_async(dispatch_get_main_queue(), {
                    self.collectionView.reloadData()
                })
            },
            onError: {(statusCode: Int, payload: Any) -> Void in
                var dict = payload as! Dictionary<String, String>
                let alertController = UIAlertController(title: "Image load failure", message: "Images failed to load: \(dict["error"])", preferredStyle: .Alert)
                let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                alertController.addAction(OKAction)
                
                self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        collectionView.delegate = self
        collectionView.dataSource = self
        
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
        
        // If pin has no photos, then retrieve them
        if (pin.photos == nil || pin.photos?.count == 0) {
            updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
        } else {
            self.collectionView.reloadData()
            self.newCollectionButton.enabled = true
        }
    }
    
    override func viewDidLoad() {
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionCell", forIndexPath:  indexPath) as! PhotoCollectionItem
        
        // Set image view to load image keeping aspect ratio
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        // If the photo is persisted, then load it from core data
        var pinPhotos : [AlbumPinPhoto] = pin.photos?.allObjects as! [AlbumPinPhoto]
        if (pinPhotos.count > indexPath.row) {
            cell.imageView.image = UIImage(data: pinPhotos[indexPath.row].image!)
            return cell
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pin.photos!.count
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // Delete this photo
        var pinPhotos : [AlbumPinPhoto] = self.pin.photos?.allObjects as! [AlbumPinPhoto]
        let photo = pinPhotos[indexPath.row]
        DataLayerService.deleteObject(photo)
        DataLayerService.saveContext()
        
        dispatch_async(dispatch_get_main_queue(), {
            self.collectionView.reloadData()
        })
    }
    
    @IBAction func newCollectionButtonPressed(sender: AnyObject) {
        newCollectionButton.enabled = false
        
        // Delete all photos from this pin and load new ones
        for photo in pin.photos! {
            DataLayerService.deleteObject(photo as! NSManagedObject)
        }
        DataLayerService.saveContext()
        
        // Get new photos
        updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
    }
}

class MapViewController : UIViewController, UIGestureRecognizerDelegate, MKMapViewDelegate {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    var pins : [AlbumPin]!
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewWillAppear(animated: Bool) {
        self.mapView.removeAnnotations(mapView.annotations)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.handleTap(_:)))
        gestureRecognizer.delegate = self
        
        self.mapView.addGestureRecognizer(gestureRecognizer)
        self.mapView.delegate = self
        self.pins = DataLayerService.getObjectForEntityName("AlbumPin") as! [AlbumPin]
        
        for pin in pins {
            var coordinate = CLLocationCoordinate2D()
            coordinate.latitude = Double(pin.latitude!)
            coordinate.longitude = Double(pin.longitude!)
            
            let annotation = AlbumPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Album"
            annotation.pin = pin
            mapView.addAnnotation(annotation)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func loadPins() {
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        dispatch_async(queue) { () -> Void in
            self.pins = DataLayerService.getObjectForEntityName("AlbumPin") as! [AlbumPin]
            for pin in self.pins {
                var coordinate = CLLocationCoordinate2D()
                coordinate.latitude = Double(pin.latitude!)
                coordinate.longitude = Double(pin.longitude!)
                
                let annotation = AlbumPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = "Album"
                annotation.pin = pin
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.mapView.addAnnotation(annotation)
                })
            }
        }
    }
    
    func handleTap(sender: UILongPressGestureRecognizer) {
        if (sender.state == .Ended) {
            print("MAP VIEW TAPPED")

            let location = sender.locationInView(mapView)
            let coordinate = mapView.convertPoint(location, toCoordinateFromView: mapView)
            
            let pin = DataLayerService.createObjectForName("AlbumPin") as! AlbumPin
            pin.longitude = coordinate.longitude
            pin.latitude  = coordinate.latitude
            pin.createdOn = NSDate()
            
            DataLayerService.saveContext()
            
            self.pins.append(pin)
            
            // Add annotation
            let annotation = AlbumPointAnnotation()
            annotation.coordinate = coordinate
            annotation.pin = pin
            annotation.title = "Album"
            mapView.addAnnotation(annotation)
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.animatesDrop = true
            pinView!.canShowCallout = true
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        print("ANNOTATION SELECTED")
        
        guard let annotation = view.annotation else { return }
        let pinAnnotation = annotation as! AlbumPointAnnotation
        
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoCollectionViewController") as! PhotoCollectionViewController
        viewController.pin = pinAnnotation.pin
        
        self.navigationController?.pushViewController(viewController, animated: true)
        mapView.deselectAnnotation(annotation, animated: true)
    }
}
