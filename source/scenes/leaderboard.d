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
				.add!GUIText(""d, vec2(150, 50 + i * 50), vec2(1, 1)).finalize();
		extraInfo = world.newEntity("Extra Info").add!GUIText(""d, vec2(150,
				50 + 8 * 50), vec2(1, 1)).finalize();
	}

	override void preEnter(IScene prev)
	{
		foreach (ref text; texts)
			text.get!GUIText.text = ""d;
		if (cast(IngameScene) prev)
		{
			auto game = cast(IngameScene) prev;
			VehiclePhysics phys;
			int playerRanking;
			foreach (entity; game.world.entities)
			{
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
			int earnedMoney = 0;
			if (playerRanking == 1)
				earnedMoney = 100;
			else if (playerRanking == 2)
				earnedMoney = 50;
			else if (playerRanking == 3)
				earnedMoney = 25;
			extraInfo.get!GUIText.text = "You have earned "d ~ earnedMoney.to!dstring ~ "ĸ in this Race"d;
			if (earnedMoney)
			{
				globalState.money += earnedMoney;
				globalState.save();
			}
		}
	}

	override void postExit(IScene next)
	{
	}

	Entity[8] texts;
	Entity extraInfo;
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
