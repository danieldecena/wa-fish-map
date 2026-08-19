import CoreLocation
import Testing
@testable import WAFishMap

struct GeoJSONParsingTests {
    @Test func marineAreaUsesOuterRingAndDropsClosingVertex() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [-122.91, 47.15],
                    [-122.72, 47.15],
                    [-122.72, 47.09],
                    [-122.91, 47.09],
                    [-122.91, 47.15]
                  ],
                  [
                    [-122.85, 47.13],
                    [-122.84, 47.13],
                    [-122.84, 47.12],
                    [-122.85, 47.12],
                    [-122.85, 47.13]
                  ]
                ]
              },
              "properties": {
                "AreaName": "13",
                "AreaTitle": "South Puget Sound",
                "WAC": "220-311-010"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let areas = try WDFWLayerLoader.marineAreas(from: json)
        #expect(areas.count == 1)
        let area = areas[0]
        #expect(area.areaName == "13")
        #expect(area.areaTitle == "South Puget Sound")
        #expect(area.wac == "220-311-010")
        #expect(area.coordinates.count == 4)
        #expect(area.coordinates[0] == LonLat(longitude: -122.91, latitude: 47.15))
        #expect(area.coordinates[2] == LonLat(longitude: -122.72, latitude: 47.09))
        #expect(area.mapCoordinates[0].latitude == 47.15)
        #expect(area.mapCoordinates[0].longitude == -122.91)
    }

    @Test func marineAreaSkipsNonPolygonFeatures() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"Point","coordinates":[-122.9,47.14]},
           "properties":{"AreaName":"x","AreaTitle":"nope","WAC":"0"}}
        ]}
        """.data(using: .utf8)!
        let areas = try WDFWLayerLoader.marineAreas(from: json)
        #expect(areas.isEmpty)
    }

    @Test func accessSiteParsesBostonHarborWithoutSwappingLonLat() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": { "type": "Point", "coordinates": [-122.90550329432564, 47.13965712964172] },
              "properties": {
                "FacilityName": "Boston Harbor",
                "CountyName": "Thurston",
                "Launch": 1,
                "LaunchType": 1,
                "Restrooms": 1,
                "Directions": "Eastbay Drive to Boston Harbor Rd."
              }
            },
            {
              "type": "Feature",
              "geometry": { "type": "Point", "coordinates": [-122.72750155752296, 47.10093474591317] },
              "properties": {
                "FacilityName": "Luhr's Landing",
                "CountyName": "Thurston",
                "Launch": 1,
                "LaunchType": 1,
                "Restrooms": 1,
                "Directions": "I-5 exit 114 at Nisqually."
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let sites = try WDFWLayerLoader.accessSites(from: json)
        #expect(sites.count == 2)
        let boston = try #require(sites.first { $0.facilityName == "Boston Harbor" })
        #expect(boston.countyName == "Thurston")
        #expect(boston.hasLaunch)
        #expect(boston.launchSurface == .concrete)
        #expect(boston.launchSurface.label == "Concrete")
        #expect(boston.hasRestrooms)
        #expect(boston.coordinate.longitude == -122.90550329432564)
        #expect(boston.coordinate.latitude == 47.13965712964172)
        #expect(boston.mapCoordinate.latitude == 47.13965712964172)
    }

    @Test func accessSiteLaunchTypeFallsBackToUnknown() throws {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","geometry":{"type":"Point","coordinates":[-122.9,47.1]},
           "properties":{"FacilityName":"X","CountyName":"Thurston","Launch":1,"LaunchType":99,"Restrooms":0,"Directions":null}}
        ]}
        """.data(using: .utf8)!
        let sites = try WDFWLayerLoader.accessSites(from: json)
        #expect(sites[0].launchSurface == .unknown)
        #expect(sites[0].launchSurface.label == "Unknown")
        #expect(sites[0].directions.isEmpty)
        #expect(!sites[0].hasRestrooms)
    }
}
