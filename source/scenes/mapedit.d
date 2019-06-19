module scenes.mapedit;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import app;
import components;
import globstate;
import scenemanager;
import shaderpool;
import scenes.ingame;
import systems.menu;
import systems.editor;
import trackgen;

import std.conv;
import std.file;
import std.path;

class MapeditSelectScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto defaultFrag = shaders.load(ShaderType.Fragment, "shaders/default.frag");
		auto defaultVert = shaders.load(ShaderType.Vertex, "shaders/default.vert");
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		auto shader = new Shader();
		shader.attach(defaultFrag);
		shader.attach(defaultVert);
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		this.sceneManager = sceneManager;
		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		{
			auto trackTex = resources.load!Texture("textures/street.png");
			auto trackMesh = resources.load!Scene("models/pole.obj").value.meshes[0].convertAssimpMesh;
			preview = mixin(createEntity!("Map Preview", q{
				GUI3D: perspective(1, 9.0f/16.0f, 45.0f, 0.1f, 1000.0f), mat4.translation(0, -1.5f, -200) * mat4.xrotation(cradians!30) * mat4.scaling(0.1f, 0.1f, 0.1f), trackMesh, shader, trackTex
			}, "world", true));
		}

		mixin(createEntity!("BottomBar", q{
			GUIColorRectangle: vec4(0.216f, 0.278f, 0.31f, 1), vec4(0, 0, 10000, 70), Align.BottomLeft
		}));
		mixin(createEntity!("PrevMap", q{
			Button: "<"d, vec4(1, 1, 1, 0.5f), vec4(1), vec4(80, 80, 64, 320), Align.TopLeft
			TabFocus: 1
			DelegateAction: &prevMap
		}));
		mixin(createEntity!("NextMap", q{
			Button: ">"d, vec4(1, 1, 1, 0.5f), vec4(1), vec4(80, 80, 64, 320), Align.TopRight
			TabFocus: 2
			DelegateAction: &nextMap
		}));
		deleteBtn = mixin(createEntity!("Delete Button", q{
			Button: "Delete"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 100, 32), Align.TopLeft
			DelegateAction: &deleteMap
		}, "world", true));
		version (Have_requests)
			uploadBtn = mixin(createEntity!("Upload Button", q{
				Button: "Upload"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 100, 32), Align.TopRight
				DelegateAction: &uploadMap
			}, "world", true));
		editBtn = mixin(createEntity!("Edit Button", q{
			Button: "Edit"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 300, 50), Align.BottomRight
			TabFocus: 0
			SceneSwitchAction: "editor"
		}, "world", true));
		mapTitle = mixin(createEntity!("Map Title", q{
			GUIText: "???"d, vec2(0, 48), vec2(1, 1), vec4(1), Align.TopCenter, TextAlign.Center
		}, "world", true));
		dots = mixin(createEntity!("Dots", q{
			Dots: vec2(0, 90), Align.BottomCenter, 1, 0, &prevMap, &nextMap
		}, "world", true));
		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 300, 50), Align.BottomLeft
			TabFocus: 3
			SceneSwitchAction: "main"
		}));
	}

	void prevMap()
	{
		index = (index + choices.length - 1) % choices.length;
		updateMap();
	}

	void nextMap()
	{
		index = (index + 1) % choices.length;
		updateMap();
	}

	void deleteMap()
	{
		if (index == 0)
			return;

		deleteIndex = index;
		mixin(createEntity!("Delete Dialog", q{
			Dialog: "Really delete map "d ~ files[index].baseName.to!dstring ~ "?"d, "Delete"d, "Cancel"d
			DelegateAction: &actuallyDelete
		}));
		sceneManager.setScene("mapedit");
	}

	version (Have_requests) void uploadMap()
	{
		if (index == 0)
			return;

		uploadIndex = index;
		uploadDialog = mixin(createEntity!("Upload Dialog", q{
			Dialog: "Upload map "d ~ files[index].baseName.to!dstring ~ " to the Internet?"d, "Upload"d, "Cancel"d, "Author Name: "d, "Anon"
			DelegateAction: &actuallyUpload
		}, "world", true));
		sceneManager.setScene("mapedit");
	}

	void actuallyDelete()
	{
		import std.algorithm;
		import std.file;

		if (index != deleteIndex)
			return;

		std.file.remove(files[index]);
		files = files.remove(index);
		choices = choices.remove(index);
		dots.get!Dots.numDots = cast(int) choices.length;
		index = index % choices.length;
		updateMap();
		deleteIndex = -1;
	}

	version (Have_requests) void actuallyUpload()
	{
		import requests;
		import std.json;
		import std.uuid;
		import std.stdio : stderr;

		if (index != uploadIndex)
			return;

		auto map = choices[index];
		JSONValue[] points;
		foreach (i, ref v; map.innerRing)
			points ~= JSONValue([JSONValue(v.x), JSONValue(v.y), JSONValue(map.widths[i])]);
		string uploader = uploadDialog.get!Dialog.value;
		//dfmt off
		JSONValue data = JSONValue([
			"mapid": JSONValue(UUID(map.id).toString),
			"name": JSONValue(map.name),
			"uploader": JSONValue(uploader),
			"controlPoints": JSONValue(points)
		]);
		//dfmt on
		auto tok = tokenStore.tokenFor(map.id);
		if (tok != [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
			data["token"] = JSONValue(UUID(tok).toString);

		try
		{
			auto ret = cast(string) postContent(APIEndPoint ~ "maps", data.toString, "application/json");
			if (ret.length > 2)
				tokenStore.storeMap(map.id, UUID(ret[1 .. $ - 1]).data);
			else
				throw new Exception(ret);
		}
		catch (Exception e)
		{
			stderr.writeln("Failed uploading");
			stderr.writeln(data);
			stderr.writeln(e);
			sceneManager.setScene("error");
		}
		uploadIndex = -1;
	}

	void updateMap()
	{
		dots.get!Dots.dotsIndex = cast(int) index;
		mapTitle.get!GUIText.text = choices[index].name.to!dstring;
		choices[index].generateOuterAndMeshes();
		preview.get!GUI3D.mesh = choices[index].roadMesh;
		if (choices[index].isRandom)
		{
			editBtn.get!Button.text = "Create"d;
			deleteBtn.get!Button.rect.x = -500;
			version (Have_requests)
				uploadBtn.get!Button.rect.x = -500;
		}
		else
		{
			editBtn.get!Button.text = "Edit"d;
			deleteBtn.get!Button.rect.x = 10;
			version (Have_requests)
				uploadBtn.get!Button.rect.x = 10;
		}
	}

	override void preEnter(IScene prev)
	{
		if (prev == this && (deleteIndex != -1 || uploadIndex != -1))
			return;
		choices = [generateTrack];
		files = [null];
		foreach (map; dirEntries("res/maps", SpanMode.shallow)) // TODO: implement this into ResourceManager
		{
			if (map.extension != ".map")
				continue;
			files ~= map;
			choices ~= trackFromMemory(cast(ubyte[]) read(map));
		}
		index = 0;
		dots.get!Dots.numDots = cast(int) choices.length;
		updateMap();
	}

	void notifyMap(string file, Track track)
	{
		files ~= file;
		choices ~= track;
		index = choices.length - 1;
		dots.get!Dots.numDots = cast(int) choices.length;
		updateMap();
	}

	override void postExit(IScene next)
	{
	}

	SceneManager sceneManager;
	Entity mapTitle, dots, preview, editBtn, deleteBtn, uploadBtn, uploadDialog;
	string[] files;
	Track[] choices;
	size_t index, deleteIndex, uploadIndex;
}

class MapEditorScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");
		auto defaultVert = shaders.load(ShaderType.Vertex, "shaders/default.vert");
		auto editFrag = shaders.load(ShaderType.Fragment, "shaders/edit.frag");
		auto editVert = shaders.load(ShaderType.Vertex, "shaders/edit.vert");
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		auto shader = new Shader();
		shader.attach(textureFrag);
		shader.attach(defaultVert);
		shader.create(renderer);
		shader.register(["modelview", "projection", "tex"]);
		shader.set("tex", 0);

		auto editShader = new Shader();
		editShader.attach(editFrag);
		editShader.attach(editVert);
		editShader.create(renderer);
		editShader.register(["modelview", "projection", "tex"]);
		editShader.set("tex", 0);

		auto roadTex = resources.load!Texture("textures/street.png");
		auto testMesh = resources.load!Scene("models/pole.obj").value.meshes[0].convertAssimpMesh;
		editor = world.addSystem!EditorSystem(renderer, window, font, textShader,
				sceneManager, editShader, roadTex, shader, testMesh);
	}

	override void preEnter(IScene prevScene)
	{
		if (cast(IngameScene) prevScene)
			return;
		world.entities.length = 0;
		MapeditSelectScene selector = cast(MapeditSelectScene) prevScene;
		Track track = selector.choices[selector.index];
		Entity first;
		Entity prev;
		foreach (i, ref v; track.innerRing)
		{
			auto cur = world.newEntity("MapVertex " ~ i.to!string).add!MapVertex(v,
					track.widths[i], prev);
			if (i == 0)
				first = cur;
			if (prev)
			{
				prev.get!MapVertex.next = cur;
				prev.finalize();
			}
			prev = cur;
		}
		prev.get!MapVertex.next = first;
		first.get!MapVertex.prev = prev;
		first.finalize();
		prev.finalize();
		editor.firstSave = true;
		editor.name = track.name;
		editor.file = selector.files[selector.index];
	}

	override void postExit(IScene next)
	{
	}

	EditorSystem editor;
}
