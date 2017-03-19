module components;

import avocado.core;
import avocado.sdl2;

import app;
import particles;
import scenemanager;

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
	Key accelerate, steerLeft, decelerate, steerRight, boost, lookBack;

	mixin ComponentBase;
}

struct VehicleAI
{
	vec2 nextWaypoint;
	size_t trackIndex = 0;

	mixin ComponentBase;
}

struct VehiclePhysics
{
	this(vec2 position, float rotation)
	{
		this.position = startPosition = position;
		this.rotation = rotation;
	}

	vec2 position = vec2(0, 0);
	float rotation = 0;
	vec2 linearVelocity = vec2(0, 0);
	float angularVelocity = 0;
	float cameraRotation = 0;
	bool reversing = false;
	int currentCheckpoint = 0;
	int numCheckpoints = 0;
	ubyte place = 0;
	int lastCheck = -1;
	bool player = false;
	vec2 startPosition;

	mixin ComponentBase;

	/// Returns: [tl, tr, bl, br, exL, exR, exL2, exR2]
	vec2[8] generateCornersAndExhaust()
	{
		enum HalfFWidth = 1;
		enum HalfWidth = 2;
		enum HExWidth = 1.5f;
		enum HExWidth2 = 1.1f;
		enum HalfHeight = 3.8f;
		auto s = sin(rotation);
		auto c = cos(rotation);
		vec2 tl = vec2(-HalfWidth * c - HalfHeight * s, -HalfWidth * s + HalfHeight * c) + position;
		vec2 tr = vec2(HalfWidth * c - HalfHeight * s, HalfWidth * s + HalfHeight * c) + position;
		vec2 bl = vec2(-HalfFWidth * c + HalfHeight * s, -HalfFWidth * s - HalfHeight * c) + position;
		vec2 br = vec2(HalfFWidth * c + HalfHeight * s, HalfFWidth * s - HalfHeight * c) + position;
		vec2 exL = vec2(-HExWidth * c - HalfHeight * s, -HExWidth * s + HalfHeight * c) + position;
		vec2 exR = vec2(HExWidth * c - HalfHeight * s, HExWidth * s + HalfHeight * c) + position;
		vec2 exL2 = vec2(-HExWidth2 * c - HalfHeight * s, -HExWidth2 * s + HalfHeight * c) + position;
		vec2 exR2 = vec2(HExWidth2 * c - HalfHeight * s, HExWidth2 * s + HalfHeight * c) + position;
		return [tl, tr, bl, br, exL, exR, exL2, exR2];
	}
}

struct TrackCollision
{
	vec2[] outerRing;
	vec2[] innerRing;
	float[] widths;

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

struct Skybox
{
	Shader shader;
	Texture texture;

	mixin ComponentBase;
}

struct RaceInfo
{
	float time = -3;

	mixin ComponentBase;
}

enum Align : ubyte
{
	TopLeft,
	BottomLeft,
	TopRight,
	BottomRight
}

struct Button
{
	dstring text;
	vec4 bg, fg;
	vec4 rect;
	Align alignment;

	mixin ComponentBase;
}

struct GUIRectangle
{
	Texture texture;
	vec4 rect;
	Align alignment;

	mixin ComponentBase;
}

struct GUIColorRectangle
{
	vec4 color;
	vec4 rect;
	Align alignment;

	mixin ComponentBase;
}

enum TextAlign : ubyte
{
	Left,
	Center,
	Right
}

struct GUIText
{
	dstring text;
	vec2 pos, scale;
	vec4 fg = vec4(1);
	Align alignment;
	TextAlign textAlign;

	mixin ComponentBase;
}

struct GUI3D
{
	mat4 projection, modelview;
	Mesh mesh;
	Shader shader;
	Texture texture;
	float time = 0;

	mixin ComponentBase;
}

struct TabFocus
{
	uint index;

	mixin ComponentBase;
}

struct SceneSwitchAction
{
	string scene;

	mixin ComponentBase;
}

struct BuyAction
{
	int upgradeIndex;

	mixin ComponentBase;
}
