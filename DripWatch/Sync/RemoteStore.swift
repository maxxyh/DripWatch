import Foundation

enum SupabasePhotoBucket: String, CaseIterable, Sendable {
    case bean = "bean-photos"
    case brew = "brew-photos"
}

/// The network-facing sync seam. DTOs and bytes cross this boundary; SwiftData models do not.
protocol RemoteStore: Sendable {
    func fetchBeans() async throws -> [BeanDTO]
    func fetchBrews() async throws -> [BrewDTO]
    func fetchBeanPhotos() async throws -> [BeanPhotoDTO]
    func fetchGrinders() async throws -> [GrinderDTO]
    func fetchLexiconTerms() async throws -> [LexiconTermDTO]

    func upsert(bean: BeanDTO) async throws
    func upsert(brew: BrewDTO) async throws
    func upsert(beanPhoto: BeanPhotoDTO) async throws
    func upsert(grinder: GrinderDTO) async throws
    func upsert(lexiconTerm: LexiconTermDTO) async throws

    func uploadPhoto(
        data: Data,
        photoID: UUID,
        bucket: SupabasePhotoBucket
    ) async throws -> String

    func downloadPhoto(
        path: String,
        bucket: SupabasePhotoBucket
    ) async throws -> Data
}
