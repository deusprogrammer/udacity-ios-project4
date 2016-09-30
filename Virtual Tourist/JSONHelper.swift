//
//  JSONHelper.swift
//  OnTheMap
//
//  Created by Michael Main on 7/24/16.
//  Copyright © 2016 Michael Main. All rights reserved.
//

import Foundation

class JSONHelper {
    class func serialize(obj: AnyObject) -> String! {
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(obj, options: .PrettyPrinted)
            return NSString(data: jsonData, encoding: NSUTF8StringEncoding) as String!
        } catch {
            return nil
        }
    }
    
    class func search(path: String, object: Any) -> Any! {
        let pathComponents : Array<String> = path.componentsSeparatedByString("/")
        var currentNode : Any = object
        
        for pathComponent in pathComponents {
            if (pathComponent.isEmpty) {
                continue
            }
            
            let indexStart = pathComponent.characters.indexOf("[")
            let indexEnd   = pathComponent.characters.indexOf("]")
            
            if (indexStart != nil && indexEnd != nil) {
                let pathComponentName = pathComponent.substringToIndex(indexStart!)
                let pathComponentIndex = pathComponent.substringWithRange((indexStart!.advancedBy(1)..<indexEnd!))
                
                if (!pathComponentName.isEmpty) {
                    // Go to dictionary entry
                    if (!(currentNode is Dictionary<String, AnyObject>)) {
                        return nil
                    }
                    
                    
                    let d = currentNode as! Dictionary<String, AnyObject>
                    currentNode = d[pathComponentName]
                }
                
                
                // Go to array element
                if (!(currentNode is Array<Any>)) {
                    return nil
                }
                
                let a = currentNode as! Array<Any>
                currentNode = a[(pathComponentIndex as NSString).integerValue]
            } else {
                // Go to dictionary entry
                if (!(currentNode is Dictionary<String, AnyObject>)) {
                    return nil
                }
                
                let d = currentNode as! Dictionary<String, AnyObject>
                currentNode = d[pathComponent]
            }
        }
        
        return currentNode
    }
}