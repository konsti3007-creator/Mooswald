extends RefCounted
## Game content as data: goods, buildings, recipes, quests, specialists,
## natural positions and seasons. Balancing and new content are edited here;
## the simulation reads these tables. Positions use Vector2i, sizes too.

const NAMES := {"holz":"Holz","stein":"Stein","nahrung":"Nahrung","getreide":"Korn","mehl":"Mehl","bretter":"Bretter","brot":"Brot","muenzen":"Münzen","beeren":"Beeren","honig":"Honig","marmelade":"Marmelade","karotten":"Karotten","kartoffeln":"Kartoffeln","kohl":"Kohl","zwiebeln":"Zwiebeln","kuerbis":"Kürbisse","flachs":"Flachs","sonnenblumen":"Sonnenblumen","fisch":"Fisch","raeucherfisch":"Räucherfisch","eier":"Eier","wolle":"Wolle","milch":"Milch","kaese":"Käse"}

const INITIAL := {"holz":100, "stein":45, "nahrung":12, "getreide":0, "mehl":0, "bretter":0, "brot":0, "muenzen":220, "beeren":0, "honig":0, "marmelade":0, "karotten":0, "kartoffeln":0, "kohl":0, "zwiebeln":0, "kuerbis":0, "flachs":0, "sonnenblumen":0, "fisch":0, "raeucherfisch":0, "eier":0, "wolle":0, "milch":0, "kaese":0}

const SPECIAL_HOUSES := ["HausHolz","HausGarten","HausStein","HausBau","HausBaecker","HausImker","HausKraeuter","HausHandel"]

const DECORATIONS := ["Weg","Baum","Blumenbeet","Brunnen","Bank","Laterne","Strauch","Wildbaum","Felsen"]

const DEFS := {
	"Huehnerhof":{"label":"Hühnerhof", "category":"Tiere", "size":Vector2i(3,3), "cost":{"holz":30,"bretter":6,"muenzen":50}, "level":4, "duration":20.0, "input":{"getreide":2}, "output":{"eier":4}, "herd":"huhn", "pen":true},
	"Schafweide":{"label":"Schafweide", "category":"Tiere", "size":Vector2i(3,3), "cost":{"holz":40,"bretter":10,"muenzen":70}, "level":6, "duration":30.0, "input":{"getreide":2}, "output":{"wolle":3}, "herd":"schaf", "pen":true},
	"Ziegenstall":{"label":"Ziegenweide", "category":"Tiere", "size":Vector2i(3,3), "cost":{"holz":35,"stein":10,"bretter":8,"muenzen":70}, "level":7, "duration":24.0, "input":{"getreide":1}, "output":{"milch":3}, "herd":"ziege", "pen":true},
	"Kaeserei":{"label":"Käserei", "category":"Tiere", "size":Vector2i(2,2), "cost":{"bretter":14,"stein":12,"muenzen":80}, "level":8, "duration":20.0, "input":{"milch":3}, "output":{"kaese":2,"nahrung":3}, "sign":"cheese", "art":"Baeckerei"},
	"Lager":{"label":"Vorratsscheune", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":30,"stein":10,"muenzen":40}, "level":2, "storage":150, "sign":"crate", "art":"Saegewerk"},
	"Angler":{"label":"Anglerhütte", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":25,"muenzen":40}, "level":3, "gather":"fisch", "sign":"fish", "art":"Forsthaus", "near_water":true},
	"Raeucherei":{"label":"Räucherkate", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":30,"stein":12,"muenzen":60}, "level":5, "duration":16.0, "input":{"fisch":3,"holz":2}, "output":{"raeucherfisch":3,"nahrung":3}, "sign":"smoke", "art":"Kochhaus"},
	"Haus":{"label":"Wurzelhäuschen", "category":"Wohnen", "size":Vector2i(2,2), "cost":{"holz":12,"stein":4,"muenzen":25}, "level":1},
	"Feld":{"label":"Ackerbeet", "category":"Ernte", "size":Vector2i.ONE, "cost":{"holz":3,"muenzen":5}, "level":1, "duration":24.0, "harvest":{"getreide":6,"nahrung":2,"muenzen":3}},
	"Forsthaus":{"label":"Forsthütte", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":15,"muenzen":25}, "level":1, "gather":"holz"},
	"Steinbruch":{"label":"Kieselsammler", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":12,"muenzen":20}, "level":1, "gather":"stein"},
	"Saegewerk":{"label":"Sägemühle", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":20,"stein":8,"muenzen":35}, "level":2, "duration":14.0, "input":{"holz":6}, "output":{"bretter":4}},
	"Muehle":{"label":"Kornmühle", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"holz":18,"stein":10,"muenzen":35}, "level":2, "duration":12.0, "input":{"getreide":4}, "output":{"mehl":3}},
	"Baeckerei":{"label":"Ofenstube", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"bretter":6,"stein":12,"muenzen":45}, "level":3, "duration":16.0, "input":{"mehl":3}, "output":{"brot":3,"nahrung":3}},
	"Weg":{"label":"Waldweg", "category":"Wege", "size":Vector2i.ONE, "cost":{"muenzen":1}, "level":1},
	"Baum":{"label":"Honigbaum", "category":"Natur", "size":Vector2i.ONE, "cost":{"muenzen":4}, "level":1},
	"Wildbaum":{"label":"Jungbaum für den Forst", "category":"Natur", "size":Vector2i.ONE, "cost":{"muenzen":3}, "level":1, "wild":true},
	"Felsen":{"label":"Findling", "category":"Wildnis", "size":Vector2i.ONE, "cost":{}, "level":99, "wild":true},
	"Blumenbeet":{"label":"Wiesenblumen", "category":"Natur", "size":Vector2i.ONE, "cost":{"muenzen":6}, "level":1},
	"Imkerei":{"label":"Sonnenimkerei", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"bretter":12,"stein":8,"muenzen":55}, "level":4, "duration":20.0, "input":{}, "output":{"honig":3}},
	"Beeren":{"label":"Beerengarten", "category":"Ernte", "size":Vector2i.ONE, "cost":{"holz":6,"muenzen":12}, "level":3, "duration":30.0, "harvest":{"beeren":5,"nahrung":2}},
	"Kochhaus":{"label":"Marmeladenküche", "category":"Handwerk", "size":Vector2i(2,2), "cost":{"bretter":16,"stein":14,"muenzen":75}, "level":4, "duration":18.0, "input":{"honig":2,"beeren":4}, "output":{"marmelade":3}},
	"Gasthaus":{"label":"Gasthaus zum Blätterdach", "category":"Wohnen", "size":Vector2i(2,2), "cost":{"bretter":24,"stein":20,"muenzen":110}, "level":5, "duration":24.0, "input":{"brot":2,"marmelade":1}, "output":{"muenzen":30,"nahrung":2}},
	"Bank":{"label":"Waldliege", "category":"Natur", "size":Vector2i.ONE, "cost":{"bretter":2,"muenzen":8}, "level":2},
	"Laterne":{"label":"Glühwürmchenlaterne", "category":"Natur", "size":Vector2i.ONE, "cost":{"holz":4,"muenzen":12}, "level":3},
	"Strauch":{"label":"Farninsel", "category":"Natur", "size":Vector2i.ONE, "cost":{"muenzen":5}, "level":1},
	"Brunnen":{"label":"Quellbrunnen", "category":"Natur", "size":Vector2i.ONE, "cost":{"stein":10,"muenzen":20}, "level":2},
	"HausHolz":{"label":"Hütte der Holzmeisterin", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"holz":30,"stein":6,"muenzen":60}, "level":2, "special":"holz"},
	"HausGarten":{"label":"Gärtnerhäuschen", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"holz":24,"stein":8,"muenzen":60}, "level":2, "special":"garten"},
	"HausStein":{"label":"Kate des Steinkundigen", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"holz":20,"stein":20,"muenzen":70}, "level":3, "special":"stein"},
	"HausBau":{"label":"Werkhaus des Baumeisters", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"bretter":14,"stein":14,"muenzen":90}, "level":3, "special":"bau"},
	"HausBaecker":{"label":"Stübchen des Bäckers", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"bretter":16,"stein":12,"muenzen":90}, "level":4, "special":"brot"},
	"HausImker":{"label":"Wabenhäuschen der Imkerin", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"bretter":18,"stein":10,"muenzen":100}, "level":5, "special":"honig"},
	"HausKraeuter":{"label":"Kräuterhütte", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"bretter":18,"stein":16,"muenzen":110}, "level":5, "special":"kraeuter"},
	"HausHandel":{"label":"Haus des Händlers", "category":"Bewohner", "size":Vector2i(2,2), "cost":{"bretter":24,"stein":18,"muenzen":140}, "level":6, "special":"handel"}
}

const SPECIALISTS := {
	"holz":{"name":"Birka","role":"Holzmeisterin","effect":"Holzfäller tragen 2 Holz mehr pro Gang.","job":"Forsthaus","palette":5,"sign":"axe"},
	"garten":{"name":"Ilvi","role":"Gärtnerin","effect":"Kornbeete und Beerengärten wachsen 20 % schneller.","job":"","palette":6,"sign":"sprout"},
	"stein":{"name":"Kolbo","role":"Steinkundiger","effect":"Steinsammler tragen 2 Stein mehr; Findlinge wachsen schneller nach.","job":"Steinbruch","palette":7,"sign":"pick"},
	"bau":{"name":"Zimmerling","role":"Baumeister","effect":"Ausbauten kosten 20 % weniger.","job":"Saegewerk","palette":8,"sign":"hammer"},
	"brot":{"name":"Mehlwin","role":"Bäcker","effect":"Jede Ofenstube backt 1 Brot mehr pro Durchgang.","job":"Baeckerei","palette":9,"sign":"bread"},
	"honig":{"name":"Summa","role":"Imkerin","effect":"Jede Imkerei liefert 1 Honig mehr.","job":"Imkerei","palette":10,"sign":"bee"},
	"kraeuter":{"name":"Salbei","role":"Kräuterkundige","effect":"Waldlinge erholen sich doppelt so schnell und brauchen ein Viertel weniger Nahrung.","job":"","palette":11,"sign":"leaf"},
	"handel":{"name":"Taler","role":"Händler","effect":"Der Händler zahlt 30 % mehr; Handelsaufträge bringen 20 % mehr Münzen.","job":"","palette":12,"sign":"coin"},
}

const CONTRACTS := [
	{"kind":"getreide","amount":6,"coins":18,"xp":12,"title":"Korn für die Waldküche","level":1},
	{"kind":"bretter","amount":6,"coins":38,"xp":18,"title":"Bretter für den Brückenbauer","level":2},
	{"kind":"brot","amount":6,"coins":58,"xp":22,"title":"Ein Korb für unterwegs","level":3},
	{"kind":"honig","amount":4,"coins":44,"xp":22,"title":"Sonnengold im Glas","level":4},
	{"kind":"marmelade","amount":4,"coins":65,"xp":28,"title":"Süßer Gruß aus Mooswinkel","level":4}
]

const QUESTS := [
	{"title":"Neue Nachbarn", "hint":"Baue ein zweites Wurzelhäuschen.", "kind":"Haus", "goal":2, "coins":35,"xp":45},
	{"title":"Vorräte für alle", "hint":"Lege vier Ackerbeete an.", "kind":"Feld", "goal":4, "coins":40,"xp":50},
	{"title":"Kurze Wege", "hint":"Verbinde das Dorf mit 18 Wegfeldern.", "kind":"Weg", "goal":18, "coins":40,"xp":40},
	{"title":"Nachwachsender Wald", "hint":"Errichte eine Forsthütte.", "kind":"Forsthaus", "goal":1, "coins":45,"xp":45},
	{"title":"Das erste Handwerk", "hint":"Baue eine Sägemühle und eine Kornmühle.", "kind":"Muehle", "goal":1, "extra":"Saegewerk", "coins":70,"xp":70},
	{"title":"Frisches Brot", "hint":"Produziere insgesamt sechs Brote.", "product":"brot", "goal":6, "coins":100,"xp":100},
	{"title":"Unser Dorfplatz", "hint":"Baue einen Brunnen und sechs Blumenbeete.", "kind":"Blumenbeet", "goal":6,"extra":"Brunnen", "coins":100,"xp":100},
	{"title":"Süße Waldbeeren", "hint":"Lege zwei Beerengärten an.", "kind":"Beeren","goal":2,"coins":65,"xp":80},
	{"title":"Summendes Handwerk", "hint":"Baue eine Sonnenimkerei.", "kind":"Imkerei","goal":1,"coins":90,"xp":90},
	{"title":"Ein Glas Sommer", "hint":"Koche insgesamt neun Gläser Marmelade.", "product":"marmelade","goal":9,"coins":120,"xp":120},
	{"title":"Ein offenes Haus", "hint":"Baue das Gasthaus zum Blätterdach.", "kind":"Gasthaus","goal":1,"coins":140,"xp":120},
	{"title":"Platz zum Träumen", "hint":"Erschließe die östliche Waldlichtung.", "expansion":1,"goal":1,"coins":120,"xp":120},
	{"title":"Lichter im Wald", "hint":"Stelle sechs Glühwürmchenlaternen auf.", "kind":"Laterne","goal":6,"coins":150,"xp":140},
	{"title":"Weit über die Lichtung", "hint":"Erschließe auch die südliche Wiese.", "expansion":2,"goal":2,"coins":200,"xp":180}
]

const WILD_TREES := [Vector2i(5,5),Vector2i(6,6),Vector2i(7,4),Vector2i(4,7),Vector2i(6,3),Vector2i(3,6),Vector2i(18,5),Vector2i(19,6),Vector2i(20,4),Vector2i(21,6),Vector2i(19,3),Vector2i(17,4),Vector2i(20,17),Vector2i(21,18),Vector2i(19,18),Vector2i(5,17),Vector2i(2,19),Vector2i(1,12),Vector2i(26,20),Vector2i(27,22),Vector2i(33,4),Vector2i(35,6),Vector2i(37,18),Vector2i(12,27),Vector2i(16,28),Vector2i(30,27)]

const WILD_ROCKS := [Vector2i(22,11),Vector2i(23,12),Vector2i(26,17),Vector2i(4,3),Vector2i(2,5),Vector2i(9,21),Vector2i(34,12),Vector2i(36,9),Vector2i(22,26),Vector2i(8,27)]

## Display groups for the stock overview.
const RESOURCE_GROUPS := [
	["Rohstoffe", ["holz", "stein"]],
	["Ernte", ["getreide", "beeren", "honig", "karotten", "kartoffeln", "kohl", "zwiebeln", "kuerbis", "flachs", "sonnenblumen"]],
	["Fang", ["fisch", "raeucherfisch"]],
	["Tiere", ["eier", "wolle", "milch", "kaese"]],
	["Waren", ["bretter", "mehl", "brot", "marmelade"]],
	["Vorrat", ["nahrung", "muenzen"]],
]

## Seasons: name, growth factor for beds/bushes, tree regrowth factor.
const SEASONS := [
	{"name": "Frühling", "growth": 1.15, "trees": 1.3, "fish": 1.0},
	{"name": "Sommer", "growth": 1.0, "trees": 1.0, "fish": 1.25},
	{"name": "Herbst", "growth": 0.85, "trees": 0.8, "fish": 1.0},
	{"name": "Winter", "growth": 0.35, "trees": 0.3, "fish": 0.55},
]

## Endless village wishes after the introduction quests: templates the
## generator fills in from what the village can actually make.
const WISH_TEXTS := {
	"getreide": "Korn für das Erntefest", "beeren": "Beeren für die Kinderstube",
	"bretter": "Bretter für einen neuen Steg", "mehl": "Mehl für die Wintervorräte",
	"brot": "Brot für die Wanderer", "honig": "Honig gegen den Husten",
	"marmelade": "Marmelade für den Jahrmarkt", "holz": "Holz für das Feuer am Dorfplatz",
	"stein": "Steine für eine Trockenmauer", "nahrung": "Vorräte für lange Abende",
	"karotten": "Karotten für die Hasenfreunde", "kartoffeln": "Kartoffeln für das Feuerfest", "kohl": "Kohl für die Wintersuppe",
	"zwiebeln": "Zwiebeln für die Waldküche", "kuerbis": "Kürbisse für die Herbstlaternen", "flachs": "Flachs für neue Leinen",
	"sonnenblumen": "Sonnenblumen für den Dorfplatz", "fisch": "Frischer Fisch für das Gasthaus", "raeucherfisch": "Räucherfisch für die Reise",
	"eier": "Eier für den Frühlingskuchen", "wolle": "Wolle für warme Mützen", "milch": "Milch für die Kleinsten", "kaese": "Käse für das Picknick",
}
## Crops for the field beds: grow time (s), harvest, seed cost, unlock
## level, harvest animation ("reap" = sickle, "dig" = kneel and pull).
const CROPS := {
	"korn": {"label": "Korn", "duration": 24.0, "harvest": {"getreide": 6, "nahrung": 2, "muenzen": 3}, "seed": 0, "level": 1, "anim": "reap", "color": Color("e7c169")},
	"karotten": {"label": "Karotten", "duration": 36.0, "harvest": {"karotten": 5, "nahrung": 3}, "seed": 2, "level": 2, "anim": "dig", "color": Color("e98a2e")},
	"kohl": {"label": "Kohl", "duration": 48.0, "harvest": {"kohl": 4, "nahrung": 4}, "seed": 3, "level": 3, "anim": "reap", "color": Color("8fb38a")},
	"kartoffeln": {"label": "Kartoffeln", "duration": 56.0, "harvest": {"kartoffeln": 6, "nahrung": 5}, "seed": 3, "level": 3, "anim": "dig", "color": Color("c9a46a")},
	"zwiebeln": {"label": "Zwiebeln", "duration": 32.0, "harvest": {"zwiebeln": 5, "nahrung": 2}, "seed": 2, "level": 4, "anim": "dig", "color": Color("d9a35a")},
	"kuerbis": {"label": "Kürbisse", "duration": 84.0, "harvest": {"kuerbis": 3, "nahrung": 5, "muenzen": 6}, "seed": 5, "level": 5, "anim": "dig", "color": Color("e5782a")},
	"flachs": {"label": "Flachs", "duration": 44.0, "harvest": {"flachs": 5}, "seed": 3, "level": 6, "anim": "reap", "color": Color("7f9fd8")},
	"sonnenblumen": {"label": "Sonnenblumen", "duration": 66.0, "harvest": {"sonnenblumen": 4, "muenzen": 4}, "seed": 4, "level": 6, "anim": "reap", "color": Color("f2c330")},
}

## Unit prices of the travelling merchant.
const PRICES := {"kaese": 9, "wolle": 4, "eier": 3, "milch": 3, "marmelade": 10, "raeucherfisch": 7, "honig": 6, "kuerbis": 5, "brot": 8, "bretter": 4, "mehl": 4, "kohl": 3, "flachs": 3, "sonnenblumen": 3, "fisch": 3, "beeren": 3, "karotten": 2, "kartoffeln": 2, "zwiebeln": 2, "getreide": 2, "holz": 1, "stein": 1}

const WISH_BUILD := ["Huehnerhof", "Haus", "Feld", "Beeren", "Laterne", "Blumenbeet", "Bank", "Brunnen", "Strauch", "Wildbaum", "Lager"]
