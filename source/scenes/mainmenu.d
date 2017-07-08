module scenes.mainmenu;

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

class MainMenuScene : IScene
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
			auto vehicle1 = resources.load!Texture("textures/vehicle1.png");
			auto vehicleMesh = resources.load!Scene("models/vehicle1.obj")
				.value.meshes[0].convertAssimpMesh;
			mixin(createEntity!("Menu Vehicle", q{
				GUI3D: perspective(1, 9.0f/16.0f, 30.0f, 0.1f, 50.0f), mat4.translation(2, -1.5f, -12) * mat4.yrotation(cradians!140) * mat4.xrotation(-cradians!10), vehicleMesh, shader, vehicle1
			}));
		}

		auto logo = resources.load!Texture("textures/logo.png");
		mixin(createEntity!("Logo", q{
			GUIRectangle: logo, vec4(32, 32, 320, 89), Align.TopRight
		}));
		mixin(createEntity!("Play Button", q{
			Button: "Play"d, vec4(0.69f, 0.224f, 0.192f, 1), vec4(1), vec4(112, 32, 300, 64), Align.TopLeft
			TabFocus: 0
			SceneSwitchAction: "mapselect"
		}));
		mixin(createEntity!("Create Button", q{
			Button: "Create"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(96, 112, 300, 64), Align.TopLeft
			TabFocus: 1
			SceneSwitchAction: "mapedit"
		}));
		version(Have_Requests)
			mixin(createEntity!("Browse Button", q{
				Button: "Browse Maps"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(80, 192, 300, 64), Align.TopLeft
				TabFocus: 2
				SceneSwitchAction: "mapbrowser"
			}));
		mixin(createEntity!("Shop Button", q{
			Button: "Shop"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(64, 272, 300, 64), Align.TopLeft
			TabFocus: 3
			SceneSwitchAction: "shop"
		}));
		mixin(createEntity!("Settings Button", q{
			Button: "Settings"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(48, 352, 300, 64), Align.TopLeft
			TabFocus: 4
			SceneSwitchAction: "settings"
		}));
		mixin(createEntity!("Exit Button", q{
			Button: "Exit"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(16, 16, 240, 64), Align.BottomLeft
			TabFocus: 5
			SceneSwitchAction: "crash"
		}));
		moneyCounter = mixin(createEntity!("Money Counter", q{
			GUIText: "Money: 0ĸ"d, vec2(16, 16), vec2(1, 1), vec4(1), Align.BottomRight
		}, "world", true));
	}

	override void preEnter(IScene prev)
	{
		moneyCounter.get!GUIText.text = "Money: "d ~ globalState.money.to!dstring ~ 'ĸ';
	}

	override void postExit(IScene next)
	{
	}

	Entity moneyCounter;
}

class ShopScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		boostBuy = mixin(createEntity!("Buy Boost Button", q{
			Button: "Buy Boost"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(64, 32, 300, 64)
			TabFocus: 0
			BuyAction: 0
			SceneSwitchAction: "shop"
		}, "world", true));
		controlBuy = mixin(createEntity!("Control+ Button", q{
			Button: "+Air Resistance"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(48, 112, 300, 64)
			TabFocus: 1
			BuyAction: 1
			SceneSwitchAction: "shop"
		}, "world", true));
		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(16, 16, 240, 64), Align.BottomLeft
			TabFocus: 2
			SceneSwitchAction: "main"
		}));
		boostUpgrades = mixin(createEntity!("Boost Counter", q{
			GUIText: "x0"d, vec2(364 + 24, 80), vec2(1, 1), vec4(1), Align.TopLeft
		}, "world", true));
		controlUpgrades = mixin(createEntity!("Control+ Counter", q{
			GUIText: "x0"d, vec2(348 + 24, 160), vec2(1, 1), vec4(1), Align.TopLeft
		}, "world", true));
		moneyCounter = mixin(createEntity!("Money Counter", q{
			GUIText: "Money: 0ĸ"d, vec2(16, 16), vec2(1, 1), vec4(1), Align.BottomRight
		}, "world", true));
	}

	override void preEnter(IScene prev)
	{
		updateMoney();
	}

	override void postExit(IScene next)
	{
		globalState.save();
	}

	void updateMoney()
	{
		moneyCounter.get!GUIText.text = "Money: "d ~ globalState.money.to!dstring ~ 'ĸ';
		boostBuy.get!Button.text = "Buy Boost ("d ~ globalState.upgradeCost(0).to!dstring ~ "ĸ)"d;
		controlBuy.get!Button.text = "+Air Resistance ("d ~ globalState.upgradeCost(1)
			.to!dstring ~ "ĸ)"d;
		boostUpgrades.get!GUIText.text = 'x' ~ globalState.upgrades.boostLevel.to!dstring;
		controlUpgrades.get!GUIText.text = 'x' ~ globalState.upgrades.betterControls.to!dstring;
	}

	Entity boostBuy, controlBuy;
	Entity boostUpgrades, controlUpgrades;
	Entity moneyCounter;
}

class SettingsScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		this.sceneManager = sceneManager;
		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Accelerate: "d ~ settings.controls.accelerate.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 16, 300, 48)
			KeybindAction: "Accelerate", "accelerate"
		}, "world", true));
		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Steer Left: "d ~ settings.controls.steerLeft.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 70, 300, 48)
			KeybindAction: "Steer Left", "steerLeft"
		}, "world", true));
		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Decelerate: "d ~ settings.controls.decelerate.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 124, 300, 48)
			KeybindAction: "Decelerate", "decelerate"
		}, "world", true));
		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Steer Right: "d ~ settings.controls.steerRight.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 178, 300, 48)
			KeybindAction: "Steer Right", "steerRight"
		}, "world", true));
		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Boost: "d ~ settings.controls.boost.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 232, 300, 48)
			KeybindAction: "Boost", "boost"
		}, "world", true));
		keybinds ~= mixin(createEntity!("Keybind", q{
			Button: "Look Back: "d ~ settings.controls.lookBack.to!dstring, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 286, 300, 48)
			KeybindAction: "Look Back", "lookBack"
		}, "world", true));
		sound = mixin(createEntity!("Sound Button", q{
			Button: "Sound"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 340, 300, 48)
			TabFocus: 0
			DelegateAction: &toggleSound
		}, "world", true));
		music = mixin(createEntity!("Music Button", q{
			Button: "Music"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(-1000, 394, 300, 48)
			TabFocus: 1
			DelegateAction: &toggleMusic
		}, "world", true));

		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(16, 16, 240, 64), Align.BottomLeft
			TabFocus: 2
			SceneSwitchAction: "main"
		}));
	}

	Entity[] keybinds;
	override void preEnter(IScene prev)
	{
		if (!(cast(SettingsScene) prev))
			world.tick();
		foreach (ref ent; keybinds)
			ent.get!Button.rect.x = 16;
		sound.get!Button.rect.x = 16;
		sound.get!Button.text = settings.disableSound ? "Enable Sound"d : "Disable Sound"d;
		music.get!Button.rect.x = 16;
		music.get!Button.text = settings.disableMusic ? "Enable Music"d : "Disable Music"d;

	}

	override void postExit(IScene next)
	{
		if (cast(SettingsScene) next)
			return;
		foreach (ref ent; keybinds)
			ent.get!Button.rect.x = -1000;
		sound.get!Button.rect.x = -1000;
		music.get!Button.rect.x = -1000;
	}

	void toggleSound()
	{
		settings.disableSound = !settings.disableSound;
		settings.save();
		sceneManager.setScene("settings");
	}

	void toggleMusic()
	{
		settings.disableMusic = !settings.disableMusic;
		if (settings.disableMusic)
			bgMusic.fadeOut(500);
		else
			bgMusic.fadeIn(500);
		settings.save();
		sceneManager.setScene("settings");
	}

	Entity sound, music;
	SceneManager sceneManager;
}

class ErrorScene : IScene
{
	override void load(SceneManager sceneManager, Renderer renderer, View window,
			ResourceManager resources, ShaderPool shaders)
	{
		auto textVert = shaders.load(ShaderType.Vertex, "shaders/text.vert");
		auto textFrag = shaders.load(ShaderType.Fragment, "shaders/text.frag");

		Shader textShader = new Shader(renderer, textVert, textFrag);
		Font font = resources.load!Font("fonts/roboto.fnt", resources, "fonts/");

		world.addSystem!MenuSystem(renderer, window, font, textShader, sceneManager);

		mixin(createEntity!("Error Text", q{
			GUIText: "An unexpected error occured"d, vec2(0, 100), vec2(1, 1), vec4(1), Align.TopCenter, TextAlign.Center
		}));
		mixin(createEntity!("Back Button", q{
			Button: "Back"d, vec4(0.878f, 0.878f, 0.878f, 1), vec4(0, 0, 0, 1), vec4(16, 16, 240, 64), Align.BottomLeft
			TabFocus: 0
			SceneSwitchAction: "main"
		}));
	}

	override void preEnter(IScene prev)
	{
	}

	override void postExit(IScene next)
	{
	}
}
