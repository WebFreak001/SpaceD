module trackgen;

import avocado.core;
import avocado.gl3;

import app;
import std.random;
import std.bitmanip;

import gl3n.math;
import gl3n.linalg;

enum RoadWidth = 50;

struct Track
{
	vec2[] outerRing, innerRing;
	float[] widths;
	Mesh roadMesh;
	Mesh outerRingMesh, innerRingMesh;
	string name;
	bool isRandom;
	ubyte[16] id;
	bool toDownload;

	void generateOuterAndMeshes()
	{
		if (outerRing.length == innerRing.length)
			return;
		outerRing.reserve(innerRing.length);
		roadMesh = new Mesh();
		roadMesh.primitiveType = PrimitiveType.TriangleStrip;
		innerRingMesh = new Mesh();
		innerRingMesh.primitiveType = PrimitiveType.TriangleStrip;
		outerRingMesh = new Mesh();
		outerRingMesh.primitiveType = PrimitiveType.TriangleStrip;
		// generate mesh data
		foreach (i, inPos; innerRing)
		{
			vec2 prev = innerRing[(i + $ - 1) % $];
			vec2 next = innerRing[(i + 1) % $];

			vec2 dirA = (prev - inPos).normalized;
			vec2 dirB = (inPos - next).normalized;

			vec2 avgDir = (dirA + dirB).normalized;
			vec2 ortho = vec2(-avgDir.y, avgDir.x);

			float uvX = (i % 2) == 0 ? 1 : 0;

			vec2 outPos = inPos - ortho * RoadWidth * widths[i];

			outerRing ~= outPos;

			roadMesh.addIndex(cast(int) i * 2);
			roadMesh.addPosition(vec3(inPos.x, 0, inPos.y));
			roadMesh.addTexCoord(vec2(uvX, 0));
			roadMesh.addNormal(vec3(0, 1, 0));

			roadMesh.addIndex(cast(int) i * 2 + 1);
			roadMesh.addPosition(vec3(outPos.x, 0, outPos.y));
			roadMesh.addTexCoord(vec2(uvX, 1));
			roadMesh.addNormal(vec3(0, 1, 0));

			innerRingMesh.addIndex(cast(int) i * 2);
			innerRingMesh.addPosition(vec3(inPos.x, 0, inPos.y));
			innerRingMesh.addTexCoord(vec2(uvX * 8, 1));
			innerRingMesh.addNormal(vec3(0, 1, 0));

			innerRingMesh.addIndex(cast(int) i * 2 + 1);
			innerRingMesh.addPosition(vec3(inPos.x, 2, inPos.y));
			innerRingMesh.addTexCoord(vec2(uvX * 8, 0));
			innerRingMesh.addNormal(vec3(0, 1, 0));

			outerRingMesh.addIndex(cast(int) i * 2);
			outerRingMesh.addPosition(vec3(outPos.x, 0, outPos.y));
			outerRingMesh.addTexCoord(vec2(uvX * 8, 1));
			outerRingMesh.addNormal(vec3(0, 1, 0));

			outerRingMesh.addIndex(cast(int) i * 2 + 1);
			outerRingMesh.addPosition(vec3(outPos.x, 2, outPos.y));
			outerRingMesh.addTexCoord(vec2(uvX * 8, 0));
			outerRingMesh.addNormal(vec3(0, 1, 0));
		}
		roadMesh.addIndex(0);
		roadMesh.addIndex(1);
		roadMesh.generate();
		innerRingMesh.addIndex(0);
		innerRingMesh.addIndex(1);
		innerRingMesh.generate();
		outerRingMesh.addIndex(0);
		outerRingMesh.addIndex(1);
		outerRingMesh.generate();
	}

	float startRotation1()
	{
		vec2 a = innerRing[0] - innerRing[1];
		return atan2(a.y, a.x) - PI * 0.5f;
	}

	float startRotation2()
	{
		vec2 a = innerRing[$ - 1] - innerRing[0];
		return atan2(a.y, a.x) - PI * 0.5f;
	}
}

T smooth(T, size_t l)(T[l] arr, size_t i, int n)
{
	T sum = arr[i];
	for (int it = 1; it <= n; it++)
		sum += arr[(i + it) % l] + arr[(i + l - it) % l];
	return sum / cast(float)(n * 2 + 1);
}

Track generateTrack()
{
	enum Scale = 400;

	vec2[96] trackPath;
	float[96] widthMuls;
	widthMuls[] = 1;
	// generate circle
	foreach (i, ref vec; trackPath)
	{
		float n = i / cast(float) trackPath.length * 3.1415926f * 2;
		vec = vec2(sin(n), cos(n));
	}
	// randomly resize circle & smooth circle (multiple times)
	for (int it = 1; it < 10; it++)
	{
		float n = 1.0f / cast(float) it;
		foreach (ref vec; trackPath)
			vec *= uniform(1 - n, 1.1f + n);
		foreach (i, ref vec; trackPath)
			vec = trackPath.smooth(i, 2);
	}
	// final smoothing
	foreach (i, ref vec; trackPath)
		vec = trackPath.smooth(i, 2);
	Track track;
	track.name = "Randomly Generated Map";
	track.isRandom = true;
	track.innerRing.reserve(trackPath.length);
	with (track)
	{
		// generate road width multipliers (wider on curves, more narrow on straight paths)
		foreach (i, pos; trackPath)
		{
			vec2 prev = trackPath[(i + $ - 1) % $];
			vec2 next = trackPath[(i + 1) % $];

			vec2 dirA = (prev - pos).normalized;
			vec2 dirB = (pos - next).normalized;

			float mul = (dirA - dirB).length * 7 + 0.3f;
			if (mul < 0.7f)
				mul = 0.7f;
			if (mul > 3)
				mul = 3;
			widthMuls[i] = mul;
		}
		// smooth width multipliers
		foreach (i, ref mul; widthMuls)
			mul = widthMuls.smooth(i, 8);
		widths = widthMuls[].dup;
		// generate mesh data
		foreach (i, pos; trackPath)
			track.innerRing ~= pos * Scale;
	}
	track.generateOuterAndMeshes();
	return track;
}

/// Track File Format:
/// ubyte name length (in bytes)
/// name (utf8 encoded)
/// 0xFF (extended header)
/// 0x01 (version)
/// ubyte[16] uuid // extended header end
/// uint numParts
/// (float,float,float)[] (x,y,width)
Track trackFromMemory(ubyte[] mem)
{
	Track ret;
	ret.name = cast(string) mem[1 .. 1 + mem[0]];
	size_t index = 1 + mem[0];
	uint numParts;
	if (mem[index] == 0xFF)
	{
		ubyte ver = mem[++index];
		if (ver != 1)
			throw new Exception("Unsupported Track Version");
		index++;
		ret.id = mem[index .. index + 16][0 .. 16];
		index += 16;
	}
	numParts = mem.peek!uint(&index);
	if (mem.length != index + numParts * 12)
		throw new Exception("Invalid Track");
	ret.innerRing.reserve(numParts);
	ret.widths.reserve(numParts);
	for (uint i = 0; i < numParts; i++)
	{
		float x = mem.peek!float(&index);
		float y = mem.peek!float(&index);
		float width = mem.peek!float(&index);
		ret.innerRing ~= vec2(x, y);
		ret.widths ~= width;
	}
	return ret;
}

ubyte[] trackToMemory(Track track)
{
	import std.uuid;

	ubyte[] data;
	data ~= cast(ubyte) track.name.length;
	data ~= cast(ubyte[]) track.name;
	data ~= 0xFF; // Extended Header
	data ~= 0x01; // Version
	data ~= track.id;
	data ~= (cast(uint) track.innerRing.length).nativeToBigEndian;
	foreach (i, ref v; track.innerRing)
	{
		data ~= v.x.nativeToBigEndian;
		data ~= v.y.nativeToBigEndian;
		data ~= track.widths[i].nativeToBigEndian;
	}
	return data;
}
