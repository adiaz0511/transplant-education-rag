import Foundation

@main
struct AskEndpointDiagnostic {
    static func main() async {
        let port = 8989
        let server = MockAskServer(port: port)

        do {
            try server.start()
            defer { server.stop() }

            let largeQuestion = String(repeating: "follow-up context ", count: 35_000)
            let client = APIClient(
                baseURL: "http://127.0.0.1:\(port)",
                requestTimeout: 5,
                resourceTimeout: 5
            )

            print("== Ask Endpoint Diagnostic ==")
            print("Server: \(client.baseURL)/ask")
            print("Large first query characters: \(largeQuestion.count)")

            let firstStart = Date()
            do {
                _ = try await client.ask(query: largeQuestion) { _ in }
                print("First request unexpectedly succeeded.")
            } catch {
                print("First request failed after \(elapsed(since: firstStart))s")
                print("Failure: \(error.localizedDescription)")
            }

            let secondStart = Date()
            do {
                let secondResponse = try await withTimeout(seconds: 5) {
                    try await client.ask(query: "Can you still answer after the failed request?") { _ in }
                }
                print("Second request completed after \(elapsed(since: secondStart))s")
                print("Second response prefix: \(secondResponse.prefix(120))")
            } catch {
                print("Second request did not finish cleanly after \(elapsed(since: secondStart))s")
                print("Failure: \(error.localizedDescription)")
            }

            print("Server observed \(server.requestCount) request(s).")
            print(server.requestCount >= 2
                ? "Diagnosis: the second request reached the server promptly."
                : "Diagnosis: the second request never reached the server in time, which points to client-side gating.")
        } catch {
            fputs("Diagnostic setup failed: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func elapsed(since start: Date) -> String {
        String(format: "%.2f", Date().timeIntervalSince(start))
    }
}

private actor TimeoutBox<T: Sendable> {
    private var completed = false

    func finish(with result: Result<T, Error>) -> Result<T, Error>? {
        guard !completed else { return nil }
        completed = true
        return result
    }
}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let box = TimeoutBox<T>()
    return try await withThrowingTaskGroup(of: Result<T, Error>.self) { group in
        group.addTask {
            do {
                let value = try await operation()
                return await box.finish(with: .success(value)) ?? .failure(CancellationError())
            } catch {
                return await box.finish(with: .failure(error)) ?? .failure(CancellationError())
            }
        }

        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return await box.finish(with: .failure(DiagnosticError.timeout(seconds))) ?? .failure(CancellationError())
        }

        guard let first = try await group.next() else {
            throw DiagnosticError.timeout(seconds)
        }
        group.cancelAll()
        return try first.get()
    }
}

private enum DiagnosticError: LocalizedError {
    case timeout(TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .timeout(seconds):
            return "Timed out after \(Int(seconds)) seconds."
        }
    }
}

private final class MockAskServer {
    private let port: Int
    private let scriptURL: URL
    private let process = Process()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private var outputBuffer = ""

    init(port: Int) {
        self.port = port
        self.scriptURL = URL(fileURLWithPath: "/tmp/ask_endpoint_mock_server_\(port).py")
    }

    var requestCount: Int {
        combinedOutput
            .split(separator: "\n")
            .filter { $0.hasPrefix("REQUEST ") }
            .count
    }

    func start() throws {
        try pythonSource.write(to: scriptURL, atomically: true, encoding: .utf8)

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self.outputBuffer.append(text)
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self.outputBuffer.append(text)
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptURL.path, String(port)]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        waitUntilListening()
    }

    func stop() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        try? FileManager.default.removeItem(at: scriptURL)
    }

    private var combinedOutput: String {
        outputBuffer
    }

    private func waitUntilListening() {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if combinedOutput.contains("LISTENING \(port)") {
                return
            }

            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private var pythonSource: String {
        #"""
import json
import socket
import sys

port = int(sys.argv[1])
request_count = 0

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", port))
server.listen(5)
print(f"LISTENING {port}", flush=True)

while True:
    conn, _ = server.accept()
    request_count += 1
    print(f"REQUEST {request_count}", flush=True)

    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk

    headers, _, rest = data.partition(b"\r\n\r\n")
    content_length = 0
    for line in headers.decode("utf-8", errors="ignore").split("\r\n"):
        if line.lower().startswith("content-length:"):
            content_length = int(line.split(":", 1)[1].strip())
            break

    while len(rest) < content_length:
        chunk = conn.recv(4096)
        if not chunk:
            break
        rest += chunk

    if request_count == 1:
        conn.close()
        continue

    payload = json.dumps({
        "answer": "The second request reached the server.",
        "key_points": ["Follow-up request succeeded."],
        "source_indices": [0],
        "sources": ["Mock source chunk"]
    }).encode("utf-8")

    response = (
        b"HTTP/1.1 200 OK\r\n"
        + f"Content-Type: application/json\r\n".encode("utf-8")
        + f"Content-Length: {len(payload)}\r\n".encode("utf-8")
        + b"Connection: close\r\n\r\n"
        + payload
    )
    conn.sendall(response)
    conn.close()
"""#
    }
}
