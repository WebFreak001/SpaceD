module trackgen;

import avocado.core;
import avocado.gl3;

import app;
import std.random;

struct Track
{
	vec2[] outerRing, innerRing;
	Mesh mesh;
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
	enum RoadWidth = 30;
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
		mesh = new Mesh();
		mesh.primitiveType = PrimitiveType.TriangleStrip;
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
			std.stdio.writeln(mul);
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

			mesh.addIndex(cast(int) i * 2);
			mesh.addPosition(vec3(pos.x * Scale, 0, pos.y * Scale));
			track.innerRing ~= pos;
			mesh.addTexCoord(vec2(uvX, 0));
			mesh.addNormal(vec3(0, 1, 0));

			mesh.addIndex(cast(int) i * 2 + 1);
			mesh.addPosition(vec3(pos.x * Scale + ortho.x * RoadWidth * widthMuls[i], 0,
					pos.y * Scale + ortho.y * RoadWidth * widthMuls[i]));
			track.outerRing ~= pos * Scale + ortho * widthMuls[i];
			mesh.addTexCoord(vec2(uvX, 1));
			mesh.addNormal(vec3(0, 1, 0));
		}
		mesh.addIndex(0);
		mesh.addIndex(1);
		mesh.generate();
	}
	return track;
}
