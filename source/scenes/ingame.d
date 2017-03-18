module scenes.ingame;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import app;
import components;
import particles;
import scenemanager;
import shaderpool;
import systems.display;
import systems.logic;
import trackgen;

class IngameScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto defaultFrag = shaders.load(ShaderType.Fragment, "shaders/default.frag");
		auto defaultVert = shaders.load(ShaderType.Vertex, "shaders/default.vert");
		auto skyboxVert = shaders.load(ShaderType.Vertex, "shaders/skybox.vert");
		auto particleFrag = shaders.load(ShaderType.Fragment, "shaders/particle.frag");
		auto particleVert = shaders.load(ShaderType.Vertex, "shaders/particle.vert");
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");

		auto particleShader = new Shader();
		particleShader.attach(particleFrag);
		particleShader.attach(particleVert);
		particleShader.create(renderer);
		particleShader.register(["modelview", "projection", "orientation", "tex0", "tex1"]);
		particleShader.set("tex0", 0);
		particleShader.set("tex1", 1);

		Shader textShader = new Shader(renderer, textVert, textureFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!LogicSystem(renderer, window);
		world.addSystem!DisplaySystem(renderer, window, new ParticleSystem!(2048)(particleShader,
				[resources.load!Texture("textures/smoke.png"),
				resources.load!Texture("textures/plasma.png")]), font, textShader,
				resources, sceneManager);

		auto shader = new Shader();
		shader.attach(defaultFrag);
		shader.attach(defaultVert);
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		mixin(createEntity!("RaceInfo Entity", q{
			RaceInfo:
		}));

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
		Texture poleTex = resources.load!Texture("textures/pole.png");
		auto poleMesh = resources.load!Scene("models/pole.obj").value.meshes[0].convertAssimpMesh;
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
		mixin(createEntity!("Start Pole Left", q{
			EntityDisplay: poleMesh, shader, poleTex, mat4.identity
			Transformation: mat4.translation(track.innerRing[0].x, 5, track.innerRing[0].y)
		}));
		mixin(createEntity!("Start Pole Right", q{
			EntityDisplay: poleMesh, shader, poleTex, mat4.identity
			Transformation: mat4.translation(track.outerRing[0].x, 5, track.outerRing[0].y)
		}));
		{
			auto mesh = resources.load!Scene("models/vehicle1.obj").value.meshes[0].convertAssimpMesh;
			mixin(createEntity!("Bot 1", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.2f + track.outerRing[$ - 1] * 0.8f, PI * 0.5f
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Player", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				PlayerControls: Key.Up, Key.Left, Key.Down, Key.Right, Key.RShift, Key.RCtrl
				VehiclePhysics: track.innerRing[0] * 0.4f + track.outerRing[0] * 0.6f, PI * 0.5f
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 1", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.6f + track.outerRing[$ - 1] * 0.4f, PI * 0.5f
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 1", q{
				EntityDisplay: mesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[0] * 0.8f + track.outerRing[0] * 0.2f, PI * 0.5f
				VehicleAI:
				ParticleSpawner:
			}));
		}
	}

	override void preEnter(IScene prev)
	{
	}

	override void postExit(IScene next)
	{
	}
}
