module components;

import app;
import particles;

import avocado.core;
import avocado.sdl2;

struct Transformation
{
	mat4 transform;
	bool netSync = false;

	mixin ComponentBase;
}

struct EntityDisplay
{
	Mesh mesh;
	Shader shader;
	Texture texture;
	mat4 matrix;

	mixin ComponentBase;
}

struct PlayerControls
{
	Key accelerate, steerLeft, decelerate, steerRight, boost;

	mixin ComponentBase;
}

struct VehiclePhysics
{
	vec2 position = vec2(0, 0);
	float rotation = 0;
	vec2 linearVelocity = vec2(0, 0);
	float angularVelocity = 0;
	float cameraRotation = 0;
	bool reversing = false;

	mixin ComponentBase;
}

struct TrackCollision
{
	vec2[] outerRing;
	vec2[] innerRing;

	mixin ComponentBase;
}

struct ParticleSpawner
{
	struct Data
	{
		vec3 pos;
		uint tex;
		ParticleInfo info;
	}
	Data[] toSpawn;
	float time = 0;

	mixin ComponentBase;
}