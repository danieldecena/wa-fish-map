import Testing
@testable import WAFishMap

struct MapScopeTests {
    @Test func keepsOnlyArea13AndThurston() {
        let thirteen = MarineArea(
            areaName: "13",
            areaTitle: "South Puget Sound",
            wac: "220-311-010",
            coordinates: [
                LonLat(longitude: -122.91, latitude: 47.15),
                LonLat(longitude: -122.72, latitude: 47.15),
                LonLat(longitude: -122.72, latitude: 47.09),
            ]
        )
        let eleven = MarineArea(
            areaName: "11",
            areaTitle: "Tacoma - Vashon Island",
            wac: "220-311-010",
            coordinates: thirteen.coordinates
        )
        #expect(MapScope.filter(marineAreas: [thirteen, eleven]).map(\.areaName) == ["13"])

        let boston = AccessSite(
            facilityName: "Boston Harbor",
            countyName: "Thurston",
            hasLaunch: true,
            launchSurface: .concrete,
            hasRestrooms: true,
            directions: "",
            coordinate: LonLat(longitude: -122.90550329432564, latitude: 47.13965712964172)
        )
        let defiance = AccessSite(
            facilityName: "Not In Layer",
            countyName: "Pierce",
            hasLaunch: true,
            launchSurface: .concrete,
            hasRestrooms: false,
            directions: "",
            coordinate: LonLat(longitude: -122.51, latitude: 47.30)
        )
        #expect(MapScope.filter(accessSites: [boston, defiance]).map(\.facilityName) == ["Boston Harbor"])
    }

    @Test func scopedURLsAskOnlyForArea13AndThurston() {
        let marine = MapScope.marineAreasURL.absoluteString
        #expect(marine.contains("/6/query"))
        #expect(marine.contains("%2713%27") || marine.contains("'13'"))
        #expect(marine.contains("maxAllowableOffset=0.002"))
        #expect(marine.contains("outSR=4326"))
        #expect(marine.contains("f=geojson"))

        let sites = MapScope.accessSitesURL.absoluteString
        #expect(sites.contains("/0/query"))
        #expect(sites.contains("Launch=1") || sites.contains("Launch%3D1"))
        #expect(sites.contains("Thurston"))
        #expect(sites.contains("f=geojson"))
    }
}
