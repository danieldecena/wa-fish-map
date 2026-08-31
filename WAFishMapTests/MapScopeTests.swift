import Testing
@testable import WAFishMap

struct MapScopeTests {
    @Test func keepsAllMarineAreasAndAnyLaunch() {
        let thirteen = MarineArea(
            areaName: "13", areaTitle: "South Puget Sound", wac: "220-311-010",
            coordinates: [
                LonLat(longitude: -122.91, latitude: 47.15),
                LonLat(longitude: -122.72, latitude: 47.15),
                LonLat(longitude: -122.72, latitude: 47.09),
            ]
        )
        let eleven = MarineArea(
            areaName: "11", areaTitle: "Tacoma - Vashon Island", wac: "220-311-010",
            coordinates: thirteen.coordinates
        )
        // Statewide: every marine area is kept.
        #expect(Set(MapScope.filter(marineAreas: [thirteen, eleven]).map(\.areaName)) == ["13", "11"])

        let boston = AccessSite(
            facilityName: "Boston Harbor", countyName: "Thurston", hasLaunch: true,
            launchSurface: .concrete, hasRestrooms: true, directions: "",
            coordinate: LonLat(longitude: -122.9055, latitude: 47.1397)
        )
        let pierce = AccessSite(
            facilityName: "Point Defiance", countyName: "Pierce", hasLaunch: true,
            launchSurface: .concrete, hasRestrooms: false, directions: "",
            coordinate: LonLat(longitude: -122.51, latitude: 47.30)
        )
        let shore = AccessSite(
            facilityName: "Shore Access", countyName: "Mason", hasLaunch: false,
            launchSurface: .unknown, hasRestrooms: false, directions: "",
            coordinate: LonLat(longitude: -123.0, latitude: 47.2)
        )
        // Statewide: keep launches AND shore/bank access, any county.
        #expect(Set(MapScope.filter(accessSites: [boston, pierce, shore]).map(\.facilityName))
                == ["Boston Harbor", "Point Defiance", "Shore Access"])
    }

    @Test func statewideURLsHaveNoCountyOrAreaFilter() {
        let marine = MapScope.marineAreasURL.absoluteString
        #expect(marine.contains("/6/query"))
        #expect(marine.contains("where=1%3D1") || marine.contains("where=1=1"))
        #expect(marine.contains("maxAllowableOffset=0.002"))
        #expect(marine.contains("outSR=4326"))
        #expect(marine.contains("f=geojson"))

        let sites = MapScope.accessSitesURL.absoluteString
        #expect(sites.contains("/0/query"))
        #expect(sites.contains("where=1%3D1") || sites.contains("where=1=1"))
        #expect(!sites.contains("Thurston"))
        // Richer fields requested for the statewide sites.
        #expect(sites.contains("Camping"))
        #expect(sites.contains("ADAParking"))
        #expect(sites.contains("f=geojson"))

        let piers = MapScope.piersURL.absoluteString
        #expect(piers.contains("/1/query"))
        #expect(piers.contains("outFields=*") || piers.contains("outFields=%2A"))
        #expect(piers.contains("f=geojson"))
    }
}
