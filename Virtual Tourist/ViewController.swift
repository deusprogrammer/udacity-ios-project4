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

class PhotoCollectionViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    var loadingImageData = UIImagePNGRepresentation(UIImage(named: "loading")!)
    internal var mainContext : NSManagedObjectContext = DataLayerService.managedObjectContext
    
    var pin : AlbumPin!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: PhotoCollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    lazy var fetchedResultsController : NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "AlbumPinPhoto")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdOn", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", argumentArray: [self.pin])
        
        let frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        frc.delegate = self
        
        return frc
    }()
    
    // Display an error modal
    func displayError(title: String, message: String, completionHandler: (() -> Void)! = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) in
            if (completionHandler != nil) {
                completionHandler()
            }
        })
        alertController.addAction(OKAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    // Create a photo with a temporary loading image while we fetch the image from flickr
    func createPhoto(photo: FlickrPhoto, backgroundContext: NSManagedObjectContext) -> AlbumPinPhoto! {
        do {
            // Create image
            let pinPhoto = NSEntityDescription.insertNewObjectForEntityForName("AlbumPinPhoto", inManagedObjectContext: backgroundContext) as! AlbumPinPhoto
            let pin = try backgroundContext.existingObjectWithID(self.pin.objectID) as! AlbumPin
            
            // Store url to fetch later and set temporary loading image
            pinPhoto.title = photo.name
            pinPhoto.createdOn = NSDate()
            pinPhoto.image = self.loadingImageData
            pinPhoto.url = photo.url
            pinPhoto.pin = pin
            
            return pinPhoto
        } catch {
            self.displayError("Core Data Error", message: "Failed to create photos")
        }
        
        return nil
    }
    
    // Fetch the image for an album pin photo and store it
    func fetchImage(photo: AlbumPinPhoto, backgroundContext: NSManagedObjectContext) {
        do {
            // Load image asynchronously
            let url = NSURL(string: photo.url!)
            let data = NSData(contentsOfURL: url!)
            
            photo.image = data
            try backgroundContext.save()
        } catch {
            self.displayError("Core Data Error", message: "Failed to store fetched photo")
        }
    }
    
    // Load and persist a list of flickr photos
    func loadAndPersistPhotos(photos: Array<FlickrPhoto>) {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.parentContext = mainContext
        
        var pinPhotos : [AlbumPinPhoto] = []
        
        backgroundContext.performBlockAndWait({
            do {
                // Persist photos with temporary loading image
                for photo in photos {
                    let pinPhoto = self.createPhoto(photo, backgroundContext: backgroundContext)
                    pinPhotos.append(pinPhoto)
                }
                try backgroundContext.save()
                
                // Fetch images
                for pinPhoto in pinPhotos {
                    self.fetchImage(pinPhoto, backgroundContext: backgroundContext)
                }
                
                // Persist parent context
                self.mainContext.performBlock({
                    do {
                        try self.mainContext.save()
                    } catch {
                        self.displayError("Core Data Error", message: "Failed to store photos")
                    }
                })
            } catch {
                print(error)
                self.displayError("Core Data Error", message: "Failed to store photos")
            }
        })

        dispatch_async(dispatch_get_main_queue(), {
            self.newCollectionButton.enabled = true
        })
    }
    
    // Clear all photos related to this collection view's pin
    func clearPhotos() {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.parentContext = mainContext
        
        backgroundContext.performBlockAndWait({
            do {
                let pin = try backgroundContext.existingObjectWithID(self.pin.objectID) as! AlbumPin
                
                // Delete photos
                for photo in pin.photos! {
                    backgroundContext.deleteObject(photo as! NSManagedObject)
                }
                try backgroundContext.save()
                
                // Persist parent context
                self.mainContext.performBlock({
                    do {
                        try self.mainContext.save()
                    } catch {
                        print(error)
                        self.displayError("Core Data Error", message: "Failed to clear photos")
                    }
                })
            } catch {
                print(error)
                self.displayError("Core Data Error", message: "Failed to clear photos")
            }
        })
    }
    
    // Delete a single album pin photo
    func deletePhoto(photo: AlbumPinPhoto) {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        backgroundContext.parentContext = mainContext
        
        backgroundContext.performBlockAndWait({
            do {
                // Delete photo
                let ctxPhoto = try backgroundContext.existingObjectWithID(photo.objectID) as! AlbumPinPhoto
                backgroundContext.deleteObject(ctxPhoto as NSManagedObject)
                try backgroundContext.save()
                
                // Persist parent context
                self.mainContext.performBlock({
                    do {
                        try self.mainContext.save()
                    } catch {
                        print(error)
                        self.displayError("Core Data Error", message: "Failed to delete photo")
                    }
                })
            } catch {
                print(error)
                self.displayError("Core Data Error", message: "Failed to delete photo")
            }
        })
    }
    
    // Pull new photos from flickr for a given latitude and longitude at street level
    func updatePhotos(lat lat: Double, lon: Double) {
        service.getRandomPhotosFromLocation(
            FlickrAccuracy.Street,
            lat: "\(lat)",
            lon: "\(lon)",
            pageSize: 12,
            onComplete: {(photos: Array<FlickrPhoto>!) -> Void in
                // If no photos here, then display error and close collection view
                if photos.count == 0 {
                    self.displayError("No images found", message: "No images at this location, try placing a pin elsewhere", completionHandler: {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.navigationController?.popViewControllerAnimated(true)
                        })
                    })
                    return
                }

                self.loadAndPersistPhotos(photos)
            },
            onError: {(statusCode: Int, payload: Any) -> Void in
                var dict = payload as! Dictionary<String, String>
                self.displayError("Image load failure", message: "Images failed to load: \(dict["error"])")
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
        
        self.newCollectionButton.enabled = true
        
        do {
            // If pin has no photos, then retrieve them
            if (pin.photos == nil || pin.photos?.count == 0) {
                self.newCollectionButton.enabled = false
                updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
            }
            
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
    }
    
    override func viewDidLoad() {
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.collectionView.reloadData()
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionCell", forIndexPath:  indexPath) as! PhotoCollectionItem
        
        // Set image view to load image keeping aspect ratio
        cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        // Load image into cell
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! AlbumPinPhoto
        cell.imageView.image = UIImage(data: photo.image!)

        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sections = fetchedResultsController.sections {
            let currentSection = sections[section]
            return currentSection.numberOfObjects
        }
        
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! AlbumPinPhoto
        self.deletePhoto(photo)
    }
    
    @IBAction func newCollectionButtonPressed(sender: AnyObject) {
        newCollectionButton.enabled = false
        
        // Delete all photos from this pin and load new ones
        self.clearPhotos()
        
        // Get new photos
        self.updatePhotos(lat: Double(self.pin.latitude!), lon: Double(self.pin.longitude!))
    }
}

class MapViewController : UIViewController, UIGestureRecognizerDelegate, MKMapViewDelegate {
    var service = FlickrApiService(apiKey: FlickrConfig.apiKey)
    var pins : [AlbumPin]!
    var context = DataLayerService.managedObjectContext
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewWillAppear(animated: Bool) {
        self.mapView.removeAnnotations(mapView.annotations)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.handleTap(_:)))
        gestureRecognizer.delegate = self
        
        self.mapView.addGestureRecognizer(gestureRecognizer)
        self.mapView.delegate = self
        loadPins()
    }

    // Display an error modal
    func displayError(title: String, message: String, completionHandler: (() -> Void)! = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) in
            if (completionHandler != nil) {
                completionHandler()
            }
        })
        alertController.addAction(OKAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    // Load all the pins asynchronously
    func loadPins() {
        // Fetch all persisted pins
        let fetchRequest = NSFetchRequest(entityName: "AlbumPin")
        
        let asynchronousFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { (asynchronousFetchResult) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.pins = asynchronousFetchResult.finalResult as! [AlbumPin]
                
                // Load each pin into the map view
                for pin in self.pins {
                    var coordinate = CLLocationCoordinate2D()
                    coordinate.latitude = Double(pin.latitude!)
                    coordinate.longitude = Double(pin.longitude!)
                    
                    let annotation = AlbumPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = "Album"
                    annotation.pin = pin
                    
                    self.mapView.addAnnotation(annotation)
                }
            })
        }
        
        do {
            try context.executeRequest(asynchronousFetchRequest)
        } catch {
            self.displayError("Core Data Error", message: "Unable to load pins")
        }
    }
    
    func handleTap(sender: UILongPressGestureRecognizer) {
        // On the end of a long tap gesture, create and store a new pin
        if (sender.state == .Began) {
            // Retrieve the coordinates of where we tapped
            let location = sender.locationInView(mapView)
            let coordinate = mapView.convertPoint(location, toCoordinateFromView: mapView)
            
            // Create new album pin object and persist it
            let pin = NSEntityDescription.insertNewObjectForEntityForName("AlbumPin", inManagedObjectContext: context) as! AlbumPin
            pin.longitude = coordinate.longitude
            pin.latitude  = coordinate.latitude
            pin.createdOn = NSDate()
            
            do {
                try context.save()
            } catch {
                self.displayError("Core Data Error", message: "Unable to save pin")
            }
            
            // Add the pin to our list of pins
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
        
        // Define how to present the pin
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
        // Retrieve the selected pin
        guard let annotation = view.annotation else { return }
        let pinAnnotation = annotation as! AlbumPointAnnotation
        
        // Open photo collection view for the selected pin
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoCollectionViewController") as! PhotoCollectionViewController
        viewController.pin = pinAnnotation.pin
        self.navigationController?.pushViewController(viewController, animated: true)
        mapView.deselectAnnotation(annotation, animated: true)
    }
}
