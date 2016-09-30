//
//  FlickrSDK.swift
//  Virtual Tourist
//
//  Created by Michael Main on 9/26/16.
//  Copyright © 2016 Michael Main. All rights reserved.
//

import Foundation

enum FlickrAccuracy : Int {
    case World = 1
    case Country = 3
    case Region = 6
    case City = 11
    case Street = 16
}

struct FlickrPhoto {
    var name : String
    var url : String
    
    init(payload: Dictionary<String, AnyObject>) {
        self.name = payload["title"] as! String
        let farmId = payload["farm"] as! Int
        let serverId = payload["server"] as! String
        let id = payload["id"] as! String
        let secret = payload["secret"] as! String
        self.url  = "https://farm\(farmId).staticflickr.com/\(serverId)/\(id)_\(secret).jpg"
    }
}

class FlickrApiService {
    var apiKey : String
    
    init(apiKey : String) {
        self.apiKey = apiKey
    }
    
    func searchByLocation(
        accuracy : FlickrAccuracy,
        lat : String,
        lon: String,
        page: Int,
        perPage: Int,
        onComplete : ((photos : Array<FlickrPhoto>!) -> Void)! = nil,
        onError: ((statusCode: Int, payload: Any) -> Void)! = nil) {
        let request = NBRestClient.get(
            hostname: "api.flickr.com",
            uri: "/services/rest",
            query: [
                "method": "flickr.photos.search",
                "api_key": self.apiKey,
                "accuracy": accuracy.rawValue,
                "lat": lat,
                "lon": lon,
                "page": page,
                "per_page": perPage,
                "format": "json",
                "nojsoncallback": 1
            ],
            ssl: true)
        
        request.sendAsync({(response: NBRestResponse!) -> Void in
            // If error is set, display it and fail
            if (response.error != nil) {
                print(response.error?.localizedDescription)
                let errorMap = [
                    "error": (response.error?.localizedDescription)!
                    ] as Dictionary<String, AnyObject>
                
                if (onError != nil) {
                    onError(
                        statusCode: 0,
                        payload: errorMap
                    )
                }
                return
            }
            
            // Deserialize json
            var data : AnyObject! = nil
            do {
                try data = NSJSONSerialization.JSONObjectWithData(response.body, options: .AllowFragments)
            } catch {
                if (onError != nil) {
                    onError(
                        statusCode: 0,
                        payload: [
                            "error": "JSON Parsing Error: \(error)"
                        ]
                    )
                }
                return
            }
            
            print("Status Code:  \(response.statusCode)")
            
            // If status code not 201, then fail
            if (response.statusCode != 200) {
                print("HTTP request failed")
                if (onError != nil) {
                    onError(
                        statusCode: response.statusCode,
                        payload: data
                    )
                }
                return
            }
            
            // Acquire the results from the results key at the root of the returned object
            let results = JSONHelper.search("/photos/photo", object: data) as! Array<AnyObject>
            
            // On no results
            if (results.count <= 0) {
                if (onComplete != nil) {
                    onComplete(photos: [])
                }
                
                return
            }
            
            var photos : Array<FlickrPhoto> = []

            for result in results {
                let photo = FlickrPhoto(payload: result as! Dictionary<String, AnyObject>)
                photos.append(photo)
            }
            
            // Run call back if one was provided
            if (onComplete != nil) {
                onComplete(photos: photos)
            }
        })
    }
}