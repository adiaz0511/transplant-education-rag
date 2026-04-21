import Foundation

struct APIClient: Sendable {
    let config: BackendConfig
    let baseURL: String
    private let session: URLSession
    private let requestLimiter: APIRequestLimiter
    private let requestSigner: RequestSigner

    init(
        config: BackendConfig = BackendConfig(),
        requestTimeout: TimeInterval = 120,
        resourceTimeout: TimeInterval = 300
    ) {
        self.config = config
        self.baseURL = config.baseURLString
        self.requestLimiter = APIRequestLimiter.shared
        self.requestSigner = RequestSigner(config: config)

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        self.session = URLSession(configuration: configuration)
    }

    func ask(query: String, onChunk: @escaping @Sendable (String) async -> Void) async throws -> String {
        try await streamRequest(
            endpoint: .ask,
            path: "/ask",
            body: ["query": query],
            onChunk: onChunk
        )
    }

    func lesson(
        topic: String,
        instructions: String,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        try await streamRequest(
            endpoint: .lesson,
            path: "/lesson",
            body: requestBody(topic: topic, instructions: instructions),
            onChunk: onChunk
        )
    }

    func quiz(
        topic: String,
        instructions: String,
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        try await streamRequest(
            endpoint: .quiz,
            path: "/quiz",
            body: requestBody(topic: topic, instructions: instructions),
            onChunk: onChunk
        )
    }

    private func streamRequest(
        endpoint: APIRequestLimiter.Endpoint,
        path: String,
        body: [String: String],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let bodyData = try encodeBody(body)
        let lease = try await requestLimiter.acquire(endpoint: endpoint, body: body)
        let requestBodyText = String(data: bodyData, encoding: .utf8)
        let request: URLRequest
        let url: URL

        do {
            request = try requestSigner.signedRequest(
                path: path,
                method: "POST",
                bodyData: bodyData
            )
            url = request.url ?? URL(string: baseURL + path) ?? URL(fileURLWithPath: "/")
        } catch {
            logRequestFailure(
                stage: "signing",
                endpoint: endpoint,
                path: path,
                url: URL(string: baseURL + path),
                requestBodyText: requestBodyText,
                error: error
            )
            await requestLimiter.cancel(lease)
            throw error
        }

        logOutboundRequest(
            endpoint: endpoint,
            request: request,
            requestBodyText: requestBodyText
        )

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch is CancellationError {
            await requestLimiter.cancel(lease)
            throw CancellationError()
        } catch {
            if shouldStartCooldown(for: error.localizedDescription) {
                await requestLimiter.registerRateLimitSignal()
            }
            logRequestFailure(
                stage: "transport",
                endpoint: endpoint,
                path: path,
                url: url,
                requestBodyText: requestBodyText,
                error: error
            )
            await requestLimiter.cancel(lease)
            throw APIError.transportError(
                url: url.absoluteString,
                message: error.localizedDescription,
                requestBody: requestBodyText,
                underlying: transportErrorSummary(from: error)
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("")
            print("====== API RESPONSE ERROR ======")
            print("Endpoint: \(endpoint.logName)")
            print("Path: \(path)")
            print("URL: \(url.absoluteString)")
            print("Error: Response was not an HTTPURLResponse.")
            print("================================")
            print("")
            await requestLimiter.cancel(lease)
            throw APIError.invalidResponse
        }

        logResponseStart(
            endpoint: endpoint,
            path: path,
            url: url,
            statusCode: httpResponse.statusCode
        )

        guard (200...299).contains(httpResponse.statusCode) else {
            var data = Data()

            for try await byte in bytes {
                data.append(byte)
            }

            let message = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            logHTTPFailure(
                endpoint: endpoint,
                path: path,
                url: url,
                statusCode: httpResponse.statusCode,
                message: message,
                requestBodyText: requestBodyText
            )
            if shouldStartCooldown(statusCode: httpResponse.statusCode, message: message) {
                await requestLimiter.registerRateLimitSignal()
            }
            await requestLimiter.cancel(lease)

            switch httpResponse.statusCode {
            case 401:
                throw APIError.secureConnectionFailed
            case 429:
                throw APIError.serverBusy
            default:
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
        }

        var responseText = ""
        var pendingData = Data()
        var pendingText = ""
        let flushThreshold = 1024

        do {
            for try await byte in bytes {
                pendingData.append(byte)

                let decodedChunk = decodeValidUTF8Prefix(from: &pendingData)
                guard !decodedChunk.isEmpty else {
                    continue
                }

                responseText.append(decodedChunk)
                pendingText.append(decodedChunk)

                if pendingText.contains("\n") || pendingText.count >= flushThreshold {
                    await onChunk(pendingText)
                    pendingText.removeAll(keepingCapacity: true)
                }
            }
        } catch is CancellationError {
            await requestLimiter.cancel(lease)
            throw CancellationError()
        } catch {
            if shouldStartCooldown(for: error.localizedDescription) {
                await requestLimiter.registerRateLimitSignal()
            }
            await requestLimiter.cancel(lease)
            throw APIError.transportError(
                url: url.absoluteString,
                message: error.localizedDescription,
                requestBody: requestBodyText,
                underlying: transportErrorSummary(from: error)
            )
        }

        let finalChunk = decodeValidUTF8Prefix(from: &pendingData, flushCompletely: true)
        guard pendingData.isEmpty else {
            await requestLimiter.cancel(lease)
            throw APIError.invalidUTF8Stream
        }

        if !finalChunk.isEmpty {
            responseText.append(finalChunk)
            pendingText.append(finalChunk)
        }

        if !pendingText.isEmpty {
            await onChunk(pendingText)
        }

        print("")
        print("====== API RESPONSE SUCCESS ======")
        print("Endpoint: \(endpoint.logName)")
        print("Path: \(path)")
        print("URL: \(url.absoluteString)")
        print("Response Bytes: \(responseText.utf8.count)")
        print("Preview: \(responseText.prefix(220))")
        print("==================================")
        print("")

        await requestLimiter.release(lease)
        return responseText
    }

    private func logOutboundRequest(
        endpoint: APIRequestLimiter.Endpoint,
        request: URLRequest,
        requestBodyText: String?
    ) {
        print("")
        print("====== API REQUEST OUT ======")
        print("Endpoint: \(endpoint.logName)")
        print("Method: \(request.httpMethod ?? "UNKNOWN")")
        print("URL: \(request.url?.absoluteString ?? "nil")")
        print("Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "nil")")
        print("X-App-Id: \(request.value(forHTTPHeaderField: "X-App-Id") ?? "nil")")
        print("X-App-Version: \(request.value(forHTTPHeaderField: "X-App-Version") ?? "nil")")
        print("X-Timestamp: \(request.value(forHTTPHeaderField: "X-Timestamp") ?? "nil")")
        print("X-Nonce: \(request.value(forHTTPHeaderField: "X-Nonce") ?? "nil")")
        if let signature = request.value(forHTTPHeaderField: "X-Signature") {
            print("X-Signature Prefix: \(signature.prefix(16))...")
        } else {
            print("X-Signature: nil")
        }
        print("Body: \(requestBodyText ?? "")")
        print("=============================")
        print("")
    }

    private func logResponseStart(
        endpoint: APIRequestLimiter.Endpoint,
        path: String,
        url: URL,
        statusCode: Int
    ) {
        print("")
        print("====== API RESPONSE START ======")
        print("Endpoint: \(endpoint.logName)")
        print("Path: \(path)")
        print("URL: \(url.absoluteString)")
        print("Status Code: \(statusCode)")
        print("================================")
        print("")
    }

    private func logHTTPFailure(
        endpoint: APIRequestLimiter.Endpoint,
        path: String,
        url: URL,
        statusCode: Int,
        message: String?,
        requestBodyText: String?
    ) {
        print("")
        print("====== API HTTP FAILURE ======")
        print("Endpoint: \(endpoint.logName)")
        print("Path: \(path)")
        print("URL: \(url.absoluteString)")
        print("Status Code: \(statusCode)")
        print("Response: \(message ?? "<empty>")")
        print("Request Body: \(requestBodyText ?? "<empty>")")
        print("==============================")
        print("")
    }

    private func logRequestFailure(
        stage: String,
        endpoint: APIRequestLimiter.Endpoint,
        path: String,
        url: URL?,
        requestBodyText: String?,
        error: Error
    ) {
        print("")
        print("====== API REQUEST FAILURE ======")
        print("Stage: \(stage)")
        print("Endpoint: \(endpoint.logName)")
        print("Path: \(path)")
        print("URL: \(url?.absoluteString ?? "nil")")
        print("Error: \(error.localizedDescription)")
        print("Request Body: \(requestBodyText ?? "<empty>")")
        if let summary = transportErrorSummary(from: error), !summary.isEmpty {
            print("Details:")
            print(summary)
        }
        print("=================================")
        print("")
    }

    private func shouldStartCooldown(statusCode: Int, message: String?) -> Bool {
        if statusCode == 429 || statusCode == 503 {
            return true
        }

        return shouldStartCooldown(for: message)
    }

    private func shouldStartCooldown(for message: String?) -> Bool {
        guard let message else { return false }

        let normalized = message.lowercased()
        return normalized.contains("rate limit")
            || normalized.contains("too many requests")
            || normalized.contains("quota")
            || normalized.contains("token")
            || normalized.contains("capacity")
            || normalized.contains("resource exhausted")
    }

    private func transportErrorSummary(from error: Error) -> String? {
        let nsError = error as NSError
        var parts: [String] = []

        parts.append("Domain: \(nsError.domain)")
        parts.append("Code: \(nsError.code)")

        if let failingURL = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
            parts.append("Failing URL: \(failingURL)")
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("Underlying Domain: \(underlying.domain)")
            parts.append("Underlying Code: \(underlying.code)")
        }

        return parts.joined(separator: "\n")
    }

    private func encodeBody(_ body: [String: String]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(body)
    }

    private func requestBody(topic: String, instructions: String) -> [String: String] {
        var body = ["topic": topic]

        if !instructions.isEmpty {
            body["instructions"] = instructions
        }

        return body
    }

    private func decodeValidUTF8Prefix(from data: inout Data, flushCompletely: Bool = false) -> String {
        let validByteCount = validUTF8PrefixLength(in: data, flushCompletely: flushCompletely)
        guard validByteCount > 0 else {
            return ""
        }

        let prefix = data.prefix(validByteCount)
        let decoded = String(decoding: prefix, as: UTF8.self)
        data.removeFirst(validByteCount)
        return decoded
    }

    private func validUTF8PrefixLength(in data: Data, flushCompletely: Bool) -> Int {
        guard !data.isEmpty else {
            return 0
        }

        if flushCompletely {
            return String(data: data, encoding: .utf8) == nil ? 0 : data.count
        }

        let trailingCount = incompleteTrailingByteCount(in: data)
        let candidateLength = data.count - trailingCount
        guard candidateLength > 0 else {
            return 0
        }

        let candidate = data.prefix(candidateLength)
        return String(data: candidate, encoding: .utf8) == nil ? 0 : candidateLength
    }

    private func incompleteTrailingByteCount(in data: Data) -> Int {
        let bytes = Array(data)
        let maxLookback = min(4, bytes.count)

        for trailingCount in 1..<maxLookback {
            let prefixLength = bytes.count - trailingCount
            let leadByte = bytes[prefixLength - 1]

            if expectedUTF8SequenceLength(for: leadByte) == trailingCount + 1 {
                let trailingBytes = bytes[prefixLength...]
                if trailingBytes.allSatisfy(isUTF8ContinuationByte(_:)) {
                    return trailingCount
                }
            }
        }

        return 0
    }

    private func expectedUTF8SequenceLength(for byte: UInt8) -> Int {
        switch byte {
        case 0x00...0x7F:
            return 1
        case 0xC2...0xDF:
            return 2
        case 0xE0...0xEF:
            return 3
        case 0xF0...0xF4:
            return 4
        default:
            return 0
        }
    }

    private func isUTF8ContinuationByte(_ byte: UInt8) -> Bool {
        (byte & 0b1100_0000) == 0b1000_0000
    }
}

private extension APIRequestLimiter.Endpoint {
    var logName: String {
        switch self {
        case .ask:
            return "ask"
        case .lesson:
            return "lesson"
        case .quiz:
            return "quiz"
        }
    }
}
