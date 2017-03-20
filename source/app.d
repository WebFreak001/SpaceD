module app;

import avocado.assimp;
import avocado.bmfont;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import globstate;
import scenemanager;
import scenes.ingame;
import scenes.leaderboard;
import scenes.mainmenu;
import scenes.mapedit;
import scenes.mapselect;
import shaderpool;
import trackgen;

alias View = SDLWindow;
alias Renderer = GL3Renderer;
alias Shader = GL3ShaderProgram;
alias ShaderUnit = GLShaderUnit;
alias Texture = GLTexture;

alias Shape = GL3ShapePosition;
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

void main(string[] args)
{
	auto engine = new Engine;
	with (engine)
	{
		auto window = new View(1280, 720, "SpaceD");
		auto renderer = new Renderer;
		window.setOpenGLVersion(3, 3);
		auto world = add(window, renderer);

		void onResized(int width, int height)
		{
			renderer.resize(width, height);
		}

		window.onResized ~= &onResized;
		onResized(window.width, window.height);

		SDL_EventState(SDL_DROPFILE, SDL_ENABLE);

		auto resources = new ResourceManager();
		resources.prepend("res");
		resources.prependAll("packs", "*.{pack,zip}");

		renderer.setupDepthTest(DepthFunc.Less);

		globalState.load();
		scope (exit)
			globalState.save();
		pbStore.load();
		scope (exit)
			pbStore.save();
		settings = PlayerSettings.load();
		scope (exit)
			settings.save();

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

		auto mapselect = new MapselectScene();
		mapselect.load(sceneManager, renderer, window, resources, shaders);
		sceneManager.register(mapselect, "mapselect");

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
		while (update)
			limiter.wait();
		stop();
	}
}
