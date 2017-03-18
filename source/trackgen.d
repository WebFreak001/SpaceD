module trackgen;

import avocado.core;
import avocado.gl3;

import app;
import std.random;

struct Track
{
	vec2[] outerRing, innerRing;
	Mesh roadMesh;
	Mesh outerRingMesh, innerRingMesh;
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
	enum RoadWidth = 50;
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
	track.innerRing.reserve(trackPath.length);
	track.outerRing.reserve(trackPath.length);
	with (track)
	{
		roadMesh = new Mesh();
		roadMesh.primitiveType = PrimitiveType.TriangleStrip;
		innerRingMesh = new Mesh();
		innerRingMesh.primitiveType = PrimitiveType.TriangleStrip;
		outerRingMesh = new Mesh();
		outerRingMesh.primitiveType = PrimitiveType.TriangleStrip;
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
		// generate mesh data
		foreach (i, pos; trackPath)
		{
			vec2 prev = trackPath[(i + $ - 1) % $];
			vec2 next = trackPath[(i + 1) % $];

			vec2 dirA = (prev - pos).normalized;
			vec2 dirB = (pos - next).normalized;

			vec2 avgDir = (dirA + dirB).normalized;
			vec2 ortho = vec2(-avgDir.y, avgDir.x);

			float uvX = (i % 2) == 0 ? 1 : 0;

			vec2 inPos = pos * Scale;
			vec2 outPos = pos * Scale - ortho * RoadWidth * widthMuls[i];

			track.innerRing ~= inPos;
			track.outerRing ~= outPos;

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
	return track;
}
