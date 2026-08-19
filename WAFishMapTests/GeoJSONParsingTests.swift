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
}
