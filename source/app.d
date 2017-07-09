module app;

import avocado.assimp;
import avocado.bmfont;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import derelict.sdl2.mixer;

import audio;
import globstate;
import scenemanager;
import scenes.ingame;
import scenes.leaderboard;
import scenes.mainmenu;
import scenes.mapedit;
import scenes.mapselect;
import shaderpool;
import trackgen;

import std.string;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Shape = GL3ShapePosition;
alias Mesh = GL3MeshIndexPositionTextureNormal;
alias Font = BMFont!(Texture, ResourceManager);

enum APIEndPoint = "https://spaced.webfreak.org/";

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

void importMap(string file, SceneManager sceneManager)
{
	import std.path;
	import std.file;
	import std.conv;
	import std.string;
	import std.stdio : stderr;

	if (file.extension == ".map")
	{
		try
		{
			auto target = buildPath("res", "maps", file.baseName);
			if (file.endsWith(target))
				return;
			stderr.writeln("Importing ", file);
			auto track = trackFromMemory(cast(ubyte[]) read(file));
			int i = 1;
			while (target.exists)
				target = buildPath("res", "maps", file.baseName.stripExtension ~ i.to!string ~ ".map");
			copy(file, target);
			remove(file);
			if (sceneManager.current == "mapselect")
				(cast(MapselectScene) sceneManager.scene).notifyMap(target, track);
			else if (sceneManager.current == "mapedit")
				(cast(MapeditSelectScene) sceneManager.scene).notifyMap(target, track);
		}
		catch (Exception e)
		{
			stderr.writeln("Failed to import map");
			stderr.writeln(e);
		}
	}
}

__gshared Audio collisionSound, countdownLowSound, countdownHighSound;
__gshared Music bgMusic;

void main(string[] args)
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View(1280, 720, "SpaceD", WindowFlags.Default | WindowFlags.Resizable);
		auto renderer = new Renderer;
		window.setOpenGLVersion(3, 3);
		auto world = add(window, renderer);

		DerelictSDL2Mixer.load();

		Mix_Init(MIX_INIT_OGG);
		if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 1024) == -1)
			debug throw new Exception("Failed to open audio device: " ~ Mix_GetError().fromStringz.idup);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
		}

		Key[16] lastPresses;
		ubyte lastPressIndex;
		bool isFullscreen = false;
		window.onKeyboard ~= (ev) {
			if (ev.type == SDL_KEYUP)
			{
				if (ev.keysym.sym == Key.F11)
				{
					isFullscreen = !isFullscreen;
					SDL_SetWindowFullscreen(cast(SDL_Window*) window.getHandle(),
							isFullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
				}
				lastPresses[lastPressIndex] = cast(Key) ev.keysym.sym;
				//dfmt off
				if (lastPresses[(lastPressIndex + $ - 9) % lastPresses.length] == Key.Up
					&& lastPresses[(lastPressIndex + $ - 8) % lastPresses.length] == Key.Up
					&& lastPresses[(lastPressIndex + $ - 7) % lastPresses.length] == Key.Down
					&& lastPresses[(lastPressIndex + $ - 6) % lastPresses.length] == Key.Down
					&& lastPresses[(lastPressIndex + $ - 5) % lastPresses.length] == Key.Left
					&& lastPresses[(lastPressIndex + $ - 4) % lastPresses.length] == Key.Right
					&& lastPresses[(lastPressIndex + $ - 3) % lastPresses.length] == Key.Left
					&& lastPresses[(lastPressIndex + $ - 2) % lastPresses.length] == Key.Right
					&& lastPresses[(lastPressIndex + $ - 1) % lastPresses.length] == Key.B
					&& lastPresses[lastPressIndex] == Key.A)
					cheatsActive = true;
				//dfmt on
				lastPressIndex = (lastPressIndex + 1) % lastPresses.length;
			}
		};

		globalState.load();
		scope (exit)
			globalState.save();
		pbStore.load();
		scope (exit)
			pbStore.save();
		tokenStore.load();
		scope (exit)
			tokenStore.save();
		settings = PlayerSettings.load();
		scope (exit)
			settings.save();

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		SDL_EventState(SDL_DROPFILE, SDL_ENABLE);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		collisionSound = resources.load!Audio("sounds/collision.wav");
		countdownLowSound = resources.load!Audio("sounds/countdown-low.wav");
		countdownHighSound = resources.load!Audio("sounds/countdown-high.wav");

		bgMusic = resources.load!Music("music/Blaehubb - R4cers.ogg");
		bgMusic.play;

		renderer.setupDepthTest(DepthFunc.Less);

		SceneManager sceneManager = new SceneManager(world);

		window.onDrop ~= (DropEvent ev) { importMap(ev.file, sceneManager); };

		if (args.length > 1)
			foreach (file; args[1 .. $])
				importMap(file, sceneManager);

		ShaderPool shaders = new ShaderPool(resources);

		auto ingame = new IngameScene();
		ingame.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(ingame, "ingame");
		auto shop = new ShopScene();
		shop.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(shop, "shop");
		auto settings = new SettingsScene();
		settings.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(settings, "settings");
		auto error = new ErrorScene();
		error.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(error, "error");

		auto mapselect = new MapselectScene();
		mapselect.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(mapselect, "mapselect");
		sceneManager.register(mapselect, "mapbrowser");

		auto mapedit = new MapeditSelectScene();
		mapedit.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(mapedit, "mapedit");
		auto editor = new MapEditorScene();
		editor.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(editor, "editor");

		auto leaderboards = new LeaderboardScene();
		leaderboards.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(leaderboards, "leaderboards");

		auto mainmenu = new MainMenuScene();
		mainmenu.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(mainmenu, "main");
		sceneManager.setScene("main");

		FPSLimiter limiter = new FPSLimiter(240);

		start();
		while (update && !sceneManager.shouldExit)
			limiter.wait();
		stop();
	}
}
