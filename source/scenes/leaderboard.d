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

enum ScoreboardY = 64;

class LeaderboardScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		mixin(createEntity!("BottomBar", q{
			GUIColorRectangle: vec4(0.216f, 0.278f, 0.31f, 1), vec4(0, 0, 10000, 70), Align.BottomLeft
		}));

		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(10, 10, 300, 50), Align.BottomRight
			TabFocus: 0
			SceneSwitchAction: "main"
		}));

		for (int i = 0; i < 8; i++)
		{
			world.newEntity("Leaderboard Number " ~ i.to!string)
				.add!GUIText(i.placement, vec2(94, ScoreboardY + i * 50), vec2(1, 1),
						vec4(1), Align.TopLeft, TextAlign.Right).finalize();
			texts[i] = world.newEntity("Leaderboard Line " ~ i.to!string)
				.add!GUIText(""d, vec2(102, ScoreboardY + i * 50), vec2(1, 1)).finalize();
		}
		extraInfo = world.newEntity("Extra Info").add!GUIText(""d, vec2(32, 20),
				vec2(1, 1), vec4(1), Align.BottomLeft).finalize();
		curTime = world.newEntity("Cur Time:").add!GUIText(""d, vec2(10, 100),
				vec2(1, 1), vec4(1, 1, 1, 0.5f)).finalize();
		bestTime = world.newEntity("Best Time:").add!GUIText(""d, vec2(10, 70),
				vec2(1, 1), vec4(1), Align.BottomRight).finalize();

		auto pbTex = resources.load!Texture("textures/pb.png");
		pbTag = world.newEntity("PB Tag").add!GUIRectangle(pbTex, vec4(0, 0, 56,
				32), Align.TopLeft).finalize();
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
					texts[phys.place - 1].get!GUIText.text = name;
				}
			}
			ulong msecs = cast(ulong)(info.time * 1000);
			auto cTime = curTime.get!GUIText;
			cTime.text = msecs.makeTime;
			cTime.pos = vec2(190, ScoreboardY + (playerRanking - 1) * 50);
			bestTime.get!GUIText.text = "PB: "d ~ globalState.bestTime.makeTime;
			if (globalState.bestTime == 0 || msecs < globalState.bestTime)
			{
				globalState.bestTime = msecs;
				pbTag.get!GUIRectangle.rect = vec4(335, ScoreboardY + (playerRanking - 1) * 50 - 32, 56, 32);
			}
			else
				pbTag.get!GUIRectangle.rect = vec4(-100, -100, 56, 32);
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
	Entity pbTag;
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

dstring placement(size_t n)
{
	dstring s = (n + 1).to!dstring;
	if (s == "1"d)
		return "1st"d;
	else if (s == "2"d)
		return "2nd"d;
	else if (s == "3"d)
		return "3rd"d;
	else
		return s ~ "th"d;
}
