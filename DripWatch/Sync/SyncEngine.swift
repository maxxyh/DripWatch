import Combine
import Foundation
import SwiftData

@MainActor
final class SyncEngine: ObservableObject {
    enum Status: Equatable {
        case notConfigured
        case idle(lastSyncedAt: Date?)
        case syncing
        case failed(String)
    }

    @Published private(set) var status: Status

    private let context: ModelContext
    private let remote: (any RemoteStore)?
    private let outbox: SyncOutbox
    private var cycleTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(
        context: ModelContext,
        remote: (any RemoteStore)? = nil,
        outbox: SyncOutbox? = nil
    ) {
        self.context = context
        self.outbox = outbox ?? .shared

        if let remote {
            self.remote = remote
            status = .idle(lastSyncedAt: nil)
        } else if let config = try? SupabaseConfig.load() {
            self.remote = SupabaseRemoteStore(config: config)
            status = .idle(lastSyncedAt: nil)
        } else {
            self.remote = nil
            status = .notConfigured
        }

        self.outbox.onRecord = { [weak self] in
            self?.scheduleDebouncedSync()
        }
    }

    deinit {
        debounceTask?.cancel()
        cycleTask?.cancel()
    }

    func start() async {
        guard remote != nil else { return }
        do {
            try SyncBootstrap.prepareIfNeeded(context: context, outbox: outbox)
        } catch {
            status = .failed("Could not prepare local data: \(error.localizedDescription)")
            return
        }
        await syncNow()
    }

    func syncNow() async {
        guard remote != nil else {
            status = .notConfigured
            return
        }

        if let cycleTask {
            await cycleTask.value
            return
        }

        debounceTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runCycle()
        }
        cycleTask = task
        await task.value
        cycleTask = nil
    }

    private func scheduleDebouncedSync() {
        guard remote != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    private func runCycle() async {
        guard let remote else { return }
        status = .syncing

        do {
            let batch = outbox.snapshot()
            let acknowledged = try await push(batch: batch, to: remote)
            outbox.acknowledge(acknowledged)

            // Snapshot again after awaiting uploads/upserts. Rows edited during the push are
            // excluded from this pull, so an in-flight response cannot overwrite fresh input.
            try await pull(from: remote)
            try context.save()
            SyncBootstrap.markComplete(outbox: outbox)
            status = .idle(lastSyncedAt: .now)

            if !outbox.isEmpty { scheduleDebouncedSync() }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func push(
        batch: [SyncRecordKey: UInt64],
        to remote: any RemoteStore
    ) async throws -> [SyncRecordKey: UInt64] {
        guard !batch.isEmpty else { return [:] }
        var sent: [SyncRecordKey: UInt64] = [:]

        let beans = try context.fetch(FetchDescriptor<Bean>())
        let brews = try context.fetch(FetchDescriptor<Brew>())
        let photos = try context.fetch(FetchDescriptor<BeanPhoto>())
        let grinders = try context.fetch(FetchDescriptor<Grinder>())
        let terms = try context.fetch(FetchDescriptor<LexiconTerm>())

        // Parents precede children so foreign keys are always satisfiable.
        for bean in beans { try await send(bean, batch: batch, sent: &sent, remote: remote) }
        for grinder in grinders { try await send(grinder, batch: batch, sent: &sent, remote: remote) }
        for term in terms { try await send(term, batch: batch, sent: &sent, remote: remote) }

        for photo in photos {
            let key = SyncRecordKey(photo)
            guard let generation = batch[key] else { continue }
            if photo.deletedAt == nil, let data = photo.data {
                photo.remotePath = try await remote.uploadPhoto(
                    data: data,
                    photoID: photo.id,
                    bucket: .bean
                )
            }
            try await remote.upsert(beanPhoto: BeanPhotoDTO(photo))
            sent[key] = generation
        }

        for brew in brews {
            let key = SyncRecordKey(brew)
            guard let generation = batch[key] else { continue }
            if brew.deletedAt == nil, let data = brew.photo {
                brew.photoRemotePath = try await remote.uploadPhoto(
                    data: data,
                    photoID: brew.id,
                    bucket: .brew
                )
            }
            try await remote.upsert(brew: BrewDTO(brew))
            sent[key] = generation
        }

        try context.save()
        return sent
    }

    private func send(
        _ bean: Bean,
        batch: [SyncRecordKey: UInt64],
        sent: inout [SyncRecordKey: UInt64],
        remote: any RemoteStore
    ) async throws {
        let key = SyncRecordKey(bean)
        guard let generation = batch[key] else { return }
        try await remote.upsert(bean: BeanDTO(bean))
        sent[key] = generation
    }

    private func send(
        _ grinder: Grinder,
        batch: [SyncRecordKey: UInt64],
        sent: inout [SyncRecordKey: UInt64],
        remote: any RemoteStore
    ) async throws {
        let key = SyncRecordKey(grinder)
        guard let generation = batch[key] else { return }
        try await remote.upsert(grinder: GrinderDTO(grinder))
        sent[key] = generation
    }

    private func send(
        _ term: LexiconTerm,
        batch: [SyncRecordKey: UInt64],
        sent: inout [SyncRecordKey: UInt64],
        remote: any RemoteStore
    ) async throws {
        let key = SyncRecordKey(term)
        guard let generation = batch[key] else { return }
        try await remote.upsert(lexiconTerm: LexiconTermDTO(term))
        sent[key] = generation
    }

    private func pull(from remote: any RemoteStore) async throws {
        async let beanRows = remote.fetchBeans()
        async let grinderRows = remote.fetchGrinders()
        async let termRows = remote.fetchLexiconTerms()
        async let photoRows = remote.fetchBeanPhotos()
        async let brewRows = remote.fetchBrews()

        let (beansDTO, grindersDTO, termsDTO, photosDTO, brewsDTO) = try await (
            beanRows, grinderRows, termRows, photoRows, brewRows
        )

        var beans = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<Bean>()).map { ($0.id, $0) }
        )
        var grinders = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<Grinder>()).map { ($0.id, $0) }
        )
        var terms = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<LexiconTerm>()).map { ($0.id, $0) }
        )
        var photos = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<BeanPhoto>()).map { ($0.id, $0) }
        )
        var brews = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<Brew>()).map { ($0.id, $0) }
        )

        for row in beansDTO where !outbox.contains(.init(table: .beans, id: row.id)) {
            let model = beans[row.id] ?? row.makeModel()
            if beans[row.id] == nil { context.insert(model); beans[row.id] = model }
            row.apply(to: model)
        }
        for row in grindersDTO where !outbox.contains(.init(table: .grinders, id: row.id)) {
            let model = grinders[row.id] ?? row.makeModel()
            if grinders[row.id] == nil { context.insert(model); grinders[row.id] = model }
            row.apply(to: model)
        }
        for row in termsDTO where !outbox.contains(.init(table: .lexiconTerms, id: row.id)) {
            let model = terms[row.id] ?? row.makeModel()
            if terms[row.id] == nil { context.insert(model); terms[row.id] = model }
            row.apply(to: model)
        }

        for row in photosDTO where !outbox.contains(.init(table: .beanPhotos, id: row.id)) {
            let model = photos[row.id] ?? row.makeModel()
            let pathChanged = model.remotePath != row.remotePath
            if photos[row.id] == nil { context.insert(model); photos[row.id] = model }
            row.apply(to: model)
            model.bean = row.beanID.flatMap { beans[$0] }
            if pathChanged { model.data = nil }
        }

        for row in brewsDTO where !outbox.contains(.init(table: .brews, id: row.id)) {
            let model = brews[row.id] ?? row.makeModel()
            let pathChanged = model.photoRemotePath != row.photoPath
            if brews[row.id] == nil { context.insert(model); brews[row.id] = model }
            row.apply(to: model)
            model.bean = row.beanID.flatMap { beans[$0] }
            if pathChanged { model.photo = nil }
        }

        // Blobs are cached locally but remain recoverable from their private bucket.
        for photo in photos.values where photo.deletedAt == nil && photo.data == nil {
            guard let path = photo.remotePath else { continue }
            let data = try await remote.downloadPhoto(path: path, bucket: .bean)
            guard !outbox.contains(SyncRecordKey(photo)), photo.remotePath == path else { continue }
            photo.data = data
        }
        for brew in brews.values where brew.deletedAt == nil && brew.photo == nil {
            guard let path = brew.photoRemotePath else { continue }
            let data = try await remote.downloadPhoto(path: path, bucket: .brew)
            guard !outbox.contains(SyncRecordKey(brew)), brew.photoRemotePath == path else { continue }
            brew.photo = data
        }
    }
}
