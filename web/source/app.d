import std.algorithm;
import std.bitmanip;
import std.file;
import std.path;
import std.uuid;

import vibe.d;

import mongoschema;
import std.math;

enum newUUID = cast(BsonBinData.Type) 0x04;

struct Map
{
	@binaryType(newUUID) immutable(ubyte)[] mapID;
	@binaryType(newUUID) immutable(ubyte)[] editToken;
	string name;
	string path;

	mixin MongoSchema;
}

__gshared float spam = 0;
__gshared UUID[10] last10Maps;
__gshared ubyte last10MapsIndex;

shared static this()
{
	auto client = connectMongoDB("localhost");
	auto db = client.getDatabase("spaced");
	db["maps"].register!Map;

	if (!exists("uploads"))
		mkdir("uploads");

	setTimer(1.minutes, {
		spam -= 0.1f;
		if (spam < 0)
			spam = 0;
	}, true);

	auto settings = new HTTPServerSettings;
	settings.port = 3000;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	auto router = new URLRouter;
	router.get("/maps/:id", &getMap);
	registerRestInterface(router, new MapInterface());
	listenHTTP(settings, router);
}

interface MapProvider
{
	PublicMap[] getMaps(int page = 0);
	string postMaps(string mapid, string name, float[3][] controlPoints, string token = "");
}

class MapInterface : MapProvider
{
	PublicMap[] getMaps(int page = 0)
	{
		enforceBadRequest(page >= 0 && page < 1_000_000);
		PublicMap[] maps;
		foreach (map; Map.findAll().skip(page * 100).limit(100))
			maps ~= map.getPublic;
		return maps;
	}

	string postMaps(string mapid, string name, float[3][] controlPoints, string token = "")
	{
		enforceHTTP(spam < 10, HTTPStatus.serviceUnavailable,
				"Maps cannot be uploaded right now, please try again later");
		spam += 0.1f;
		enforceBadRequest(controlPoints.length >= 3, "Insufficient Map Data");
		enforceBadRequest(mapid.length == 36, "Invalid UUID");
		enforceBadRequest(name.length > 0 && name.length <= 255, "Invalid Name");
		UUID uuid, editToken;
		try
		{
			uuid = UUID(mapid);
			if (token.length)
				editToken = UUID(token);
		}
		catch (UUIDParsingException)
		{
			enforceBadRequest(false, "Invalid UUID");
		}
		foreach (map; last10Maps)
			if (map == uuid)
				spam += 0.5f;
		last10Maps[last10MapsIndex] = uuid;
		last10MapsIndex = (last10MapsIndex + 1) % last10Maps.length;
		enforceBadRequest(!uuid.empty, "Reserved UUID");
		enforceHTTP(uuid.data.length == 16, HTTPStatus.internalServerError);
		auto existing = Map.tryFindOne(["mapID" : Bson(BsonBinData(newUUID, uuid.data[].idup))]);
		Map map;
		if (!existing.isNull)
		{
			enforceBadRequest(existing.editToken[0 .. 16] == editToken.data, "Map already exists");
			map.bsonID = existing.bsonID;
		}
		map.mapID = uuid.data[].idup;
		map.name = name;
		editToken = randomUUID;
		map.editToken = editToken.data[].idup;
		ubyte[] mapContent;
		mapContent ~= cast(ubyte) name.length;
		mapContent ~= cast(ubyte[]) name;
		mapContent ~= 0xFF;
		mapContent ~= 0x01;
		mapContent ~= uuid.data;
		mapContent ~= (cast(uint) controlPoints.length).nativeToBigEndian;
		foreach (ctrl; controlPoints)
		{
			enforceBadRequest(ctrl[0].isFinite && ctrl[1].isFinite && ctrl[2].isFinite);
			mapContent ~= ctrl[0].nativeToBigEndian;
			mapContent ~= ctrl[1].nativeToBigEndian;
			mapContent ~= ctrl[2].nativeToBigEndian;
		}
		writeFile(buildPath("uploads", uuid.toString ~ ".map"), mapContent);
		map.save();
		return editToken.toString;
	}
}

bool isFinite(float n)
{
	return !isNaN(n) && n != float.infinity && n != -float.infinity;
}

void getMap(HTTPServerRequest req, HTTPServerResponse res)
{
	string id = req.params["id"];
	enforceHTTP(spam < 10, HTTPStatus.serviceUnavailable,
			"Maps cannot be downloaded right now, please try again later");
	spam += 0.005f;
	auto uuid = UUID(id);
	auto existing = Map.tryFindOne(["mapID" : Bson(BsonBinData(newUUID, uuid.data[].idup))]);
	enforceHTTP(!existing.isNull, HTTPStatus.notFound, "Map does not exist");
	res.headers["Content-Type"] = "application/octet-stream";
	res.headers["Content-Disposition"] = "attachment; filename=\"" ~ uuid.toString ~ ".map\"";
	sendFile(req, res, Path("uploads") ~ Path(uuid.toString ~ ".map"));
}

struct PublicMap
{
	string id, name;
}

PublicMap getPublic(Map map)
{
	return PublicMap(UUID(map.mapID[0 .. 16]).toString, map.name);
}
