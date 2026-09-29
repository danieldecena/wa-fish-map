import Testing
@testable import WAFishMap

struct TimeOfDayTests {
    @Test func bucketsByHour() {
        #expect(TimeOfDay(hour: 5) == .dawn)
        #expect(TimeOfDay(hour: 12) == .day)
        #expect(TimeOfDay(hour: 18) == .dusk)
        #expect(TimeOfDay(hour: 23) == .night)
        #expect(TimeOfDay(hour: 2) == .night)
    }

    @Test func primeLightOnlyAtDawnAndDusk() {
        #expect(TimeOfDay.dawn.isPrimeLight)
        #expect(TimeOfDay.dusk.isPrimeLight)
        #expect(!TimeOfDay.day.isPrimeLight)
        #expect(!TimeOfDay.night.isPrimeLight)
    }
}

/// The header chip shows the word; the sentence moved to the info popover.
/// Both still have to exist for every time of day -- dropping one silently
/// would leave a chip with no explanation behind it.
struct TimeOfDayChipTests {

    @Test func everyTimeOfDayHasBothAShortLabelAndASentence() {
        for t in [TimeOfDay.dawn, .day, .dusk, .night] {
            #expect(!t.label.isEmpty)
            #expect(!t.lightHint.isEmpty)
            #expect(!t.symbol.isEmpty)
            #expect(t.label.count <= 7, "\(t.label) is too long for a chip")
        }
    }

    @Test func theChipWordAndTheSentenceAreNotTheSameString() {
        for t in [TimeOfDay.dawn, .day, .dusk, .night] {
            #expect(t.label != t.lightHint)
        }
    }

    @Test func onlyDawnAndDuskReadAsPrimeLight() {
        #expect(TimeOfDay.dawn.isPrimeLight)
        #expect(TimeOfDay.dusk.isPrimeLight)
        #expect(!TimeOfDay.day.isPrimeLight)
        #expect(!TimeOfDay.night.isPrimeLight)
    }
}
