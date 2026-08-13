import Foundation

protocol SupabaseRow: Codable, Sendable, Identifiable where ID == UUID {
    static var table: SyncTable { get }
    var id: UUID { get }
    var updatedAt: Date { get }
}

struct BeanDTO: SupabaseRow {
    static let table = SyncTable.beans

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var name: String
    var roasterName: String?
    var country: String?
    var region: String?
    var farm: String?
    var varietal: String?
    var process: String?
    var roastLevel: String?
    var roastDate: Date?
    var roasterNotes: String?
    var myFlavorTags: [String]
    var finishedAt: Date?
    var pendingNextPourover: Recipe?
    var pendingNextEspresso: Recipe?

    enum CodingKeys: String, CodingKey {
        case id, name, country, region, farm, varietal, process
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case roasterName = "roaster_name"
        case roastLevel = "roast_level"
        case roastDate = "roast_date"
        case roasterNotes = "roaster_notes"
        case myFlavorTags = "my_flavor_tags"
        case finishedAt = "finished_at"
        case pendingNextPourover = "pending_next_pourover"
        case pendingNextEspresso = "pending_next_espresso"
    }

    init(_ bean: Bean) {
        id = bean.id
        createdAt = bean.createdAt
        updatedAt = bean.updatedAt
        deletedAt = bean.deletedAt
        name = bean.name
        roasterName = bean.roasterName
        country = bean.country
        region = bean.region
        farm = bean.farm
        varietal = bean.varietal
        process = bean.process
        roastLevel = bean.roastLevel
        roastDate = bean.roastDate
        roasterNotes = bean.roasterNotes
        myFlavorTags = bean.myFlavorTags
        finishedAt = bean.finishedAt
        pendingNextPourover = bean.pendingNextPourover
        pendingNextEspresso = bean.pendingNextEspresso
    }

    func makeModel() -> Bean {
        let bean = Bean(name: name)
        apply(to: bean)
        return bean
    }

    func apply(to bean: Bean) {
        bean.id = id
        bean.createdAt = createdAt
        bean.updatedAt = updatedAt
        bean.deletedAt = deletedAt
        bean.name = name
        bean.roasterName = roasterName
        bean.country = country
        bean.region = region
        bean.farm = farm
        bean.varietal = varietal
        bean.process = process
        bean.roastLevel = roastLevel
        bean.roastDate = roastDate
        bean.roasterNotes = roasterNotes
        bean.myFlavorTags = myFlavorTags
        bean.finishedAt = finishedAt
        bean.pendingNextPourover = pendingNextPourover
        bean.pendingNextEspresso = pendingNextEspresso
    }
}

struct BrewDTO: SupabaseRow {
    static let table = SyncTable.brews

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var brewedAt: Date
    var methodRaw: String
    var brewers: [String]
    var recipe: Recipe
    var taste: Taste
    var nextRecipeDraft: Recipe?
    var beanID: UUID?
    var photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, brewers, recipe, taste
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case brewedAt = "brewed_at"
        case methodRaw = "method_raw"
        case nextRecipeDraft = "next_recipe_draft"
        case beanID = "bean_id"
        case photoPath = "photo_path"
    }

    init(_ brew: Brew) {
        id = brew.id
        createdAt = brew.createdAt
        updatedAt = brew.updatedAt
        deletedAt = brew.deletedAt
        brewedAt = brew.brewedAt
        methodRaw = brew.methodRaw
        brewers = brew.brewers
        recipe = brew.recipe
        taste = brew.taste
        nextRecipeDraft = brew.nextRecipeDraft
        beanID = brew.bean?.id
        photoPath = brew.photoRemotePath
    }

    init(_ brew: Brew, photoPath: String?) {
        self.init(brew)
        self.photoPath = photoPath
    }

    func makeModel() -> Brew {
        let brew = Brew(brewedAt: brewedAt, recipe: recipe)
        apply(to: brew)
        return brew
    }

    func apply(to brew: Brew) {
        brew.id = id
        brew.createdAt = createdAt
        brew.updatedAt = updatedAt
        brew.deletedAt = deletedAt
        brew.brewedAt = brewedAt
        brew.methodRaw = methodRaw
        brew.brewers = brewers
        brew.recipe = recipe
        brew.taste = taste
        brew.nextRecipeDraft = nextRecipeDraft
        brew.photoRemotePath = photoPath
    }
}

struct BeanPhotoDTO: SupabaseRow {
    static let table = SyncTable.beanPhotos

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var order: Int
    var beanID: UUID?
    var remotePath: String?

    enum CodingKeys: String, CodingKey {
        case id, order
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case beanID = "bean_id"
        case remotePath = "remote_path"
    }

    init(_ photo: BeanPhoto) {
        id = photo.id
        createdAt = photo.createdAt
        updatedAt = photo.updatedAt
        deletedAt = photo.deletedAt
        order = photo.order
        beanID = photo.bean?.id
        remotePath = photo.remotePath
    }

    init(_ photo: BeanPhoto, remotePath: String?) {
        self.init(photo)
        self.remotePath = remotePath
    }

    func makeModel() -> BeanPhoto {
        let photo = BeanPhoto(data: nil, order: order)
        apply(to: photo)
        return photo
    }

    func apply(to photo: BeanPhoto) {
        photo.id = id
        photo.createdAt = createdAt
        photo.updatedAt = updatedAt
        photo.deletedAt = deletedAt
        photo.order = order
        photo.remotePath = remotePath
    }
}

struct GrinderDTO: SupabaseRow {
    static let table = SyncTable.grinders

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var name: String
    var stepless: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, stepless
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ grinder: Grinder) {
        id = grinder.id
        createdAt = grinder.createdAt
        updatedAt = grinder.updatedAt
        deletedAt = grinder.deletedAt
        name = grinder.name
        stepless = grinder.stepless
    }

    func makeModel() -> Grinder {
        let grinder = Grinder(name: name, stepless: stepless)
        apply(to: grinder)
        return grinder
    }

    func apply(to grinder: Grinder) {
        grinder.id = id
        grinder.createdAt = createdAt
        grinder.updatedAt = updatedAt
        grinder.deletedAt = deletedAt
        grinder.name = name
        grinder.stepless = stepless
    }
}

struct LexiconTermDTO: SupabaseRow {
    static let table = SyncTable.lexiconTerms

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var term: String
    var fieldRaw: String

    enum CodingKeys: String, CodingKey {
        case id, term
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case fieldRaw = "field_raw"
    }

    init(_ term: LexiconTerm) {
        id = term.id
        createdAt = term.createdAt
        updatedAt = term.updatedAt
        deletedAt = term.deletedAt
        self.term = term.term
        fieldRaw = term.fieldRaw
    }

    func makeModel() -> LexiconTerm {
        let term = LexiconTerm(term: self.term)
        apply(to: term)
        return term
    }

    func apply(to term: LexiconTerm) {
        term.id = id
        term.createdAt = createdAt
        term.updatedAt = updatedAt
        term.deletedAt = deletedAt
        term.term = self.term
        term.fieldRaw = fieldRaw
    }
}
