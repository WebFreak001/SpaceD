module scenes.ingame;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import std.algorithm;
import std.random;

import app;
import components;
import globstate;
import particles;
import scenemanager;
import shaderpool;
import scenes.mapselect;
import scenes.mapedit;
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
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");
		auto skyboxFrag = shaders.load(ShaderType.Fragment, "shaders/skybox.frag");

		auto particleShader = new Shader();
		particleShader.attach(particleFrag);
		particleShader.attach(particleVert);
		particleShader.create(renderer);
		particleShader.register(["modelview", "projection", "orientation", "tex0", "tex1"]);
		particleShader.set("tex0", 0);
		particleShader.set("tex1", 1);

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		particles = new ParticleSystem!(8192)(particleShader,
				[resources.load!Texture("textures/smoke.png"),
				resources.load!Texture("textures/plasma.png")]);

		world.addSystem!LogicSystem(renderer, window);
		world.addSystem!DisplaySystem(renderer, window, particles, font,
				textShader, resources, sceneManager);

		shader = new Shader();
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
			skyboxShader.attach(skyboxFrag);
			skyboxShader.attach(skyboxVert);
			skyboxShader.create(renderer);
			skyboxShader.register(["modelview", "projection", "tex"]);
			skyboxShader.set("tex", 0);
			//dfmt off
			auto skyTex = Texture.createCubemap(
				resources.load!BitmapProvider("textures/skybox_right.png").value,
				resources.load!BitmapProvider("textures/skybox_left.png").value,
				resources.load!BitmapProvider("textures/skybox_top.png").value,
				resources.load!BitmapProvider("textures/skybox_bottom.png").value,
				resources.load!BitmapProvider("textures/skybox_front.png").value,
				resources.load!BitmapProvider("textures/skybox_back.png").value
			);
			//dfmt on
			mixin(createEntity!("Skybox", q{
				Skybox: skyboxShader, skyTex
			}));
		}
		{
			auto meteoriteTex = resources.load!Texture("textures/meteorite_ao.png");
			auto meteorite = resources.load!Scene("models/meteorite.obj")
				.value.meshes[0].convertAssimpMesh;
			for (int i = 0; i < 50; i++)
				mixin(createEntity!("Meteorite", q{
					EntityDisplay: meteorite, shader, meteoriteTex, mat4.scaling(10, 10, 10) * mat4.xrotation(uniform(0.0f, 3.1415926f * 2))
					Transformation: mat4.translation(uniform(-1000.0f, 1000.0f), uniform(-70.0f, -20.0f), uniform(-1000.0f, 1000.0f))
				}));
		}

		street = resources.load!Texture("textures/street.png");
		street.wrapX = TextureClampMode.ClampToEdge;
		street.wrapY = TextureClampMode.ClampToEdge;
		street.applyParameters();
		border = resources.load!Texture("textures/border.png");
		border.wrapX = TextureClampMode.Mirror;
		border.wrapY = TextureClampMode.Mirror;
		border.applyParameters();
		poleTex = resources.load!Texture("textures/pole.png");
		poleMesh = resources.load!Scene("models/pole.obj").value.meshes[0].convertAssimpMesh;
		vehicle1 = resources.load!Texture("textures/vehicle1.png");
		vehicleMesh = resources.load!Scene("models/vehicle1.obj").value.meshes[0].convertAssimpMesh;
	}

	override void preEnter(IScene prev)
	{
		particles.clear();
		string[] toDelete = [
			"Track", "TrackL", "TrackR", "Start Pole Left", "Start Pole Right",
			"Bot 1", "Player", "Bot 2", "Bot 3", "Bot 4", "Bot 5", "Bot 6", "Bot 7"
		];
		foreach_reverse (i, entity; world.entities)
		{
			if (toDelete.canFind(entity.name))
				world.entities = world.entities.remove(i);
			else
			{
				RaceInfo* info;
				if (entity.fetch(info))
					info.time = -3;
			}
		}
		if (cast(MapselectScene) prev)
		{
			auto mapSel = (cast(MapselectScene) prev);
			track = mapSel.choices[mapSel.index];
			if (mapSel.online)
			{
				import std.file;
				import std.uuid;

				write("res/maps/download_" ~ UUID(track.id).toString ~ ".map", track.trackToMemory);
			}
		}
		else if (cast(MapEditorScene) prev)
		{
			auto mapEdit = (cast(MapEditorScene) prev);
			track = mapEdit.editor.toTrack;
		}
		else
			track = generateTrack;
		track.generateOuterAndMeshes();
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
			mixin(createEntity!("Bot 1", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[0] * 0.2f + track.outerRing[0] * 0.8f, track.startRotation1
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Player", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				PlayerControls: settings.controls
				VehiclePhysics: track.innerRing[0] * 0.4f + track.outerRing[0] * 0.6f, track.startRotation1
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 2", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[0] * 0.6f + track.outerRing[0] * 0.4f, track.startRotation1
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 3", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[0] * 0.8f + track.outerRing[0] * 0.2f, track.startRotation1
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 4", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.2f + track.outerRing[$ - 1] * 0.8f, track.startRotation2
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 5", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.4f + track.outerRing[$ - 1] * 0.6f, track.startRotation2
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 6", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.6f + track.outerRing[$ - 1] * 0.4f, track.startRotation2
				VehicleAI:
				ParticleSpawner:
			}));
			mixin(createEntity!("Bot 7", q{
				EntityDisplay: vehicleMesh, shader, vehicle1, mat4.identity
				Transformation: mat4.translation(0, 0, 0)
				VehiclePhysics: track.innerRing[$ - 1] * 0.8f + track.outerRing[$ - 1] * 0.2f, track.startRotation2
				VehicleAI:
				ParticleSpawner:
			}));
		}
	}

	override void postExit(IScene next)
	{
	}

	Track track;
	ParticleSystem!(8192) particles;
	Texture vehicle1, poleTex, street, border;
	Mesh vehicleMesh, poleMesh;
	Shader shader;
}
