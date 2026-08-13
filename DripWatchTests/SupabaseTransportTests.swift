import Foundation
import Testing
@testable import DripWatch

struct SupabaseTransportTests {
    @Test func sha256AndContentAddressedPathAreStable() {
        let data = Data("hello".utf8)
        let photoID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

        #expect(
            PhotoSync.sha256Hex(data) ==
                "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
        #expect(
            PhotoSync.relativePath(photoID: photoID, data: data) ==
                "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824.jpg"
        )
    }

    @Test func configAcceptsRealValues() throws {
        let config = try SupabaseConfig(
            urlString: " https://example.supabase.co ",
            publishableKey: " publishable-key "
        )

        #expect(config.url.absoluteString == "https://example.supabase.co")
        #expect(config.publishableKey == "publishable-key")
    }

    @Test(arguments: [
        (nil, "key"),
        ("", "key"),
        ("$(SUPABASE_URL)", "key"),
        ("https://example.supabase.co", "$(SUPABASE_PUBLISHABLE_KEY)"),
        ("https://example.supabase.co", "placeholder"),
        ("not a URL", "key")
    ])
    func configReportsUnavailableForMissingOrPlaceholderValues(
        url: String?,
        key: String?
    ) {
        #expect(throws: SupabaseConfigError.unavailable) {
            try SupabaseConfig(urlString: url, publishableKey: key)
        }
    }

    @Test func bundleConfigReportsUnavailableWhenInfoValuesAreAbsent() {
        #expect(throws: SupabaseConfigError.unavailable) {
            try SupabaseConfig(bundle: Bundle(for: BundleMarker.self))
        }
    }

    @Test func loadFallsBackToShippedPublishableConfiguration() throws {
        let config = try SupabaseConfig.load(bundle: Bundle(for: BundleMarker.self))

        #expect(config.url.host == "jasvndjjzimqiidffwfa.supabase.co")
        #expect(config.publishableKey.hasPrefix("sb_publishable_"))
    }

    private final class BundleMarker {}
}
