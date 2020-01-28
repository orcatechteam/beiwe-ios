//
//  ApiManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/24/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit;
import Alamofire;
import ObjectMapper;
import IDZSwiftCommonCrypto;

#if os(iOS) || os(watchOS) || os(tvOS)
import MobileCoreServices
#elseif os(macOS)
import CoreServices
#endif

extension String: Error {}

protocol ApiRequest {
    associatedtype ApiReturnType : Mappable;
    static var apiEndpoint: String { get };
}

enum ApiErrors: Error {
    case failedStatus(code: Int)
    case fileNotFound
}

struct BodyResponse: Mappable {

    var body: String?;

    init(body: String?) {
        self.body = body;
    }
    init?(map: Map) {

    }

    mutating func mapping(map: Map) {
        body    <- map["body"];
    }
}


class ApiManager {
    static let sharedInstance = ApiManager();
    fileprivate var deviceId = PersistentAppUUID.sharedInstance.uuid;

    fileprivate var hashedPassword = "";

    var password: String {
        set {
            hashedPassword = Crypto.sharedInstance.sha256Base64URL(newValue);
        }
        get {
            return "";
        }
    }

    var patientId: String = "";

    func generateHeaders(_ password: String? = nil) -> [String:String] {
        let headers = [
            "Authorization": "Bearer " + Crypto.sharedInstance.sha256Base64URL(PersistentAppUUID.sharedInstance.uuid),
            "Beiwe-Api-Version": "3",
            "Accept": "application/vnd.beiwe.api.v3, application/json"
        ]
        return headers;
    }

    static func serialErr() -> NSError {
        return NSError(domain: "com.rf.beiwe.studies", code: 2, userInfo: nil);
    }

    func makePostRequest<T: ApiRequest>(_ requestObject: T, password: String? = nil) -> Promise<(T.ApiReturnType, Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = (password == nil) ? hashedPassword : Crypto.sharedInstance.sha256Base64URL(password!);
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        let headers = generateHeaders(password);
        return firstly {
            getNonce(headers:headers);
        }.map { nonce in
            var request = try! URLRequest(url: Constants.apiUrl + T.apiEndpoint, method: .post, headers: headers)
            request = try! URLEncoding.default.encode(request, with: parameters);
            request.setValue(self.digestHeaderParameter(request: request, nonce: nonce), forHTTPHeaderField: "X-Content-Digest");
            return request
        }.then { request -> Promise<(T.ApiReturnType, Int)> in
            return self.doPostRequest(requestObject, request: request);
        }
    }
    
    func makeURLParameterString(parameters: [String:Any])->String {
        var out: String = ""
        parameters.forEach({ (key, value) in
            out = out + "&\(key)=\(value)"
        })
        if out.count > 0 {
            out.remove(at: out.startIndex)
        }
        print("Parameter string: \(out)")
        return out
    }
    
    func computeDigest(time: Int64, nonce: String, content: String)->String{
        return Crypto.sharedInstance.sha256Base64( content + "," + nonce + "," + String(time));
    }
    
    func digestHeaderString(string: String, nonce: String) -> String {
        let time = Int64(Date().timeIntervalSince1970);
        let digest = computeDigest(time: time, nonce: nonce, content:Crypto.sharedInstance.base64URL(string));
        return String(time) + " " + digest
    }
    
    func digestHeaderParameter(request: URLRequest, nonce: String) -> String {
        let content = Crypto.sharedInstance.base64ToBase64URL( request.httpBody!.base64EncodedString() );
        return digestHeaderString(string: content, nonce: nonce)
    }
    
    func digestHeaderFile(file: URL, nonce: String) -> String {
        let md5 = Crypto.sharedInstance.md5(url: file)
        print("MD5: \(md5 ?? "")")
        return digestHeaderString(string: md5 ?? "", nonce: nonce)
    }
    
    func getNonce(headers: [String:String])->Promise<String> {
        return Promise { seal in
            Alamofire.request(Constants.apiUrl + "/nonce", method: .get, headers: headers).responseString { response in
                switch response.result {
                    case .failure(let error):
                        seal.reject(error);
                    case .success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                            seal.reject(ApiErrors.failedStatus(code: statusCode));
                            return
                        }
                        let nonceObject = Nonce(JSONString: response.result.value ?? "")
                        if nonceObject == nil {
                            seal.reject(ApiManager.serialErr())
                            return
                        }
                        seal.fulfill(nonceObject!.nonce ?? "");
                }
            }
        }
    }

    func doPostRequest<T: ApiRequest>(_ requestObject: T, request: URLRequest)->Promise<(T.ApiReturnType, Int)> where T:Mappable {
        return Promise { seal in
            Alamofire.request(request).responseString { response in
                switch response.result {
                case .failure(let error):
                    seal.reject(error);
                case .success:
                    let statusCode = response.response?.statusCode;
                    if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                        seal.reject(ApiErrors.failedStatus(code: statusCode));
                    } else {
                        var returnObject: T.ApiReturnType?;
                        if (T.ApiReturnType.self == BodyResponse.self) {
                            returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                        } else {
                            returnObject = Mapper<T.ApiReturnType>().map(JSONString: response.result.value ?? "");
                        }
                        if let returnObject = returnObject {
                            seal.fulfill((returnObject, statusCode ?? 0));
                        } else {
                            seal.reject(ApiManager.serialErr());
                        }
                    }
                }
            }
        }
    }
    
    func arrayPostRequest<T: ApiRequest>(_ requestObject: T) -> Promise<([T.ApiReturnType], Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = hashedPassword;
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        let headers = generateHeaders(password);
        return firstly {
            getNonce(headers:headers);
        }.map { nonce in
            var request = try! URLRequest(url: Constants.apiUrl + T.apiEndpoint, method: .post, headers: headers)
            request = try! URLEncoding.default.encode(request, with: parameters);
            request.setValue(self.digestHeaderParameter(request: request, nonce: nonce), forHTTPHeaderField: "X-Content-Digest");
            return request
        }.then { request -> Promise<([T.ApiReturnType], Int)> in
            return self.doArrayPostRequest(requestObject, request: request);
        }
    }
    
    func doArrayPostRequest<T: ApiRequest>(_ requestObject: T, request: URLRequest) -> Promise<([T.ApiReturnType], Int)> {
        return Promise { seal in
            Alamofire.request(request)
                .responseString { response in
                    switch response.result {
                    case .failure(let error):
                        seal.reject(error);
                    case .success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                            seal.reject(ApiErrors.failedStatus(code: statusCode));
                        } else {
                            var returnObject: [T.ApiReturnType]?;
                            returnObject = Mapper<T.ApiReturnType>().mapArray(JSONString: response.result.value ?? "");
                            if let returnObject = returnObject {
                                seal.fulfill((returnObject, statusCode ?? 0));
                            } else {
                                seal.reject(ApiManager.serialErr());
                            }
                        }
                    }
            }
        }
    }

    func makeMultipartUploadRequest<T: ApiRequest>(_ requestObject: T, file: URL) -> Promise<(T.ApiReturnType, Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = hashedPassword;
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        parameters.removeValue(forKey: "file");
        let headers = generateHeaders();
        let url = Constants.apiUrl + T.apiEndpoint;
        return getNonce(headers: headers).then { nonce in
            self.doMultipartUploadRequest(requestObject, url: url, parameters: parameters, headers: headers, file: file, nonce: nonce);
        }
    }
    
    func mimeType(forPathExtension pathExtension: String) -> String {
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
            return contentType as String
        }

        return "application/octet-stream"
    }
    
    func appendWithDigest(_ multipartFormData: MultipartFormData, nonce:String, name: String, string: String) {
        let headers: HTTPHeaders = [
            "Content-Type": "application/octet-stream",
            "Content-Disposition":"form-data; name=\"\(name)\"",
            "X-Content-Digest-Type": "basic",
            "X-Content-Digest": digestHeaderString(string: string, nonce: nonce),
        ]
        
        let data = string.data(using: .utf8)!
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        multipartFormData.append(stream, withLength: length, headers: headers)
    }
    
    func appendWithDigest(_ multipartFormData: MultipartFormData, nonce: String, name: String, fileURL: URL) throws {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension

        if fileName.isEmpty || pathExtension.isEmpty {
            throw "fileName and pathExtension properties are empty"
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber
        if fileSize == nil {
            throw "could not read file size"
        }
        
        let headers: HTTPHeaders = [
            "Content-Type": mimeType(forPathExtension: pathExtension),
            "Content-Disposition":"form-data; name=\"\(name)\"; filename=\"\(fileName)\"",
            "X-Content-Digest-Type": "md5",
            "X-Content-Digest": digestHeaderFile(file: fileURL, nonce: nonce),
        ]
        
        let stream = InputStream(url: fileURL)
        if stream == nil {
            throw "could not open file input stream"
        }
        // closed by internal method
        
        print("Appending multipart form file")
        
        multipartFormData.append(stream!, withLength: fileSize!.uint64Value, headers: headers)
    }
    
    func doMultipartUploadRequest<T: ApiRequest>(_ requestObject: T, url: String, parameters: [String:Any], headers: [String:String], file: URL, nonce: String) -> Promise<(T.ApiReturnType, Int)> where T: Mappable {
        return Promise { seal in
            Alamofire.upload(multipartFormData: { multipartFormData in
                    do {
                        for (k, v) in parameters {
                            self.appendWithDigest(multipartFormData, nonce: nonce, name: k, string: String(describing: v))
                        }
                        try self.appendWithDigest(multipartFormData, nonce: nonce, name: "file", fileURL: file)
                    } catch {
                        print("unable to append with digest: \(error)")
                    }
                },
                to: url,
                method: .post,
                headers: headers,
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseString { response in
                            switch response.result {
                            case .failure(let error):
                                seal.reject(error);
                            case .success:
                                let statusCode = response.response?.statusCode;
                                if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                                    seal.reject(ApiErrors.failedStatus(code: statusCode));
                                } else {
                                    var returnObject: T.ApiReturnType?;
                                    if (T.ApiReturnType.self == BodyResponse.self) {
                                        returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                                    } else {
                                        returnObject = Mapper<T.ApiReturnType>().map(JSONString: response.result.value ?? "");
                                    }
                                    if let returnObject = returnObject {
                                        seal.fulfill((returnObject, statusCode ?? 0));
                                    } else {
                                        seal.reject(ApiManager.serialErr());
                                    }
                                }
                            }
                            
                        }

                    case .failure(let encodingError):
                        seal.reject(encodingError);
                    }
            });
        }
    }

}
