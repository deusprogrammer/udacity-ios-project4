//
//  RestClient.swift
//  REST-Test
//
//  Created by Michael Main on 1/8/15.
//  Copyright (c) 2015 Michael Main. All rights reserved.
//

import Foundation

class NBRestResponse {
    var response : NSHTTPURLResponse?
    var statusCode : Int!
    var contentType : String!
    var headers : Dictionary<String, String>! = [:]
    var body : NSData!
    var error : NSError?
    
    init(error: NSError?) {
        self.error = error
    }
    
    init(statusCode: Int, contentType: String, headers: Dictionary<String, String>, body: NSData) {
        self.statusCode = statusCode
        self.contentType = contentType
        self.headers = headers
        self.body = body
    }
    
    init(response: NSHTTPURLResponse, data: NSData?) {
        self.response = response
        self.statusCode = response.statusCode
        self.contentType = response.allHeaderFields["Content-Type"] as? String
        self.body = data
        
        for (key, value) in response.allHeaderFields {
            headers[key as! String] = value as? String
        }
    }
}

class NBRestRequest {
    var request : NSMutableURLRequest = NSMutableURLRequest()
    var response : NBRestResponse?
    var error : NSError!
    
    var method : String
    var url : String
    var headers : Dictionary<String, String> = [:]
    var contentType: String?
    var acceptType: String?
    var body : String!
    
    var completed : Bool = false
    
    init(method: String, hostname : String, port : String, uri : String, headers : Dictionary<String, String>, body : String, ssl : Bool) {
        url = "http://"
        
        if (ssl) {
            url = "https://"
        }
        
        url += hostname
        
        if (!port.isEmpty) {
            url += ":\(port)"
        }
        
        url += uri
        
        self.body = body
        self.method = method
        
        for (key, value) in headers {
            addHeader(key, value: value)
        }
    }
    
    func addHeader(key : String, value : String) -> NBRestRequest {
        if (key == "Content-Type") {
            contentType = value
        } else if (key == "Accept") {
            acceptType = value
        }
        
        headers[key] = value
        return self
    }
    
    func setContentType(contentType: String) -> NBRestRequest {
        self.contentType = contentType
        return self
    }
    
    func setAcceptType(acceptType: String) -> NBRestRequest {
        self.acceptType = acceptType
        return self
    }
    
    private func setupHeaders() {
        if (contentType != nil) {
            request.addValue(contentType!, forHTTPHeaderField: "Content-Type")
        }
        
        if (acceptType == nil) {
            acceptType = "*/*"
        }
        
        request.addValue(acceptType!, forHTTPHeaderField: "Accept")
        
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
    }
    
    private func setupPayload() {
        if (body != nil) {
            if (method != "GET" && method != "DELETE") {
                request.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
                addHeader("Content-Length", value: "\(body.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))")
            } else {
                url += body
            }
        }
        
        print("\(method) \(url)")
        
        request.URL = NSURL(string: url)
        request.HTTPMethod = method
    }
    
    func sendSync() -> NBRestResponse! {
        self.response = nil
        self.completed = false
    
        // Send asynchronously, but wait for completion
        sendAsync()
        waitForCompletion()
        return self.response
    }
    
    func sendAsync() -> Void {
        sendAsync({(response: NBRestResponse!) -> Void in
        })
    }
    
    func sendAsync(completionHandler: ((response : NBRestResponse!) -> Void)) -> Void {
        self.response = nil
        self.completed = false
        
        // Reset request to empty
        request = NSMutableURLRequest()
        
        // Setup payload and headers
        setupHeaders()
        setupPayload()
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data: NSData?, response:NSURLResponse?, error: NSError?) -> Void in
            if (error != nil || data == nil) {
                print("ERROR: \(error?.description)")
                self.response = NBRestResponse(error: error)
                self.completed = true
                self.error = error
                
                completionHandler(response: self.response)
                
                return
            }
            
            let httpResponse: NSHTTPURLResponse = response as! NSHTTPURLResponse
            
            self.response = NBRestResponse(response: httpResponse, data: data)
            completionHandler(response: self.response)
            self.completed = true
        })
        
        task.resume()
    }
    
    func isComplete() -> Bool {
        return completed
    }
    
    func waitForCompletion() {
        while !completed {}
    }
    
    func getResponse() -> Any? {
        return response
    }
}

class NBRestClient {
    class NBMediaType {
        static var APPLICATION_JSON = "application/json"
        static var APPLICATION_XML = "application/xml"
    }
    
    private class func createQueryString(pairs: Dictionary<String, AnyObject>) -> String {
        var query = ""
        var sep = "?"
        
        for (key, value) in pairs {
            query += "\(sep)\(key)=\(value)"
            sep = "&"
        }
        
        return query
    }
    
    class func get(hostname hostname : String, port : String = "", uri : String, headers : Dictionary<String, String> = [:], query : Dictionary<String, AnyObject> = [:], ssl : Bool = false) -> NBRestRequest {
        let body = createQueryString(query)
        return NBRestRequest(method: "GET", hostname: hostname, port: port, uri: uri, headers: headers, body: body, ssl: ssl)
    }
    
    class func put(hostname hostname : String, port : String = "", uri : String, headers : Dictionary<String, String> = [:], body : String = "", ssl : Bool = false) -> NBRestRequest {
        return NBRestRequest(method: "PUT", hostname: hostname, port: port, uri: uri, headers: headers, body: body, ssl: ssl)
    }
    
    class func post(hostname hostname : String, port : String = "", uri : String, headers : Dictionary<String, String> = [:], body : String = "", ssl : Bool = false) -> NBRestRequest {
        return NBRestRequest(method: "POST", hostname: hostname, port: port, uri: uri, headers: headers, body: body, ssl: ssl)
    }
    
    class func delete(hostname hostname : String, port : String = "", uri : String, headers : Dictionary<String, String> = [:], query : Dictionary<String, AnyObject> = [:], ssl : Bool = false) -> NBRestRequest {
        let body = createQueryString(query)
        return NBRestRequest(method: "DELETE", hostname: hostname, port: port, uri: uri, headers: headers, body: body, ssl: ssl)
    }
}