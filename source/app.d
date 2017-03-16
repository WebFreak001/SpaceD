module app;

import avocado.core;
import avocado.dfs;
import avocado.assimp;
import avocado.gl3;
import avocado.sdl2;

import components;
import systems.display;
import systems.logic;
import std.random;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Mesh = GL3MeshIndexPositionTextureNormal;

Mesh convertAssimpMesh(AssimpMeshData from)
{
	auto mesh = new GL3MeshIndexPositionTextureNormal();
	mesh.primitiveType = PrimitiveType.Triangles;
	foreach (indices; from.indices)
		mesh.addIndexArray(indices);
	mesh.addPositionArray(from.vertices);
	if (from.texCoords.length)
	{
		foreach (texCoord; from.texCoords[0])
			mesh.addTexCoord(texCoord.xy);
	}
	else
	{
		foreach (vertex; from.vertices)
			mesh.addTexCoord(vertex.xy);
	}
	mesh.addNormalArray(from.normals);
	mesh.generate();
	return mesh;
}

Mesh generateTrack()
{
	enum RoadWidth = 30;
	enum Scale = 400;

	vec2[48] track;
	float[48] widthMuls;
	widthMuls[] = 1;
	// generate circle
	foreach (i, ref vec; track)
	{
		float n = i / cast(float) track.length * 3.1415926f * 2;
		vec = vec2(sin(n), cos(n));
	}
	for (int it = 1; it < 10; it++)
	{
		float n = 1.0f / cast(float) it;
		foreach (ref vec; track)
			vec *= uniform(1 - n, 1.1f + n);
		foreach (i, ref vec; track)
			vec = track[(i + $ - 2) % $] * 0.1f + track[(
					i + $ - 1) % $] * 0.2f + vec * 0.4f + track[(i + 1) % $] * 0.2f + track[(i + 2) % $]
				* 0.1f;
	}
	auto mesh = new GL3MeshIndexPositionTextureNormal();
	mesh.primitiveType = PrimitiveType.TriangleStrip;
	foreach (i, pos; track)
	{
		vec2 prev = track[(i + $ - 1) % $];
		vec2 next = track[(i + 1) % $];

		vec2 dirA = (prev - pos).normalized;
		vec2 dirB = (pos - next).normalized;

		float mul = (dirA - dirB).length_squared * 8;
		if (mul < 1)
			mul = 1;
		if (mul > 3)
			mul = 3;
		widthMuls[i] = mul;
	}
	foreach (i, ref mul; widthMuls)
		mul = widthMuls[(i + $ - 2) % $] * 0.1f + widthMuls[(i + $ - 1) % $] * 0.2f + mul
			* 0.4f + widthMuls[(i + 1) % $] * 0.2f + widthMuls[(i + 2) % $] * 0.1f;
	foreach (i, pos; track)
	{
		vec2 prev = track[(i + $ - 1) % $];
		vec2 next = track[(i + 1) % $];

		vec2 dirA = (prev - pos).normalized;
		vec2 dirB = (pos - next).normalized;

		vec2 avgDir = (dirA + dirB).normalized;
		vec2 ortho = vec2(-avgDir.y, avgDir.x);

		mesh.addIndex(cast(int) i * 2);
		mesh.addPosition(vec3(pos.x * Scale, 0, pos.y * Scale));
		mesh.addTexCoord(pos);
		mesh.addNormal(vec3(0, 1, 0));

		mesh.addIndex(cast(int) i * 2 + 1);
		mesh.addPosition(vec3(pos.x * Scale + ortho.x * RoadWidth * widthMuls[i], 0,
				pos.y * Scale + ortho.y * RoadWidth * widthMuls[i]));
		mesh.addTexCoord(pos);
		mesh.addNormal(vec3(0, 1, 0));
	}
	mesh.addIndex(0);
	mesh.addIndex(1);
	mesh.generate();
	return mesh;
}

void main()
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View("Fluffy");
		auto renderer = new Renderer;
		auto world = add(window, renderer);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
			renderer.projection.top = perspective(width, height, 90.0f, 10.0f, 1000.0f);
		}

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		auto shader = new Shader();
		shader.attach(new ShaderUnit(ShaderType.Fragment,
				resources.load!TextProvider("shaders/default.frag").value));
		shader.attach(new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/default.vert").value));
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		renderer.setupDepthTest(DepthFunc.Less);

		world.addSystem!LogicSystem(renderer);
		world.addSystem!DisplaySystem(renderer, window);

		auto wood = resources.load!Texture("textures/test.png");
		{
			auto mesh = resources.load!Scene("models/test.obj").value.meshes[0].convertAssimpMesh;
			mixin(createEntity!("Player", q{
				EntityDisplay: mesh, shader, wood, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				PlayerControls: Key.Up, Key.Left, Key.Down, Key.Right
				VehiclePhysics:
			}));
		}
		{
			auto mesh = generateTrack;
			mixin(createEntity!("Track", q{
				EntityDisplay: mesh, shader, wood, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
			}));
		}

		FPSLimiter limiter = new FPSLimiter(120);

		start();
		while (update)
			limiter.wait();
		stop();
	}
}
