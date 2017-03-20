module api;

struct PublicMap
{
	string id, name, uploader, uploadedAt, lastEdit;
}

interface MapProvider
{
	PublicMap[] getMaps(int page = 0);
	string postMaps(string mapid, string name, string uploader,
			float[3][] controlPoints, string token = "");
}