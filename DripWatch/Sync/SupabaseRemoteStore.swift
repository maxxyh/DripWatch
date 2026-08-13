import Foundation
import Supabase

final class SupabaseRemoteStore: RemoteStore, @unchecked Sendable {
    static let pageSize = 500

    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        let databaseOptions = SupabaseClientOptions.DatabaseOptions(
            encoder: SupabaseCoding.encoder(),
            decoder: SupabaseCoding.decoder()
        )
        let options = SupabaseClientOptions(db: databaseOptions)
        client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.publishableKey,
            options: options
        )
    }

    func fetchBeans() async throws -> [BeanDTO] {
        try await fetchAll(BeanDTO.self)
    }

    func fetchBrews() async throws -> [BrewDTO] {
        try await fetchAll(BrewDTO.self)
    }

    func fetchBeanPhotos() async throws -> [BeanPhotoDTO] {
        try await fetchAll(BeanPhotoDTO.self)
    }

    func fetchGrinders() async throws -> [GrinderDTO] {
        try await fetchAll(GrinderDTO.self)
    }

    func fetchLexiconTerms() async throws -> [LexiconTermDTO] {
        try await fetchAll(LexiconTermDTO.self)
    }

    func upsert(bean: BeanDTO) async throws {
        try await upsert(bean, in: BeanDTO.table)
    }

    func upsert(brew: BrewDTO) async throws {
        try await upsert(brew, in: BrewDTO.table)
    }

    func upsert(beanPhoto: BeanPhotoDTO) async throws {
        try await upsert(beanPhoto, in: BeanPhotoDTO.table)
    }

    func upsert(grinder: GrinderDTO) async throws {
        try await upsert(grinder, in: GrinderDTO.table)
    }

    func upsert(lexiconTerm: LexiconTermDTO) async throws {
        try await upsert(lexiconTerm, in: LexiconTermDTO.table)
    }

    func uploadPhoto(
        data: Data,
        photoID: UUID,
        bucket: SupabasePhotoBucket
    ) async throws -> String {
        let prepared = try PhotoSync.prepare(data: data, photoID: photoID)
        let options = FileOptions(
            contentType: "image/jpeg",
            upsert: true
        )
        _ = try await client.storage
            .from(bucket.rawValue)
            .upload(prepared.path, data: prepared.data, options: options)
        return prepared.path
    }

    func downloadPhoto(
        path: String,
        bucket: SupabasePhotoBucket
    ) async throws -> Data {
        try await client.storage
            .from(bucket.rawValue)
            .download(path: path)
    }

    private func fetchAll<Row: SupabaseRow>(_ rowType: Row.Type) async throws -> [Row] {
        var rows: [Row] = []
        var start = 0

        while true {
            let end = start + Self.pageSize - 1
            let page: [Row] = try await client
                .from(Row.table.rawValue)
                .select()
                .order("id", ascending: true)
                .range(from: start, to: end)
                .execute()
                .value

            rows.append(contentsOf: page)
            if page.count < Self.pageSize {
                return rows
            }
            start += page.count
        }
    }

    private func upsert<Row: SupabaseRow>(_ row: Row, in table: SyncTable) async throws {
        _ = try await client
            .from(table.rawValue)
            .upsert(row, onConflict: "id", returning: .minimal)
            .execute()
    }
}
