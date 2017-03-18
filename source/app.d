module app;

import avocado.assimp;
import avocado.bmfont;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import components;
import systems.display;
import systems.logic;
import trackgen;
import particles;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Mesh = GL3MeshIndexPositionTextureNormal;
alias Font = BMFont!(Texture, ResourceManager);

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

void main()
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View("Fluffy");
		auto renderer = new Renderer;
		window.setOpenGLVersion(3, 3);
		auto world = add(window, renderer);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
		}

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		auto defaultFrag = new ShaderUnit(ShaderType.Fragment,
				resources.load!TextProvider("shaders/default.frag").value);
		auto defaultVert = new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/default.vert").value);
		auto textureFrag = new ShaderUnit(ShaderType.Fragment,
				resources.load!TextProvider("shaders/texture.frag").value);
		auto skyboxVert = new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/skybox.vert").value);
		auto particleFrag = new ShaderUnit(ShaderType.Fragment,
				resources.load!TextProvider("shaders/particle.frag").value);
		auto particleVert = new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/particle.vert").value);
		auto textVert = new ShaderUnit(ShaderType.Vertex,
				resources.load!TextProvider("shaders/text.vert").value);

		auto shader = new Shader();
		shader.attach(defaultFrag);
		shader.attach(defaultVert);
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		auto particleShader = new Shader();
		particleShader.attach(particleFrag);
		particleShader.attach(particleVert);
		particleShader.create(renderer);
		particleShader.register(["modelview", "projection", "orientation", "tex0", "tex1"]);
		particleShader.set("tex0", 0);
		particleShader.set("tex1", 1);

		renderer.setupDepthTest(DepthFunc.Less);

		Shader textShader = new Shader(renderer, textVert, textureFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!LogicSystem(renderer, window);
		world.addSystem!DisplaySystem(renderer, window, new ParticleSystem!(2048)(particleShader,
				[resources.load!Texture("textures/smoke.png"),
				resources.load!Texture("textures/plasma.png")]), font, textShader);

		{
			auto skyboxShader = new Shader();
			skyboxShader.attach(textureFrag);
			skyboxShader.attach(skyboxVert);
			skyboxShader.create(renderer);
			skyboxShader.register(["modelview", "projection", "tex"]);
			skyboxShader.set("tex", 0);
			auto skyTex = resources.load!Texture("textures/skybox.png");
			mixin(createEntity!("Skybox", q{
				Skybox: skyboxShader, skyTex
			}));
		}

		Texture street = resources.load!Texture("textures/street.png");
		street.wrapX = TextureClampMode.ClampToEdge;
		street.wrapY = TextureClampMode.ClampToEdge;
		street.applyParameters();
		Texture border = resources.load!Texture("textures/border.png");
		border.wrapX = TextureClampMode.Mirror;
		border.wrapY = TextureClampMode.Mirror;
		border.applyParameters();
		auto vehicle1 = resources.load!Texture("textures/vehicle1.png");
		auto track = generateTrack;
		mixin(createEntity!("Track", q{
			EntityDisplay: track.roadMesh, shader, street, mat4.identity
			Transformation: mat4.translation(0, 0, 0)
			TrackCollision: track.outerRing, track.innerRing, track.widths
		}));
		mixin(createEntity!("TrackL", q{
			EntityDisplay: track.innerRingMesh, shader, border, mat4.identity
			Transformation: mat4.translation(0, 0, 0)
		}));
		mixin(createEntity!("TrackR", q{
			EntityDisplay: track.outerRingMesh, shader, border, mat4.identity
			Transformation: mat4.translation(0, 0, 0)
		}));
		{
			auto mesh = resources.load!Scene("models/vehicle1.obj").value.meshes[0].convertAssimpMesh;
			mixin(createEntity!("Player", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				PlayerControls: Key.Up, Key.Left, Key.Down, Key.Right, Key.RShift
				VehiclePhysics: (track.innerRing[0] + track.outerRing[0]) * 0.5f
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: (track.innerRing[1] + track.outerRing[1]) * 0.5f
				VehicleAI:
				ParticleSpawner:
			}));
		}

		FPSLimiter limiter = new FPSLimiter(120);

		start();
		while (update)
			limiter.wait();
		stop();
	}
}
