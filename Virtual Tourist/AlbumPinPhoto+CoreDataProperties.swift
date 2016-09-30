//
//  AlbumPinPhoto+CoreDataProperties.swift
//  Virtual Tourist
//
//  Created by Michael Main on 9/29/16.
//  Copyright © 2016 Michael Main. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension AlbumPinPhoto {

    @NSManaged var title: String?
    @NSManaged var image: NSData?
    @NSManaged var pin: NSManagedObject?

}
