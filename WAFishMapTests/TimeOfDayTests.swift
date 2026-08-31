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
