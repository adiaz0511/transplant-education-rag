import Foundation

struct BackendConfig: Sendable {
    static let baseURLInfoKey = "BackendBaseURL"
    static let appIDInfoKey = "BackendAppID"
    static let sharedSecretInfoKey = "BackendSharedSecret"

    let baseURLString: String
    let appID: String
    let appVersion: String
    let sharedSecret: String

    init(
        bundle: Bundle = .main,
        fallbackBaseURL: String = "http://127.0.0.1:8000"
    ) {
        let configuredBaseURL = Self.normalizedConfigValue(
            bundle.object(forInfoDictionaryKey: Self.baseURLInfoKey) as? String
        )
        let configuredAppID = Self.normalizedConfigValue(
            bundle.object(forInfoDictionaryKey: Self.appIDInfoKey) as? String
        )
        let configuredSharedSecret = Self.normalizedConfigValue(
            bundle.object(forInfoDictionaryKey: Self.sharedSecretInfoKey) as? String
        )
        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        self.baseURLString = Self.resolvedBaseURL(configuredBaseURL, fallback: fallbackBaseURL)
        self.appID = configuredAppID?.nilIfBlank ?? ""
        self.sharedSecret = configuredSharedSecret?.nilIfBlank ?? ""
        self.appVersion = shortVersion?.nilIfBlank ?? buildVersion?.nilIfBlank ?? "1"
    }

    var baseURL: URL? {
        URL(string: baseURLString)
    }

    private static func resolvedBaseURL(_ configuredValue: String?, fallback: String) -> String {
        guard let configuredValue = configuredValue?.nilIfBlank,
              let url = URL(string: configuredValue),
              let scheme = url.scheme,
              !scheme.isEmpty,
              url.host != nil else {
            return fallback
        }

        return configuredValue
    }

    private static func normalizedConfigValue(_ rawValue: String?) -> String? {
        var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        while let current = value, current.hasPrefix("\""), current.hasSuffix("\""), current.count >= 2 {
            value = String(current.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return value?.nilIfBlank
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
