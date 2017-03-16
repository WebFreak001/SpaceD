module components;

import app;

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
	Key accelerate, steerLeft, decelerate, steerRight;

	mixin ComponentBase;
}

struct VehiclePhysics
{
	vec2 linearVelocity = vec2(0, 0);
	vec2 position = vec2(0, 0);
	float angularVelocity = 0;
	float rotation = 0;

	mixin ComponentBase;
}
