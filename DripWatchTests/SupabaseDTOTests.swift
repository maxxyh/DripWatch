import Foundation
import Testing
@testable import DripWatch

struct SupabaseDTOTests {

    @Test func standaloneModelsRoundTripThroughWireDTOs() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000.125)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_100.5)
        let roastDate = Date(timeIntervalSince1970: 1_699_000_000)

        var recipe = Recipe()
        recipe.grinderName = "1Zpresso J"
        recipe.grindMajor = 3
        recipe.grindClickOffset = -1
        recipe.waterTempC = 92
        recipe.doseGrams = 15
        recipe.ratio = 15
        recipe.totalWaterGrams = nil
        recipe.pourCount = 3
        recipe.bloomTimeSec = 30
        recipe.totalDrawdownSec = 195
        recipe.notes = "centre pour"
        recipe.pours = [Pour(order: 1, toGrams: 45, startSec: 0, endSec: 30, style: "bloom")]
        recipe.preInfusionSec = 6
        recipe.surfWaitSec = 8
        recipe.steamModeSec = 4

        var taste = Taste()
        taste.positives = ["honey"]
        taste.negatives = ["dry"]
        taste.balance = TasteBalance(acidity: 4, sweetness: 5, bitterness: 1, body: 3)
        taste.rating = 4
        taste.note = "opened up as it cooled"

        let bean = Bean(name: "Voyager")
        bean.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        bean.createdAt = createdAt
        bean.updatedAt = updatedAt
        bean.deletedAt = Date(timeIntervalSince1970: 1_700_000_200)
        bean.roasterName = "North Star"
        bean.country = "Ethiopia"
        bean.region = "Guji"
        bean.farm = "Benti Nenka"
        bean.varietal = "74110"
        bean.process = "Natural"
        bean.roastLevel = "Light"
        bean.roastDate = roastDate
        bean.roasterNotes = "peach, jasmine"
        bean.myFlavorTags = ["stone fruit", "floral"]
        bean.finishedAt = Date(timeIntervalSince1970: 1_700_000_300)
        bean.pendingNextPourover = recipe.asPlanSeed
        bean.pendingNextEspresso = Recipe()

        let brew = Brew(brewedAt: createdAt, method: .pourover, recipe: recipe)
        brew.id = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        brew.createdAt = createdAt
        brew.updatedAt = updatedAt
        brew.deletedAt = nil
        brew.methodRaw = BrewMethod.espresso.rawValue
        brew.brewers = ["Maxx", "Sam"]
        brew.taste = taste
        brew.nextRecipeDraft = recipe.asPlanSeed
        brew.bean = bean
        bean.brews = [brew]

        let photo = BeanPhoto(data: Data([1, 2, 3]), order: 2)
        photo.id = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        photo.createdAt = createdAt
        photo.updatedAt = updatedAt
        photo.bean = bean
        bean.photos = [photo]

        let grinder = Grinder(name: "DF54", stepless: true)
        grinder.id = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        grinder.createdAt = createdAt
        grinder.updatedAt = updatedAt

        let term = LexiconTerm(term: "pink bourbon", field: .varietal)
        term.id = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        term.createdAt = createdAt
        term.updatedAt = updatedAt
        term.fieldRaw = BagField.process.rawValue

        let encoder = SupabaseCoding.encoder()
        let decoder = SupabaseCoding.decoder()

        let beanDTO = try roundTrip(BeanDTO(bean), encoder: encoder, decoder: decoder)
        #expect(beanDTO.makeModel().name == bean.name)
        #expect(beanDTO.makeModel().roastDate == bean.roastDate)
        #expect(beanDTO.makeModel().pendingNextPourover == bean.pendingNextPourover)

        let brewDTO = try roundTrip(BrewDTO(brew, photoPath: "brews/brew/result.jpg"), encoder: encoder, decoder: decoder)
        let restoredBrew = brewDTO.makeModel()
        #expect(restoredBrew.methodRaw == BrewMethod.espresso.rawValue)
        #expect(restoredBrew.recipe == brew.recipe)
        #expect(restoredBrew.taste == brew.taste)
        #expect(restoredBrew.nextRecipeDraft == brew.nextRecipeDraft)
        #expect(brewDTO.beanID == bean.id)
        #expect(brewDTO.photoPath == "brews/brew/result.jpg")
        #expect(restoredBrew.photoRemotePath == "brews/brew/result.jpg")

        let photoDTO = try roundTrip(BeanPhotoDTO(photo, remotePath: "photo-2/hash.jpg"), encoder: encoder, decoder: decoder)
        #expect(photoDTO.makeModel().order == photo.order)
        #expect(photoDTO.beanID == bean.id)
        #expect(photoDTO.remotePath == "photo-2/hash.jpg")
        #expect(photoDTO.makeModel().remotePath == "photo-2/hash.jpg")

        let grinderDTO = try roundTrip(GrinderDTO(grinder), encoder: encoder, decoder: decoder)
        #expect(grinderDTO.makeModel().stepless)
        #expect(grinderDTO.makeModel().name == "DF54")

        let termDTO = try roundTrip(LexiconTermDTO(term), encoder: encoder, decoder: decoder)
        #expect(termDTO.makeModel().fieldRaw == BagField.process.rawValue)
        #expect(termDTO.makeModel().term == "pink bourbon")
    }

    @Test func brewRecipeAndTasteAreStrictlyRequired() throws {
        let brew = BrewDTO(Brew())
        let encoder = SupabaseCoding.encoder()
        let decoder = SupabaseCoding.decoder()
        let object = try JSONSerialization.jsonObject(with: encoder.encode(brew)) as! [String: Any]

        for key in ["recipe", "taste"] {
            var missing = object
            missing.removeValue(forKey: key)
            let missingData = try JSONSerialization.data(withJSONObject: missing)
            #expect(throws: DecodingError.self) {
                try decoder.decode(BrewDTO.self, from: missingData)
            }

            var null = object
            null[key] = NSNull()
            let nullData = try JSONSerialization.data(withJSONObject: null)
            #expect(throws: DecodingError.self) {
                try decoder.decode(BrewDTO.self, from: nullData)
            }
        }

        var malformed = object
        malformed["recipe"] = "not-a-recipe"
        let malformedData = try JSONSerialization.data(withJSONObject: malformed)
        #expect(throws: DecodingError.self) {
            try decoder.decode(BrewDTO.self, from: malformedData)
        }
    }

    @Test func optionalRecipeDraftAcceptsMissingOrNull() throws {
        let encoder = SupabaseCoding.encoder()
        let decoder = SupabaseCoding.decoder()
        let source = try JSONSerialization.jsonObject(with: encoder.encode(BrewDTO(Brew()))) as! [String: Any]

        for value in [nil, NSNull()] as [Any?] {
            var object = source
            object["next_recipe_draft"] = value
            let data = try JSONSerialization.data(withJSONObject: object)
            #expect(try decoder.decode(BrewDTO.self, from: data).nextRecipeDraft == nil)
        }
    }

    @Test func clearedOptionalFieldsEncodeAsExplicitNullNotOmittedKeys() throws {
        // Swift's synthesized Encodable calls `encodeIfPresent` for Optional properties, which
        // OMITS the key when nil. PostgREST's upsert only overwrites columns present in the JSON
        // body, so an omitted key leaves the old server value in place — the bug behind a
        // discarded "next brew" plan (or a reopened finished bean) reappearing after sync.
        // BeanDTO/BrewDTO override `encode(to:)` to always emit the key so nil clears the column.
        let encoder = SupabaseCoding.encoder()

        let bean = Bean(name: "Voyager")
        bean.pendingNextPourover = nil
        bean.pendingNextEspresso = nil
        bean.finishedAt = nil
        let beanObject = try JSONSerialization.jsonObject(with: encoder.encode(BeanDTO(bean))) as! [String: Any]
        for key in ["pending_next_pourover", "pending_next_espresso", "finished_at"] {
            #expect(beanObject.keys.contains(key), "\(key) must be present so PostgREST clears it")
            #expect(beanObject[key] is NSNull)
        }

        let brew = Brew()
        brew.nextRecipeDraft = nil
        let brewObject = try JSONSerialization.jsonObject(with: encoder.encode(BrewDTO(brew))) as! [String: Any]
        #expect(brewObject.keys.contains("next_recipe_draft"))
        #expect(brewObject["next_recipe_draft"] is NSNull)
    }

    @Test func postgrestTimestampFormatsDecodeAndEncodeAsUTC() throws {
        for (value, fraction) in [
            ("2024-01-02T03:04:56Z", 0.0),
            ("2024-01-02T03:04:56.125Z", 0.125),
            ("2024-01-02T03:04:56+00:00", 0.0),
            ("2024-01-02T03:04:56.125+00:00", 0.125),
        ] {
            let expected = Date(timeIntervalSince1970: 1_704_164_696 + fraction)
            let json = Data(#"{"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","created_at":"\#(value)","updated_at":"\#(value)","name":"DF54","stepless":false}"#.utf8)
            let dto = try SupabaseCoding.decoder().decode(GrinderDTO.self, from: json)
            #expect(abs(dto.createdAt.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.001)
        }

        let dto = GrinderDTO(Grinder(name: "DF54"))
        let encoded = try SupabaseCoding.encoder().encode(dto)
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        #expect((object["created_at"] as? String)?.hasSuffix("Z") == true)
        #expect((object["updated_at"] as? String)?.contains(".") == true)
    }

    private func roundTrip<T: Codable>(_ value: T, encoder: JSONEncoder, decoder: JSONDecoder) throws -> T {
        try decoder.decode(T.self, from: encoder.encode(value))
    }
}
