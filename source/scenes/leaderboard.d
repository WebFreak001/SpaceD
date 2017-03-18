module scenes.leaderboard;

import avocado.assimp;
import avocado.core;
import avocado.dfs;
import avocado.gl3;
import avocado.sdl2;

import std.conv;

import app;
import components;
import globstate;
import scenemanager;
import scenes.ingame;
import systems.menu;
import systems.display;
import trackgen;
import shaderpool;

class LeaderboardScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textureFrag = shaders.load(ShaderType.Fragment, "shaders/texture.frag");

		Shader textShader = new Shader(renderer, textVert, textureFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.5f, 0.5f, 0.5f, 1), vec4(1), vec4(10, 10, 100, 50)
			TabFocus: 0
			SceneSwitchAction: "main"
		}));

		for (int i = 0; i < 8; i++)
			texts[i] = world.newEntity("Leaderboard Line " ~ i.to!string)
				.add!GUIText(""d, vec2(350, 50 + i * 50), vec2(1, 1)).finalize();
		extraInfo = world.newEntity("Extra Info").add!GUIText(""d, vec2(150,
				50 + 8 * 50), vec2(1, 1)).finalize();
		curTime = world.newEntity("Best Time:").add!GUIText(""d, vec2(10, 100), vec2(1, 1)).finalize();
		bestTime = world.newEntity("Best Time:").add!GUIText(""d, vec2(10, 150),
				vec2(1, 1)).finalize();
	}

	override void preEnter(IScene prev)
	{
		foreach (ref text; texts)
			text.get!GUIText.text = ""d;
		if (cast(IngameScene) prev)
		{
			auto game = cast(IngameScene) prev;
			RaceInfo info;
			VehiclePhysics phys;
			int playerRanking;
			foreach (entity; game.world.entities)
			{
				entity.fetch(info);
				if (entity.fetch(phys))
				{
					dstring name = "Bot"d;
					if (entity.has!PlayerControls)
					{
						name = "Player"d;
						playerRanking = phys.place;
					}
					texts[phys.place].get!GUIText.text = phys.place.to!dstring.placement ~ " "d ~ name;
				}
			}
			ulong msecs = cast(ulong) (info.time * 1000);
			if (globalState.bestTime == 0 || msecs < globalState.bestTime)
			{
				globalState.bestTime = msecs;
				curTime.get!GUIText.text = "New Personal Best!"d;
				bestTime.get!GUIText.text = "Time: "d ~ msecs.makeTime;
			}
			else
			{
				curTime.get!GUIText.text = "Time: "d ~ msecs.makeTime;
				bestTime.get!GUIText.text = "Best: "d ~ globalState.bestTime.makeTime;
			}
			int earnedMoney = 0;
			if (playerRanking == 1)
				earnedMoney = 100;
			else if (playerRanking == 2)
				earnedMoney = 50;
			else if (playerRanking == 3)
				earnedMoney = 25;
			extraInfo.get!GUIText.text = "You have earned "d ~ earnedMoney.to!dstring
				~ "ĸ in this Race"d;
			globalState.money += earnedMoney;
			globalState.save();
		}
	}

	override void postExit(IScene next)
	{
	}

	Entity[8] texts;
	Entity extraInfo, curTime, bestTime;
}

dstring ndigit(ulong digit, uint n)
{
	dstring s = digit.to!dstring;
	while (s.length < n)
		s = '0' ~ s;
	return s;
}

dstring makeTime(ulong msecs)
{
	ulong secs = msecs / 1000;
	return (secs / 60).ndigit(2) ~ ':' ~ (secs % 60).ndigit(2) ~ '.' ~ (msecs % 1000).ndigit(4);
}

dstring placement(dstring s)
{
	if (s == "1"d)
		return "1st"d;
	else if (s == "2"d)
		return "2nd"d;
	else if (s == "3"d)
		return "3rd"d;
	else
		return s ~ "th"d;
}
