import Foundation
import Supabase

enum SupabaseConfigError: Error, Equatable, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        "Supabase is unavailable: configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY."
    }
}

struct SupabaseConfig: Equatable, Sendable {
    static let urlInfoKey = "SUPABASE_URL"
    static let publishableKeyInfoKey = "SUPABASE_PUBLISHABLE_KEY"

    // Publishable client configuration is safe to ship in the app. Authorization remains the
    // database's RLS responsibility; a service-role or secret key must never appear here.
    private static let defaultURL = "https://jasvndjjzimqiidffwfa.supabase.co"
    private static let defaultPublishableKey = "sb_publishable_VdjBDghr-yPPnks_MlPSqg_0EWLkZYD"

    let url: URL
    let publishableKey: String

    init(bundle: Bundle = .main) throws {
        try self.init(
            urlString: bundle.object(forInfoDictionaryKey: Self.urlInfoKey) as? String,
            publishableKey: bundle.object(forInfoDictionaryKey: Self.publishableKeyInfoKey) as? String
        )
    }

    init(urlString: String?, publishableKey: String?) throws {
        guard
            let urlString,
            let publishableKey,
            let trimmedURL = Self.usableValue(urlString),
            let trimmedKey = Self.usableValue(publishableKey),
            let url = URL(string: trimmedURL),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            throw SupabaseConfigError.unavailable
        }

        self.url = url
        self.publishableKey = trimmedKey
    }

    static func load(bundle: Bundle = .main) throws -> SupabaseConfig {
        if let configured = try? SupabaseConfig(bundle: bundle) {
            return configured
        }
        return try SupabaseConfig(
            urlString: defaultURL,
            publishableKey: defaultPublishableKey
        )
    }

    private static func usableValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()
        let isBuildPlaceholder =
            trimmed.contains("$(") ||
            trimmed.contains("${") ||
            lowercased.contains("placeholder") ||
            lowercased.contains("replace_me") ||
            lowercased.contains("your_supabase") ||
            lowercased == "supabase_url" ||
            lowercased == "supabase_publishable_key"

        return isBuildPlaceholder ? nil : trimmed
    }
}
