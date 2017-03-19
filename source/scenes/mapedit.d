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
		editBtn = mixin(createEntity!("Edit Button", q{
			Button: "Edit"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 300, 50), Align.BottomRight
			TabFocus: 0
			SceneSwitchAction: "editor"
		}, "world", true));
		mapTitle = mixin(createEntity!("Map Title", q{
			GUIText: "???"d, vec2(0, 48), vec2(1, 1), vec4(1), Align.TopCenter, TextAlign.Center
		}, "world", true));
		dots = mixin(createEntity!("Dots", q{
			Dots: vec2(0, 90), Align.BottomCenter, 1, 0
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

	void updateMap()
	{
		dots.get!Dots.dotsIndex = cast(int) index;
		mapTitle.get!GUIText.text = choices[index].name.to!dstring;
		choices[index].generateOuterAndMeshes();
		preview.get!GUI3D.mesh = choices[index].roadMesh;
		if (choices[index].isRandom)
			editBtn.get!Button.text = "Create"d;
		else
			editBtn.get!Button.text = "Edit"d;
	}

	override void preEnter(IScene prev)
	{
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

	override void postExit(IScene next)
	{
	}

	SceneManager sceneManager;
	Entity mapTitle, dots, preview, editBtn;
	string[] files;
	Track[] choices;
	size_t index;
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
