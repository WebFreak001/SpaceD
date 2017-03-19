module systems.menu;

import avocado.core;
import avocado.gl3;
import avocado.sdl2;
import avocado.dfs;
import avocado.input;

import app;
import text;
import globstate;
import components;
import scenemanager;
import particles;

import std.algorithm;
import std.conv;
import std.stdio;

class MenuSystem : ISystem
{
public:
	this(Renderer renderer, View window, Font font, Shader textShader, SceneManager sceneManager)
	{
		this.renderer = renderer;
		this.window = window;
		this.sceneManager = sceneManager;
		text = new Text(font, textShader);

		buttonShape = new GL3ShapePosition();
		buttonShape.addPositionArray([vec2(0.05f, 0), vec2(1, 0), vec2(0.95f, 1),
				vec2(0.95f, 1), vec2(0.05f, 0), vec2(0, 1)]);
		buttonShape.generate();

		chevronL = new GL3ShapePosition();
		chevronL.addPositionArray([vec2(0.5f, 0), vec2(1, 0), vec2(0.5f, 0.5f),
				vec2(0.5f, 0.5f), vec2(0.5f, 0), vec2(0, 0.5f), vec2(0, 0.5f),
				vec2(0.5f, 0.5f), vec2(1, 1), vec2(0, 0.5f), vec2(1, 1), vec2(0.5f, 1)]);
		chevronL.generate();

		chevronR = new GL3ShapePosition();
		chevronR.addPositionArray([vec2(0, 0), vec2(0.5f, 0), vec2(1, 0.5f),
				vec2(1, 0.5f), vec2(0, 0), vec2(0.5f, 0.5f), vec2(0.5f, 0.5f), vec2(1,
					0.5f), vec2(0.5f, 1), vec2(0.5f, 0.5f), vec2(0.5f, 1), vec2(0, 1)]);
		chevronR.generate();

		dot = new GL3ShapePosition();
		dot.primitiveType = PrimitiveType.TriangleFan;
		vec2[] dotPos = [vec2(8, 8)];
		for (int i = 0; i <= 9; i++)
			dotPos ~= vec2(sin(i / 9.0f * PI * 2) * 8 + 8, cos(i / 9.0f * PI * 2) * 8 + 8);
		dot.addPositionArray(dotPos);
		dot.generate();

		window.onKeyboard ~= &keyboardEvent;
	}

	void keyboardEvent(KeyboardEvent ev)
	{
		if (ev.type == SDL_KEYDOWN)
			lastKey = cast(Key) ev.keysym.sym;
	}

	final void update(World world)
	{
		renderer.begin(window);
		renderer.clearColor = vec4(0.149f, 0.196f, 0.220f, 1.0f);
		renderer.clear();

		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				GUI3D* g3d;
				if (entity.fetch(g3d))
				{
					g3d.time += world.delta;
					renderer.modelview.push();
					renderer.projection.push();
					renderer.projection = g3d.projection;
					renderer.modelview = g3d.modelview * mat4.yrotation(g3d.time * 0.1f);
					renderer.bind(g3d.shader);
					renderer.bind(g3d.texture);
					renderer.drawMesh(g3d.mesh);
					renderer.projection.pop();
					renderer.modelview.pop();
				}
			}
		}

		renderer.bind2D();
		renderer.modelview.push();
		renderer.modelview = mat4.identity;

		int maxTabIndex = 0;

		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				{
					Button* button;
					if (entity.fetch(button))
					{
						bool focused;
						bool act;
						vec4 rect = compute(button.rect, button.alignment, window.width, window.height);
						if (Mouse.state.x > rect.x && Mouse.state.x <= rect.x + rect.z
								&& Mouse.state.y > rect.y && Mouse.state.y <= rect.y + rect.a)
						{
							focused = true;
							curTabIndex = -1;
							if (!Mouse.state.isButtonPressed(1) && prevMouse.isButtonPressed(1))
								act = true;
							{
								KeybindAction kbAction;
								if (entity.fetch(kbAction) && lastKey != cast(Key) 0)
								{
									button.text = kbAction.name.to!dstring ~ ": "d ~ lastKey.to!dstring;
									switch (kbAction.field)
									{
									case "accelerate":
										settings.controls.accelerate = lastKey;
										settings.save();
										break;
									case "steerLeft":
										settings.controls.steerLeft = lastKey;
										settings.save();
										break;
									case "decelerate":
										settings.controls.decelerate = lastKey;
										settings.save();
										break;
									case "steerRight":
										settings.controls.steerRight = lastKey;
										settings.save();
										break;
									case "boost":
										settings.controls.boost = lastKey;
										settings.save();
										break;
									case "lookBack":
										settings.controls.lookBack = lastKey;
										settings.save();
										break;
									default:
										assert(0);
									}
								}
							}
						}
						TabFocus tabFocus;
						if (entity.fetch(tabFocus))
						{
							if (tabFocus.index > maxTabIndex)
								maxTabIndex = tabFocus.index;
							if (curTabIndex == tabFocus.index)
							{
								focused = true;
								if (!Keyboard.state.isKeyPressed(Key.Return)
										&& prevKeyboard.isKeyPressed(Key.Return))
									act = true;
							}
						}
						renderer.modelview.push();
						renderer.modelview.top *= mat4.translation(vec3(rect.xy,
								0)) * mat4.scaling(rect.z, rect.w, 1);
						auto shape = buttonShape;
						if (button.text == "<"d)
							shape = chevronL;
						if (button.text == ">"d)
							shape = chevronR;
						if (focused)
							renderer.fillShape(shape, vec2(0), (button.bg + vec4(0.5f, 0.5f, 1, 1)) * 0.5f);
						else
							renderer.fillShape(shape, vec2(0), button.bg);
						renderer.modelview.pop();
						if (act)
						{
							BuyAction buyAction;
							if (entity.fetch(buyAction))
							{
								int cost = globalState.upgradeCost(buyAction.upgradeIndex);
								if (globalState.money >= cost)
								{
									globalState.binUpgrades[buyAction.upgradeIndex]++;
									globalState.money -= cost;
								}
							}
							SceneSwitchAction sceneAction;
							if (entity.fetch(sceneAction))
								sceneManager.setScene(sceneAction.scene);
							DelegateAction delegateAction;
							if (entity.fetch(delegateAction))
								delegateAction.del();
						}
						if (button.text != "<"d && button.text != ">"d)
						{
							text.text = button.text;
							renderer.modelview.push();
							renderer.modelview.top *= mat4.translation(vec3(rect.x + (rect.z - text.textWidth * 768) * 0.5,
									rect.y + text.lineHeight * 512 + (rect.a - text.lineHeight * 512) * 0.5, 0)) * mat4.scaling(768,
									512, 1);
							text.draw(renderer, button.fg);
							renderer.modelview.pop();
						}
					}
				}
				{
					GUIRectangle* rectangle;
					if (entity.fetch(rectangle))
					{
						auto rect = compute(rectangle.rect, rectangle.alignment, window.width, window.height);
						renderer.drawRectangle(rectangle.texture, rect);
					}
				}
				{
					GUIColorRectangle* rectangle;
					if (entity.fetch(rectangle))
					{
						auto rect = compute(rectangle.rect, rectangle.alignment, window.width, window.height);
						renderer.fillRectangle(rect, rectangle.color);
					}
				}
				{
					GUIText* guitext;
					if (entity.fetch(guitext))
					{
						text.text = guitext.text;
						vec4 baseRect = vec4(guitext.pos.xy, text.textWidth * 768 * guitext.scale.x, 0);
						if (guitext.textAlign == TextAlign.Right)
							baseRect.x -= baseRect.z;
						else if (guitext.textAlign == TextAlign.Center)
							baseRect.x -= baseRect.z * 0.5f;
						vec4 rect = compute(baseRect, guitext.alignment, window.width, window.height);
						renderer.modelview.push();
						renderer.modelview.top *= mat4.translation(vec3(rect.x, rect.y,
								0)) * mat4.scaling(768 * guitext.scale.x, 512 * guitext.scale.y, 1);
						text.draw(renderer, guitext.fg);
						renderer.modelview.pop();
					}
				}
				{
					Dots* dots;
					if (entity.fetch(dots))
					{
						vec4 baseRect = vec4(dots.pos.x - dots.numDots * 12 + 4, dots.pos.y,
								dots.numDots * 24 - 8, 16);
						vec4 rect = compute(baseRect, dots.alignment, window.width, window.height);
						for (int i = 0; i < dots.numDots; i++)
							renderer.fillShape(dot, rect.xy + vec2(i * 24, 0),
									dots.dotsIndex == i ? vec4(1) : vec4(1, 1, 1, 0.5f));
					}
				}
			}
		}

		bool tab = Keyboard.state.isKeyPressed(Key.Tab) && !prevKeyboard.isKeyPressed(Key.Tab);
		bool shiftDown = Keyboard.state.isKeyPressed(Key.LShift)
			|| Keyboard.state.isKeyPressed(Key.RShift);
		if ((tab && !shiftDown) || (Keyboard.state.isKeyPressed(Key.Down)
				&& !prevKeyboard.isKeyPressed(Key.Down)))
			curTabIndex = (curTabIndex + 1) % (maxTabIndex + 1);
		if ((tab && shiftDown) || (Keyboard.state.isKeyPressed(Key.Up)
				&& !prevKeyboard.isKeyPressed(Key.Up)))
			curTabIndex = (curTabIndex + maxTabIndex) % (maxTabIndex + 1);

		prevMouse = (*Mouse.state);
		prevKeyboard = KeyboardState(Keyboard.state.keys.dup);

		lastKey = cast(Key) 0;

		renderer.modelview.pop();
		renderer.bind3D();
		renderer.end(window);
	}

private:
	SceneManager sceneManager;
	Renderer renderer;
	View window;
	Text text;
	int curTabIndex = -1;
	Shape buttonShape, chevronL, chevronR, dot;
	Key lastKey = cast(Key) 0;

	MouseState prevMouse;
	KeyboardState prevKeyboard;
}
