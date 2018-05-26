//
//  CustormUrlProtocolRequestInterceptor.swift
//  NetworkInterceptor
//
//  Created by Kenneth Poon on 26/5/18.
//  Copyright © 2018 Kenneth Poon. All rights reserved.
//

import Foundation

extension CustormUrlProtocolRequestInterceptor: RequestInterceptor {
    public func startRecording() {
        URLProtocol.registerClass(CustormUrlProtocol.self)
        swizzleProtocolClasses()
    }
    
    public func stopRecording() {
        URLProtocol.unregisterClass(CustormUrlProtocol.self)
        swizzleProtocolClasses()
    }
}

@objc public class CustormUrlProtocolRequestInterceptor: NSObject{

    func swizzleProtocolClasses(){
        NSLog("swizzleProtocolClasses 0")
        let instance = URLSessionConfiguration.default
        NSLog("swizzleProtocolClasses 1")
        let uRLSessionConfigurationClass: AnyClass = object_getClass(instance)!
        NSLog("swizzleProtocolClasses 2")
        let m1: Method = class_getInstanceMethod(uRLSessionConfigurationClass, #selector(getter: uRLSessionConfigurationClass.protocolClasses))!
        NSLog("swizzleProtocolClasses 3")
        let m2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.swizzle_protocolClasses))!
        NSLog("swizzleProtocolClasses 4")
        method_exchangeImplementations(m1, m2)
        NSLog("swizzleProtocolClasses 5")
    }
}

extension URLSessionConfiguration {
    
    @objc func swizzle_protocolClasses() -> [AnyClass]? {
        NSLog("swizzle_protocolClasses 0")
        var originalProtocolClasses = self.swizzle_protocolClasses()
        originalProtocolClasses?.insert(CustormUrlProtocol.self, at: 0)
        return originalProtocolClasses
    }
    
}

class CustormUrlProtocol: URLProtocol {
    
    var connection: NSURLConnection?
    var response: URLResponse?
    var data: NSMutableData?
    
    
    static var requestCount = 0
    
    open override class func canInit(with request: URLRequest) -> Bool {
        
        guard let url = request.url, let scheme = url.scheme else {
            return false
        }
        guard ["http", "https"].contains(scheme) else {
            return false
        }
        if let _ = URLProtocol.property(forKey: String(describing: type(of: self)), in: request) {
            return false
        }
        
        if NetworkInterceptor.shared.shouldIgnoreLogging(url: url){
            return false
        }
        
        requestCount = requestCount + 1
        NSLog("Request #\(requestCount): CURL => \(request.cURL)")
        NetworkInterceptor.shared.logRequest(urlRequest: request)
        
        return true
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: String(describing: type(of: self)), in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
    @available(iOS, deprecated: 9.0)
    override func startLoading() {
        self.data = NSMutableData()
        self.connection =  NSURLConnection(request: self.request, delegate: self, startImmediately: true)
    }
    
    override func stopLoading() {
        self.connection?.cancel()
    }
    
    
}

extension CustormUrlProtocol: NSURLConnectionDelegate {
    
    public func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        self.client?.urlProtocol(self, didFailWithError: error)
    }
    
    public func connectionShouldUseCredentialStorage(_ connection: NSURLConnection) -> Bool {
        return true
    }
    
    public func connection(_ connection: NSURLConnection, didReceive challenge: URLAuthenticationChallenge){
        self.client?.urlProtocol(self, didReceive: challenge)
    }
    
    
    public func connection(_ connection: NSURLConnection, didCancel challenge: URLAuthenticationChallenge) {
        self.client?.urlProtocol(self, didCancel: challenge)
    }
    
}

extension CustormUrlProtocol: NSURLConnectionDataDelegate {
    
    
    public func connection(_ connection: NSURLConnection, willSend request: URLRequest, redirectResponse response: URLResponse?) -> URLRequest? {
        if let aResponse = response {
            self.response = aResponse;
            self.client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: aResponse)
        }
        return request;
        
    }
    
    public func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: URLCache.StoragePolicy.allowed)
        self.response = response;
    }
    
    
    public func connection(_ connection: NSURLConnection, didReceive data: Data){
        
        self.client?.urlProtocol(self, didLoad: data)
        self.data?.append(data)
    }
    
    public func connection(_ connection: NSURLConnection, willCacheResponse cachedResponse: CachedURLResponse) -> CachedURLResponse? {
        return cachedResponse
    }
    
    
    public func connectionDidFinishLoading(_ connection: NSURLConnection) {
        self.client?.urlProtocolDidFinishLoading(self)
    }
}
