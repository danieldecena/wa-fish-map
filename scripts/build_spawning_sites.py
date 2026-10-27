#!/usr/bin/env python3
"""Write Artifacts/salmon-rivers/sites.js: salmon viewing sites for the Map's Spawning mode.

    build_spawning_sites.py            write Artifacts/salmon-rivers/sites.js
    build_spawning_sites.py OUT.js     write somewhere else (for a diff)

Sites come from WDFW's Salmon Viewing list (wdfw.wa.gov/places-to-go/salmon-viewing),
typed in below with each site's own link. Species and months are typical timing for
that water unless src is "site" (the site or WDFW states them); src "none" means WDFW
lists the site but names no fish. This is timing guidance, not regulation.

Species names (fam and label) are exact WA Fish Map app names from fisheries.json;
the run (summer run, tule, ...) is kept in its own field, never glued to the name.
"Sockeye Salmon" is the one allowed name the app lacks (test/spawning.test.js holds
the allow-list). Fish-ladder rows are fish passing upstream, not spawning (pass).
"""
import json, re, sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'Artifacts' / 'salmon-rivers' / 'sites.js'

# Typical windows. best = peak months, good = other active months. Odd = pink salmon, odd years only.
R = {
  'chum':        ('Chum Salmon', 'Chum Salmon', None, [11], [12]),
  'chum-x':      ('Chum Salmon', 'Chum Salmon', None, [11], [10, 12]),
  'chum-col':    ('Chum Salmon', 'Chum Salmon', None, [11], [12]),
  'chum-late':   ('Chum Salmon', 'Chum Salmon', None, [12], [11, 1]),
  'summer-chum': ('Chum Salmon', 'Chum Salmon', 'summer run', [9], [10]),
  'coho':        ('Coho Salmon', 'Coho Salmon', None, [11], [10, 12]),
  'coho-oct':    ('Coho Salmon', 'Coho Salmon', None, [10], [11]),
  'coho-col':    ('Coho Salmon', 'Coho Salmon', None, [10, 11], [12]),
  'coho-sep':    ('Coho Salmon', 'Coho Salmon', None, [10], [9, 11]),
  'coho-ladder': ('Coho Salmon', 'Coho Salmon', None, [9], [10]),
  'coho-lgr':    ('Coho Salmon', 'Coho Salmon', None, [10], [11]),
  'fall-chinook':('Chinook Salmon', 'Fall Chinook', None, [9], [10]),
  'fall-chinook-wide': ('Chinook Salmon', 'Fall Chinook', None, [9], [8, 10]),
  'fall-chinook-ef': ('Chinook Salmon', 'Fall Chinook', None, [10], [9, 11]),
  'bright':      ('Chinook Salmon', 'Fall Chinook', 'upriver bright', [11], [10]),
  'tule':        ('Chinook Salmon', 'Fall Chinook', 'tule', [9], [8]),
  'summer-chinook': ('Chinook Salmon', 'Chinook Salmon', 'summer run', [10], [9]),
  'spring-chinook': ('Chinook Salmon', 'Chinook Salmon', 'spring run', [8], [7, 9]),
  'issaquah-chinook': ('Chinook Salmon', 'Chinook Salmon', None, [9, 10], [8]),
  'sockeye':     ('Sockeye Salmon', 'Sockeye Salmon', None, [10], [9, 11]),
  'sockeye-cle': ('Sockeye Salmon', 'Sockeye Salmon', None, [10], [9]),
  'pink':        ('Pink Salmon', 'Pink Salmon', 'odd years', [9], [10]),
  # fish ladders: fish passing upstream, not spawning
  'L-sockeye-ballard': ('Sockeye Salmon', 'Sockeye Salmon', None, [7], [6, 8]),
  'L-chinook-ballard': ('Chinook Salmon', 'Chinook Salmon', None, [8], [9]),
  'L-spring-bonn': ('Chinook Salmon', 'Chinook Salmon', 'spring run', [4], [5]),
  'L-sockeye-bonn': ('Sockeye Salmon', 'Sockeye Salmon', None, [6], [7]),
  'L-fall-bonn': ('Chinook Salmon', 'Fall Chinook', None, [9], [8]),
  'L-spring-lgr': ('Chinook Salmon', 'Chinook Salmon', 'spring run', [5], [4, 6]),
  'L-sockeye-lgr': ('Sockeye Salmon', 'Sockeye Salmon', None, [7], []),
  'L-fall-lgr': ('Chinook Salmon', 'Fall Chinook', None, [9], [10]),
  'L-sockeye-rr': ('Sockeye Salmon', 'Sockeye Salmon', None, [7], [8]),
  'L-summer-rr': ('Chinook Salmon', 'Chinook Salmon', 'summer run', [8], [7, 9]),
}

URBAN = ['chum', 'coho']          # small Puget Sound creeks
GREEN = ['fall-chinook', 'coho', 'chum', 'pink']

# id, name, county, kind, water, lat, lon, url, species keys, src, note
# src: 'site' = species/timing stated by the site or WDFW; 'typical' = typical for that water; 'none' = WDFW gives no species
S = [
 ('enchantment', 'Enchantment Park', 'Chelan', 'river', 'Wenatchee River', 47.5970, -120.6560, 'https://www.wta.org/go-hiking/hikes/enchantment-park', ['summer-chinook', 'coho'], 'typical', 'Blackbird Island trails along the Wenatchee in Leavenworth.'),
 ('entiat-nfh', 'Entiat National Fish Hatchery', 'Chelan', 'hatchery', 'Entiat River', 47.7180, -120.3030, 'https://www.fws.gov/fish-hatchery/entiat/visit-us', ['summer-chinook'], 'typical', None),
 ('leavenworth-nfh', 'Leavenworth National Fish Hatchery', 'Chelan', 'hatchery', 'Icicle Creek', 47.5605, -120.6750, 'https://www.fws.gov/fish-hatchery/leavenworth/visit-us', ['spring-chinook'], 'typical', 'Spring Chinook hold in Icicle Creek through summer before spawning.'),
 ('rocky-reach', 'Rocky Reach Discovery Center', 'Chelan', 'ladder', 'Columbia River', 47.5325, -120.2945, 'https://www.chelanpud.org/learning-center/rocky-reach-discovery-center', ['L-sockeye-rr', 'L-summer-rr'], 'typical', None),
 ('lyre', 'Lyre River Campground', 'Clallam', 'river', 'Lyre River', 48.1501, -123.8324, 'https://www.google.com/maps/place/Lyre+River+Campground/@48.1500903,-123.8346118,17z', ['coho', 'chum', 'pink'], 'typical', None),
 ('railroad-bridge', 'Railroad Bridge Park', 'Clallam', 'river', 'Dungeness River', 48.0838, -123.1448, 'https://dungenessrivercenter.org/explore/the-park/railroad-bridge-park', ['fall-chinook-wide', 'pink', 'coho', 'chum'], 'typical', 'Home of the Dungeness River Nature Center in Sequim.'),
 ('sol-duc', 'Sol Duc Salmon Cascades', 'Clallam', 'falls', 'Sol Duc River', 47.9667, -123.8625, 'https://www.nps.gov/thingstodo/salmoncascades.htm', ['coho-sep'], 'typical', 'Coho leap the cascades on their way upstream. Olympic National Park.'),
 ('grist-mill', 'Cedar Creek Grist Mill', 'Clark', 'ladder', 'Cedar Creek', 45.9384, -122.5745, 'https://www.cedarcreekgristmill.org', ['coho'], 'typical', 'A fish ladder beside the 1876 mill, near Woodland.'),
 ('daybreak', 'Daybreak Park', 'Clark', 'river', 'East Fork Lewis River', 45.8150, -122.5895, 'https://clark.wa.gov/public-works/daybreak-regional-park-and-boat-launch', ['fall-chinook-ef', 'coho', 'chum'], 'typical', None),
 ('lewisville', 'Lewisville Park', 'Clark', 'river', 'East Fork Lewis River', 45.8125, -122.5300, 'https://clark.wa.gov/public-works/lewisville-regional-park', ['fall-chinook-ef', 'coho', 'chum'], 'typical', None),
 ('lucia-falls', 'Lucia Falls Regional Park', 'Clark', 'falls', 'East Fork Lewis River', 45.8357, -122.4231, 'https://clark.wa.gov/public-works/lucia-falls-regional-park', ['fall-chinook-ef', 'coho'], 'typical', None),
 ('abernathy', 'Abernathy Creek Wildlife Area', 'Cowlitz', 'creek', 'Abernathy Creek', 46.1990, -123.1665, 'https://wdfw.wa.gov/places-to-go/wildlife-areas/abernathy-creek-wildlife-area-unit', ['fall-chinook', 'coho', 'chum'], 'typical', None),
 ('modrow', 'Modrow Bridge', 'Cowlitz', 'river', 'Kalama River', 46.0450, -122.8240, 'https://wdfw.wa.gov/places-to-go/water-access-sites/30066', ['fall-chinook', 'coho-oct'], 'typical', None),
 ('lower-granite', 'Lower Granite Dam', 'Garfield', 'ladder', 'Snake River', 46.6580, -117.4331, 'https://www.google.com/maps/place/Lower+Granite+Dam+Fish+Ladder+Visitor+Center/@46.6580382,-117.4353109,17z', ['L-spring-lgr', 'L-sockeye-lgr', 'L-fall-lgr', 'coho-lgr'], 'typical', 'Visitor center window on the fish ladder.'),
 ('vernita', 'Vernita Bar', 'Grant', 'river', 'Columbia River, Hanford Reach', 46.6390, -119.7380, 'https://www.grantpud.org/visit-us', ['bright'], 'typical', 'Park at Jackson Fish Camp and walk to the bar. The Hanford Reach holds the largest wild fall Chinook spawning in the Columbia.'),
 ('quilcene-bridge', 'Quilcene River bridge', 'Jefferson', 'river', 'Big Quilcene River', 47.8110, -122.8713, 'https://www.google.com/maps/place/Linger+Longer+Rd,+Washington+98376/@47.8105436,-122.8741877,17z', ['summer-chum', 'coho-oct', 'chum', 'pink'], 'typical', 'Bridge on Linger Longer Road.'),
 ('discovery-bay', 'Discovery Bay Wildlife Area', 'Jefferson', 'creek', 'Snow and Salmon creeks', 47.9925, -122.8795, 'https://wdfw.wa.gov/places-to-go/wildlife-areas/discovery-bay-wildlife-area-unit', ['summer-chum', 'coho'], 'typical', None),
 ('dosewallips', 'Dosewallips State Park', 'Jefferson', 'river', 'Dosewallips River', 47.6874, -122.9046, 'https://www.google.com/maps/place/Dosewallips+State+Park/@47.6851194,-122.9137797,14z', ['summer-chum', 'chum', 'pink', 'coho'], 'typical', None),
 ('quilcene-nfh', 'Quilcene National Fish Hatchery', 'Jefferson', 'hatchery', 'Big Quilcene River', 47.8228, -122.8745, 'https://www.fws.gov/fish-hatchery/quilcene', ['coho-sep', 'summer-chum'], 'typical', None),
 ('illahee', 'Illahee Preserve', 'Kitsap', 'creek', 'Illahee Creek', 47.6105, -122.6020, 'https://saveland.org/protected-properties/illahee-preserve/', URBAN, 'typical', 'In Bremerton. WDFW lists it under Jefferson County.'),
 ('ballard', 'Ballard Locks Fish Ladder', 'King', 'ladder', 'Lake Washington Ship Canal', 47.6656, -122.3975, 'https://ballardlocks.org/fish-salmon-ladder.html', ['L-sockeye-ballard', 'L-chinook-ballard', 'coho-ladder'], 'site', 'Underwater viewing windows on the ladder.'),
 ('duwamish', 'Duwamish Gardens Park', 'King', 'river', 'Duwamish River', 47.4920, -122.2900, 'https://www.tukwilawa.gov/departments/parks-and-recreation/parks-and-trails/duwamish-gardens', ['fall-chinook-wide', 'coho-oct'], 'typical', 'Restored estuary habitat. Fish pass through here on the way up the Green.'),
 ('fenster', 'Fenster Nature Park', 'King', 'river', 'Green River', 47.3020, -122.1960, 'https://www.auburnwa.gov/city_hall/parks_arts_recreation/parks_trails/fenster_nature_park', GREEN, 'typical', None),
 ('flaming-geyser', 'Flaming Geyser State Park', 'King', 'river', 'Green River', 47.2770, -122.0330, 'https://parks.wa.gov/find-parks/state-parks/flaming-geyser-state-park', GREEN, 'typical', None),
 ('issaquah', 'Issaquah Salmon Hatchery', 'King', 'hatchery', 'Issaquah Creek', 47.5297, -122.0390, 'https://www.issaquahfish.org', ['issaquah-chinook', 'coho'], 'site', 'Open dawn to dusk every day. Chinook spawn mid-September to mid-October; coho late October to early December.'),
 ('landsburg', 'Landsburg Park and fish ladder', 'King', 'river', 'Cedar River', 47.3780, -121.9620, 'https://archive.seattletimes.com/archive/?date=20011122&slug=walk22', ['sockeye', 'fall-chinook', 'coho'], 'typical', 'On the Cedar River Trail.'),
 ('metzler', 'Metzler Park', 'King', 'river', 'Green River', 47.2930, -122.0975, 'https://kingcounty.gov/en/legacy/services/environment/water-and-land/natural-lands/ecological/green-river.aspx', ['fall-chinook', 'coho', 'chum'], 'typical', 'Part of the Green River Natural Area, off SE Green Valley Road.'),
 ('north-creek', 'North Creek Trail at UW Bothell', 'King', 'creek', 'North Creek', 47.7595, -122.1915, 'https://www.uwb.edu/about/salmon', ['fall-chinook', 'coho'], 'typical', None),
 ('pipers', "Piper's Creek", 'King', 'creek', "Piper's Creek, Carkeek Park", 47.7106, -122.3711, 'https://parkways.seattle.gov/2022/10/05/visit-with-carkeek-park-salmon-stewards-nov-5-dec-6/', URBAN, 'site', 'Salmon stewards are usually on the trail on weekends in November and early December.'),
 ('renton-library', 'Renton Library', 'King', 'river', 'Cedar River', 47.4826, -122.2068, 'https://kcls.org/locations/renton/', ['sockeye', 'fall-chinook'], 'typical', 'The library is built over the river. Watch from the bridge and the trail.'),
 ('soos', 'Soos Creek Salmon Hatchery', 'King', 'hatchery', 'Soos Creek', 47.3108, -122.1667, 'https://wdfw.wa.gov/fishing/management/hatcheries/facilities?county=42', ['fall-chinook-wide', 'coho'], 'typical', None),
 ('tukwila-bridge', 'Tukwila Urban Center Pedestrian Bridge', 'King', 'river', 'Green River', 47.4592, -122.2453, 'https://www.google.com/maps/place/Tukwila+Urban+Center+Pedestrian+Bridge/@47.45916,-122.2475244,17z', ['fall-chinook', 'coho-oct', 'pink'], 'typical', None),
 ('chico', 'Chico Salmon Park', 'Kitsap', 'creek', 'Chico Creek', 47.5935, -122.7055, 'https://www.kitsapgov.com/parks/Pages/ChicoSalmonPark.aspx', ['chum-x', 'coho'], 'typical', 'Chico Creek carries one of the largest chum runs in Kitsap County.'),
 ('clear-creek', 'Clear Creek Trail Ridgetop Pavilion', 'Kitsap', 'creek', 'Clear Creek', 47.6590, -122.6905, 'https://www.clearcreektrail.org/map', URBAN, 'typical', 'In Silverdale.'),
 ('cowling', 'Cowling Creek', 'Kitsap', 'creek', 'Cowling Creek', 47.7555, -122.5510, 'https://greatpeninsula.org/property/cowling-creek-forest-preserve', ['chum'], 'typical', None),
 ('grovers', 'Grovers Creek Salmon Hatchery', 'Kitsap', 'hatchery', 'Grovers Creek', 47.7712, -122.5640, 'https://suquamish.nsn.us/home/departments/fisheries/finfish/salmon-enhancement/', ['fall-chinook', 'chum'], 'typical', 'Run by the Suquamish Tribe.'),
 ('keta', 'Keta Legacy Rhododendron Preserve', 'Kitsap', 'creek', 'Seabeck Highway creeks', 47.6080, -122.7540, 'https://ketalegacy.org/rhododendron-preserve/visit/', ['chum-x'], 'site', 'Spawning is usually in November, earlier or later with stream flow. Park at the Kitsap Forest Theater, 2401 Seabeck Hwy NW.'),
 ('poulsbo', "Poulsbo's Fish Park", 'Kitsap', 'creek', 'Dogfish Creek', 47.7400, -122.6430, 'https://greatpeninsula.org/property/poulsbo-fish-park', URBAN, 'typical', None),
 ('salmon-haven', 'Salmon Haven at Dickerson Creek', 'Kitsap', 'creek', 'Dickerson and Chico creeks', 47.5915, -122.7195, 'https://s3.wp.wsu.edu/uploads/sites/2074/2019/10/Salmon-Haven.pdf', ['chum', 'coho'], 'site', 'Mostly chum, with an occasional coho. Near Taylor Road and Northlake Way.'),
 ('cooper', 'Cooper River Bridge', 'Kittitas', 'river', 'Cooper River', 47.4040, -121.1000, 'https://mtsgreenway.org/blog/salmon-viewing-in-the-greenway/', ['sockeye-cle'], 'site', 'Sockeye returned to the Cle Elum basin through a reintroduction program. From Cle Elum take SR 903 and NF-46 toward Cooper Lake.'),
 ('gold-creek', 'Gold Creek Bridge', 'Kittitas', 'creek', 'Gold Creek', 47.3965, -121.3790, 'https://www.wta.org/go-hiking/hikes/gold-creek-pond-snowshoe', [], 'none', 'Near Snoqualmie Pass. WDFW lists this site but does not say which fish run here.'),
 ('cowlitz-hatchery', 'Cowlitz Salmon Hatchery', 'Lewis', 'hatchery', 'Cowlitz River', 46.5125, -122.6290, 'https://www.mytpu.org/community-environment/fish-wildlife-environment/cowlitz-river-project/cowlitz-fisheries-programs/cowlitz-salmon-hatchery/', ['fall-chinook', 'coho-col'], 'typical', 'Run by Tacoma Power near Salkum.'),
 ('bayshore', 'Bayshore Preserve', 'Mason', 'creek', 'Johns Creek', 47.2340, -123.0700, 'https://capitollandtrust.org/salmon-experience4', ['chum'], 'site', 'Docent-led days in early November. On Oakland Bay off SR 3 near Shelton.'),
 ('george-adams', 'George Adams Fish Hatchery', 'Mason', 'hatchery', 'Purdy Creek', 47.3000, -123.1745, 'https://wdfw.wa.gov/places-to-go/wildlife-areas/skokomish-wildlife-area-unit', ['fall-chinook', 'coho', 'chum'], 'typical', None),
 ('hoodsport', 'Hoodsport Hatchery', 'Mason', 'hatchery', 'Finch Creek', 47.4050, -123.1410, 'https://wdfw.wa.gov/places-to-go/fishing-piers/hoodsport-hatchery-handicap-platform', ['chum', 'fall-chinook', 'pink'], 'typical', 'Wheelchair-accessible viewing platform.'),
 ('kennedy', 'Kennedy Creek Salmon Trail', 'Mason', 'creek', 'Kennedy Creek', 47.0960, -123.0880, 'https://spsseg.org/education-outreach/kcst/', ['chum'], 'site', 'About 20,000 chum return each year. The trail usually opens on weekends from early November to early December.'),
 ('alma', 'Alma Park', 'Okanogan', 'river', 'Okanogan River', 48.3595, -119.5800, 'https://okanogancountry.com/poi/alma-park', ['summer-chinook'], 'typical', '601 1st Ave S, Okanogan.'),
 ('island-park', 'Island Park Trail', 'Okanogan', 'river', 'Okanogan River', 48.3555, -119.5770, 'https://okanogancountry.com/poi/island-park-trail', ['summer-chinook'], 'typical', 'Just south of First Avenue in Okanogan.'),
 ('spring-creek-bridge', 'Spring Creek Bridge', 'Okanogan', 'creek', 'Spring Creek', 48.4800, -120.1870, 'https://winthropwashington.com/business-directory/spring-creek-bridge', ['spring-chinook'], 'typical', 'In Winthrop. Location is approximate.'),
 ('winthrop-nfh', 'Winthrop National Fish Hatchery', 'Okanogan', 'hatchery', 'Methow River', 48.4762, -120.1815, 'https://www.fws.gov/fish-hatchery/winthrop/visit-us', ['spring-chinook', 'coho'], 'typical', None),
 ('clarks', 'Clarks Creek Park', 'Pierce', 'creek', 'Clarks Creek', 47.1845, -122.3085, 'https://www.cityofpuyallup.org/Facilities/Facility/Details/Clarks-Creek-Park-South-4', URBAN, 'typical', 'In Puyallup, north and south parks.'),
 ('donkey', 'Donkey Creek Park', 'Pierce', 'creek', 'Donkey Creek', 47.3355, -122.5870, 'https://www.gigharborwa.gov/183/Donkey-Creek-Park', URBAN, 'typical', 'In Gig Harbor.'),
 ('minter', 'Minter Creek Fish Hatchery', 'Pierce', 'hatchery', 'Minter Creek', 47.3745, -122.7010, 'https://wdfw.wa.gov/fishing/management/hatcheries/facilities?county=43', ['chum', 'coho', 'fall-chinook'], 'typical', None),
 ('swan', 'Swan Creek Park', 'Pierce', 'creek', 'Swan Creek', 47.2235, -122.3905, 'https://www.metroparkstacoma.org/event/salmon-saturdays/', URBAN, 'typical', 'Metro Parks Tacoma runs Salmon Saturdays here in the fall.'),
 ('bonneville', 'Bonneville Dam Washington Shore', 'Skamania', 'ladder', 'Columbia River', 45.6440, -121.9420, 'https://www.nwp.usace.army.mil/bonneville/', ['L-spring-bonn', 'L-sockeye-bonn', 'L-fall-bonn', 'coho-ladder'], 'typical', 'Visitor center with underwater ladder windows.'),
 ('dougan', 'Dougan Falls', 'Skamania', 'falls', 'Washougal River', 45.6745, -122.1540, 'https://www.dnr.wa.gov/Yacolt#dougan', ['fall-chinook', 'coho-oct'], 'typical', None),
 ('hamilton', 'Hamilton Creek Trail', 'Skamania', 'creek', 'Hamilton Creek', 45.6440, -121.9750, 'https://www.wta.org/go-hiking/hikes/fort-cascades-loop', ['chum-col', 'coho'], 'typical', 'Via the North Bonneville Heritage Trails. One of the few Columbia River chum spawning areas.'),
 ('salmon-falls', 'Salmon Falls Bridge', 'Skamania', 'falls', 'Washougal River', 45.6141, -122.2023, 'https://www.google.com/maps/place/3302+Salmon+Falls+Rd,+Washougal,+WA+98671/@45.6140605,-122.2023005,17z', ['fall-chinook', 'coho-oct'], 'typical', '3302 Salmon Falls Rd, Washougal.'),
 ('spring-creek-nfh', 'Spring Creek National Fish Hatchery', 'Skamania', 'hatchery', 'Columbia River', 45.7275, -121.5400, 'https://www.fws.gov/fish-hatchery/spring-creek/visit-us', ['tule'], 'typical', 'Near Underwood.'),
 ('washougal-hatchery', 'Washougal Hatchery', 'Skamania', 'hatchery', 'Washougal River', 45.6170, -122.1900, 'https://wdfw.wa.gov/fishing/management/hatcheries/facilities?county=68', ['fall-chinook', 'coho-oct'], 'typical', 'Location is approximate.'),
 ('osprey', 'Osprey Park', 'Snohomish', 'river', 'Sultan River', 47.8665, -121.8150, 'https://www.cascadeloop.com/account/osprey-park', ['fall-chinook', 'pink', 'coho', 'chum'], 'typical', 'In Sultan.'),
 ('fifth-ave', '5th Avenue Bridge', 'Thurston', 'river', 'Deschutes River outlet', 47.0450, -122.9060, 'https://www.experienceolympia.com/blog/where-to-view-the-chinook-salmon-run-in-olympia', ['fall-chinook-wide'], 'site', 'Chinook gather below the dam at Capitol Lake before heading to Tumwater Falls.'),
 ('tumwater', 'Brewery Park at Tumwater Falls', 'Thurston', 'falls', 'Deschutes River', 47.0135, -122.9050, 'https://olytumfoundation.org/park/', ['fall-chinook-wide'], 'typical', 'Fish ladders run beside the falls.'),
 ('mclane', 'McLane Creek Nature Trail', 'Thurston', 'creek', 'McLane Creek', 47.0330, -123.0060, 'https://www.wta.org/go-hiking/hikes/mclane-creek', ['chum'], 'site', 'Chum from mid-November to mid-December. Stewards on weekends. Parking needs a Discover Pass.'),
 ('grays', 'Grays River Covered Bridge', 'Wahkiakum', 'river', 'Grays River', 46.3548, -123.5811, 'https://www.google.com/maps/place/Grays+River+Covered+Bridge/@46.3540791,-123.5899942,15z', ['chum-col', 'coho'], 'typical', None),
 ('arroyo', 'Arroyo Park', 'Whatcom', 'creek', 'Chuckanut Creek', 48.6960, -122.4870, 'https://cob.org/services/environment/restoration/chuckanut-creek-2', URBAN, 'typical', 'In Bellingham.'),
 ('berthusen', 'Berthusen Park', 'Whatcom', 'creek', 'Bertrand Creek', 48.9615, -122.5280, 'https://www.lyndenwa.org/Facilities/Facility/Details/Berthusen-Park-4', ['coho'], 'typical', 'In Lynden.'),
 ('birch-bay', 'Birch Bay State Park', 'Whatcom', 'creek', 'Terrell Creek', 48.9050, -122.7610, 'https://parks.wa.gov/find-parks/state-parks/birch-bay-state-park', URBAN, 'typical', None),
 ('cornwall', 'Cornwall Park', 'Whatcom', 'creek', 'Squalicum Creek', 48.7710, -122.4880, 'https://cob.org/services/recreation/parks-trails/parks-guide/cornwall-park', URBAN, 'typical', 'In Bellingham.'),
 ('fairhaven', 'Fairhaven Park', 'Whatcom', 'creek', 'Padden Creek', 48.7130, -122.4930, 'https://cob.org/services/recreation/parks-trails/parks-guide/fairhaven-park', URBAN, 'typical', 'In Bellingham.'),
 ('lynden-park', 'Lynden City Park', 'Whatcom', 'creek', 'Fishtrap Creek', 48.9450, -122.4505, 'https://explorewashingtonstate.com/exploring-lynden-city-park/', ['coho'], 'typical', None),
 ('maple-creek', 'Maple Creek Park', 'Whatcom', 'river', 'North Fork Nooksack River', 48.9220, -122.0820, 'https://www.whatcomcounty.us/3554/Maple-Creek-Park', ['fall-chinook-wide', 'pink', 'coho', 'chum'], 'typical', 'Near Maple Falls.'),
 ('maritime', 'Maritime Heritage Park', 'Whatcom', 'hatchery', 'Whatcom Creek', 48.7550, -122.4780, 'https://cob.org/services/recreation/parks-trails/parks-guide/maritime-heritage-park', ['summer-chinook', 'chum', 'coho'], 'typical', 'A small hatchery on Whatcom Creek in downtown Bellingham.'),
 ('skookum', 'Skookum Creek Fish Hatchery', 'Whatcom', 'hatchery', 'South Fork Nooksack River', 48.6705, -122.1600, 'https://www.lummi-nsn.gov/Website.php?PageID=45', ['coho', 'spring-chinook'], 'typical', 'Run by the Lummi Nation.'),
 ('indian-creek', 'Indian Creek Campground', 'Yakima', 'creek', 'Indian Creek, Rimrock Lake', 46.6455, -121.2560, 'https://www.fs.usda.gov/recarea/okawen/recarea/?recid=58293', [], 'none', 'On US 12 near White Pass. WDFW lists this site but does not say which fish run here.'),
]

KIND = {'creek': 'Spawning creek', 'river': 'River', 'hatchery': 'Hatchery', 'ladder': 'Fish ladder', 'falls': 'Falls'}
out, ids = [], set()
for (i, name, county, kind, water, lat, lon, url, sp, src, note) in S:
    assert i not in ids, i; ids.add(i)
    assert 45.5 <= lat <= 49.0 and -124.8 <= lon <= -116.9, (i, lat, lon)
    assert kind in KIND and src in ('site', 'typical', 'none', 'added'), i
    assert (src == 'none') == (len(sp) == 0), i
    assert url.startswith('https://'), i
    rows = []
    for k in sp:
        fam, label, run, best, good = R[k]
        assert not set(best) & set(good) and all(1 <= m <= 12 for m in best + good), k
        r = {'fam': fam, 'label': label, 'best': best, 'good': good}
        if run: r['run'] = run
        if fam == 'Pink Salmon': r['odd'] = True
        if k.startswith('L-') or (kind == 'ladder' and fam != 'Pink'): r['pass'] = True
        rows.append(r)
    out.append({'id': i, 'name': name, 'county': county, 'kind': kind, 'water': water, 'lat': lat, 'lon': lon,
                'url': url, 'src': src, 'note': note, 'sp': rows})

open(sys.argv[1] if len(sys.argv) > 1 else OUT, 'w').write('/* Salmon viewing sites. From WDFW\'s Salmon Viewing list (wdfw.wa.gov/places-to-go/salmon-viewing).\n'
    ' * Species and months are typical for each water unless src is "site". Generated by scripts/build_spawning_sites.py. */\n'
    'window.SITES = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n')
print(len(out), 'sites;', sum(1 for o in out if o['src'] != 'added'), 'from WDFW;', {k: sum(1 for o in out if o['kind'] == k) for k in KIND})
