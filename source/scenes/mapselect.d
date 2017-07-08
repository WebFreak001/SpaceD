module scenes.mapselect;

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
import systems.menu;
import trackgen;

import std.conv;
import std.file;
import std.path;
import std.uuid;
import std.stdio : stderr;

version(Have_Requests)
{
	import asdf;
	import api;
	import requests;
}

class MapselectScene : IScene
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
		playButton = mixin(createEntity!("Play Button", q{
			Button: "Play"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 300, 50), Align.BottomRight
			TabFocus: 0
			SceneSwitchAction: "ingame"
		}, "world", true));
		mapTitle = mixin(createEntity!("Map Title", q{
			GUIText: "???"d, vec2(0, 48), vec2(1, 1), vec4(1), Align.TopCenter, TextAlign.Center
		}, "world", true));
		pbDisplay = mixin(createEntity!("PBDisplay", q{
			GUIText: "PB: n/a"d, vec2(0, 16), vec2(1, 1), vec4(1), Align.BottomCenter, TextAlign.Center
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

	void updateMap()
	{
		auto dotsP = dots.get!Dots;
		version(Have_Requests)
			if (online && index == dotsP.numDots)
				addMaps(cast(int)(index - 1) / 100);
		dotsP.dotsIndex = cast(int) index;
		mapTitle.get!GUIText.text = choices[index].name.to!dstring;
		if (choices[index].isRandom)
			pbDisplay.get!GUIText.text = "PB: "d ~ globalState.bestTime.makeTime;
		else
		{
			ulong ms = pbStore.pbFor(choices[index].id);
			if (ms != 0)
				pbDisplay.get!GUIText.text = "PB: "d ~ ms.makeTime;
			else
				pbDisplay.get!GUIText.text = "PB: n/a"d;
		}
		version(Have_Requests)
			if (online && choices[index].toDownload)
			{
				string name = choices[index].name;
				choices[index] = trackFromMemory(getContent(APIEndPoint ~ "maps/" ~ UUID(choices[index].id)
						.toString).data);
				choices[index].name = name;
			}

		choices[index].generateOuterAndMeshes();
		preview.get!GUI3D.mesh = choices[index].roadMesh;
	}

	void notifyMap(string file, Track track)
	{
		if (online)
			return;
		choices ~= track;
		index = choices.length - 1;
		dots.get!Dots.numDots = cast(int) choices.length;
		updateMap();
	}

	version(Have_Requests)
	void addMaps(int page)
	{
		try
		{
			auto maps = deserialize!(PublicMap[])(cast(string) getContent(APIEndPoint ~ "maps",
					queryParams("page", page)));
			foreach (map; maps)
			{
				Track track;
				track.name = map.uploader ~ " - " ~ map.name;
				track.id = UUID(map.id).data;
				track.toDownload = true;
				choices ~= track;
			}
			if (maps.length == page * 100)
				dots.get!Dots.numDots = page * 100 + 1;
			else
				dots.get!Dots.numDots = page * 100 + cast(int) maps.length;
		}
		catch (Exception e)
		{
			stderr.writeln("Error while fetching maps");
			stderr.writeln(e);
			sceneManager.setScene("error");
		}
	}

	override void preEnter(IScene prev)
	{
		version(Have_Requests)
			online = sceneManager.current == "mapbrowser";
		else
			online = false;
		if (online)
		{
			version(Have_Requests)
			{
				choices.length = 0;
				index = 0;
				addMaps(0);
				if (choices.length == 0)
				{
					// No Maps uploaded
					sceneManager.setScene("main");
					return;
				}
				playButton.get!Button.text = "Download"d;
			}
		}
		else
		{
			choices = [generateTrack];
			foreach (map; dirEntries("res/maps", SpanMode.shallow)) // TODO: implement this into ResourceManager
			{
				if (map.extension != ".map")
					continue;
				choices ~= trackFromMemory(cast(ubyte[]) read(map));
			}
			index = 0;
			dots.get!Dots.numDots = cast(int) choices.length;
			playButton.get!Button.text = "Play"d;
		}
		updateMap();
	}

	override void postExit(IScene next)
	{
	}

	bool online = false;
	Entity mapTitle, pbDisplay, dots, preview, playButton;
	Track[] choices;
	size_t index;
	SceneManager sceneManager;
}
