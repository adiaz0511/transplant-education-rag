import CryptoKit
import Foundation
import Security

struct RequestSigner: Sendable {
    let config: BackendConfig

    func signedRequest(
        path: String,
        method: String,
        bodyData: Data,
        timeoutInterval: TimeInterval = 120
    ) throws -> URLRequest {
        guard let baseURL = config.baseURL,
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.configurationError("The backend base URL is invalid.")
        }

        guard !config.appID.isEmpty else {
            throw APIError.configurationError("The backend app ID is missing.")
        }

        guard !config.sharedSecret.isEmpty else {
            throw APIError.configurationError("The backend shared secret is missing.")
        }

        let normalizedMethod = method.uppercased()
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = try makeNonceHex(byteCount: 16)
        let signature = makeSignature(
            method: normalizedMethod,
            path: path,
            timestamp: timestamp,
            nonce: nonce,
            bodyData: bodyData
        )

        var request = URLRequest(url: url)
        request.httpMethod = normalizedMethod
        request.timeoutInterval = timeoutInterval
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.appID, forHTTPHeaderField: "X-App-Id")
        request.setValue(config.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")

        print("")
        print("====== SIGNED REQUEST ======")
        print("Method: \(normalizedMethod)")
        print("Path: \(path)")
        print("Base URL: \(config.baseURLString)")
        print("Resolved URL: \(url.absoluteString)")
        print("App ID Present: \(!config.appID.isEmpty)")
        print("App Version: \(config.appVersion)")
        print("Timestamp: \(timestamp)")
        print("Nonce: \(nonce)")
        print("Body Bytes: \(bodyData.count)")
        print("Signature Prefix: \(signature.prefix(16))...")
        print("============================")
        print("")
        return request
    }

    private func makeSignature(
        method: String,
        path: String,
        timestamp: String,
        nonce: String,
        bodyData: Data
    ) -> String {
        var message = Data("\(method)\n\(path)\n\(timestamp)\n\(nonce)\n".utf8)
        message.append(bodyData)

        let key = SymmetricKey(data: Data(config.sharedSecret.utf8))
        let digest = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func makeNonceHex(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw APIError.requestSigningFailed("Failed to generate a request nonce.")
        }

        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
