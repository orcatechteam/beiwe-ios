//
//  Crypto.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import CommonCrypto;
import IDZSwiftCommonCrypto

class Crypto {
    static let sharedInstance = Crypto();
    fileprivate static let defaultRSAPadding: SecPadding = .PKCS1

    func sha256Base64(_ str: String) -> String {
        let sha256: Digest = Digest(algorithm: .sha256);
        _ = sha256.update(string: str);
        let digest: [UInt8] = sha256.final();
        let data = Data(bytes: digest, count: digest.count)
        return data.base64EncodedString();
    }
    
    func sha256Base64URL(_ str: String) -> String {
        return base64ToBase64URL(sha256Base64(str));
    }
    
    func base64URL(_ str: String) -> String {
        return base64ToBase64URL(str.data(using: .utf8)!.base64EncodedString())
    }

    func base64ToBase64URL(_ base64str: String) -> String {
        //        //replaceAll('/', '_').replaceAll('+', '-');
        return base64str.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-");
    }

    func randomBytes(_ length: Int) -> Data? {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { [count=data.count]
            (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, count, mutableBytes)
        }

        if (result == errSecSuccess) {
            return data;
        } else {
            return nil;
        }

    }

    func newAesKey(_ keyLength: Int = 128) -> Data? {
        let length = (keyLength+7) / 8;
        return randomBytes(length);
    }


    func rsaEncryptString(_ str: String, publicKey: SecKey, padding: SecPadding = defaultRSAPadding) throws -> String {
        let blockSize = SecKeyGetBlockSize(publicKey)
        let plainTextData = [UInt8](str.utf8)
        let plainTextDataLength = Int(str.count)
        var encryptedData = [UInt8](repeating: 0, count: Int(blockSize))
        var encryptedDataLength = blockSize

        let status = SecKeyEncrypt(publicKey, padding, plainTextData, plainTextDataLength, &encryptedData, &encryptedDataLength)
        if status != noErr {
            throw NSError(domain: "beiwe.crypto", code: 1, userInfo: [:]);
        }

        let data = Data(bytes: UnsafePointer<UInt8>(encryptedData), count: encryptedDataLength)
        return base64ToBase64URL(data.base64EncodedString(options: []));
    }

    func aesEncrypt(_ iv: Data, key: Data, plainText: String) -> Data? {
        let arrayKey = Array(UnsafeBufferPointer(start: (key as NSData).bytes.bindMemory(to: UInt8.self, capacity: key.count), count: key.count));
        let arrayIv = Array(UnsafeBufferPointer(start: (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv.count), count: iv.count));

        let cryptor = Cryptor(operation:.encrypt, algorithm:.aes, options: .PKCS7Padding, key:arrayKey, iv: arrayIv)
        let cipherText = cryptor.update(string: plainText)?.final()
        if let cipherText = cipherText {
            return Data(cipherText);
        }
        return nil;
    }
    
    func md5(url: URL) -> String? {

        let bufferSize = 1024 * 1024

        do {
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }

            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    return true // Continue
                }
                return false // End of file
            }) { }

            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &context)

            return Data(digest).map { String(format: "%02hhx", $0) }.joined()
            //return String(decoding: Data(digest), as: UTF8.self)

        } catch let error {
            print("unabled to calculate md5 \(error)")
            return nil
        }
    }

}
