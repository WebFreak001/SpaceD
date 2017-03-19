module systems.editor;

import avocado.core;
import avocado.gl3;
import avocado.sdl2;
import avocado.input;

import app;
import components;
import scenemanager;
import trackgen;
import text;

import std.conv;
import std.regex;
import std.file;
import std.bitmanip;

auto invalid = ctRegex!`\W`;

//dfmt off
alias EditableMesh = GL3Mesh!(
	BufferElement!("Position", 2, float, false, BufferType.Element, true),
	BufferElement!("TexCoord", 2, float, false, BufferType.Element, true),
	BufferElement!("Selected", 1, int, false, BufferType.Element, true)
);
//dfmt on

enum EditMode
{
	select,
	grab,
	width
}

class EditorSystem : ISystem
{
public:
	this(Renderer renderer, View window, Font font, Shader textShader, SceneManager sceneManager,
			Shader editShader, Texture editTexture, Shader testShader, Mesh test)
	{
		this.renderer = renderer;
		this.window = window;
		text = new Text(font, textShader);
		this.sceneManager = sceneManager;
		this.editShader = editShader;
		this.editTexture = editTexture;
		this.testShader = testShader;
		this.test = test;

		mesh = new EditableMesh();
		mesh.reservePosition(16 * 1024);
		mesh.reserveTexCoord(16 * 1024);
		mesh.reserveSelected(16 * 1024);
		mesh.primitiveType = PrimitiveType.TriangleStrip;
		mesh.generate();

		window.onMouseButton ~= &mouseButton;
		window.onMouseMotion ~= &mouseMotion;
		window.onMouseWheel ~= &mouseWheel;
		window.onTextInput ~= &textInput;
		window.onKeyboard ~= &keyboard;
	}

	void mouseWheel(MouseWheelEvent ev)
	{
		if (sceneManager.current != "editor")
			return;
		zoom -= ev.y * 5;
		if (zoom < 1)
			zoom = 1;
	}

	void mouseButton(MouseButtonEvent ev)
	{
		if (sceneManager.current != "editor")
			return;
		if (ev.button == 1)
		{
			mouseDown = ev.state == SDL_PRESSED;
			if (mode == EditMode.select && ev.x >= window.width - 200 && mouseDown && !saving && !exiting)
			{
				if (ev.y < 64)
				{
					if (firstSave)
					{
						file = null;
						saving = true;
					}
					else
						saveTrack();
				}
				else if (ev.y < 128)
					sceneManager.setScene("ingame");
				else if (ev.y < 192)
				{
					if (isDirty)
						exiting = true;
					else
						sceneManager.setScene("main");
				}
				else if (ev.y < 256)
					grab();
				else if (ev.y < 320)
					rewidth();
				else if (ev.y < 384)
					extrude();
				else if (ev.y < 448)
					del();
				if (ev.y >= 192)
					mouseDown = false;
			}
		}
		if (ev.button == 2)
			mouseWheelDown = ev.state == SDL_PRESSED;
		if (ev.button == 3)
			rightMouseDown = ev.state == SDL_PRESSED;
	}

	void mouseMotion(MouseMotionEvent ev)
	{
		if (sceneManager.current != "editor")
			return;
		if (mouseWheelDown || (mouseDown && Keyboard.state.isKeyPressed(Key.LCtrl)))
		{
			offset.x -= ev.xrel * zoom * 0.005f;
			offset.y -= ev.yrel * zoom * 0.005f;
		}
		lastMouse = vec2((ev.x - window.width * 0.5f) / cast(float) window.height * 2,
				(ev.y - window.height * 0.5f) / cast(float) window.height * 2) * zoom + offset;
	}

	void textInput(TextInputEvent ev)
	{
		if (sceneManager.current != "editor")
			return;
		if (saving)
		{
			name ~= ev.text;
			if (name.length > 255)
				name.length = 255;
		}
	}

	void keyboard(KeyboardEvent ev)
	{
		if (sceneManager.current != "editor")
			return;
		if (ev.type == SDL_KEYDOWN && ev.keysym.sym == Key.Backspace && name.length > 0 && saving)
			name.length--;
		if (ev.type == SDL_KEYDOWN && ev.keysym.sym == Key.Return && name.length > 0 && saving)
			saveTrack();
	}

	void grab()
	{
		mode = EditMode.grab;
		relativeTo = lastMouse;
	}

	void rewidth()
	{
		mode = EditMode.width;
		resetRelativeTo = true;
	}

	void extrude()
	{
		extend = true;
	}

	void del()
	{
		deleteSelected = true;
	}

	void update(World world)
	{
		renderer.begin(window);
		renderer.enableBlend();
		renderer.clear();

		vec2[] positions;
		vec2[] texCoords;
		int[] selected;

		bool applyEdit;
		if (!saving && !exiting)
		{
			if (Keyboard.state.isKeyPressed(Key.G) && !gWasDown)
				grab();
			else if (Keyboard.state.isKeyPressed(Key.W) && !wWasDown)
				rewidth();
			else if (Keyboard.state.isKeyPressed(Key.E) && !eWasDown)
				extrude();
			else if (Keyboard.state.isKeyPressed(Key.Delete) && !delWasDown)
				del();
			if (!rightMouseDown && rightMouseWasDown)
				mode = EditMode.select;
			if (!mouseDown && mouseWasDown)
				applyEdit = true;
		}

		bool select = rightMouseDown && !rightMouseWasDown
			&& mode == EditMode.select && !saving && !exiting;
		bool clearSelect = select && !Keyboard.state.isKeyPressed(Key.LShift);
		ptrdiff_t foundSelect = -1;
		ptrdiff_t entityNum = 0;
		MapVertex*[] vertices;

		controlPoints.length = 0;
		foreach (entity; world.entities)
		{
			if (entity.alive)
			{
				Entity other = entity;
				do
				{
					MapVertex* vertex;
					if (other.fetch(vertex))
					{
						vertices ~= vertex;
						if (clearSelect && foundSelect != -1)
							vertex.selected = false;
						if (select && (lastMouse - vertex.pos).length_squared < 20 * 20)
						{
							vertex.selected = !vertex.selected;
							select = false;
							foundSelect = entityNum;
						}
						if (vertex.selected && resetRelativeTo)
						{
							relativeTo = vertex.pos;
							resetRelativeTo = false;
						}
						if (vertex.selected && extend)
						{
							auto next = vertex.next.get!MapVertex;
							auto newV = world.newEntity("Extended")
								.add!MapVertex((vertex.pos + next.pos) * 0.5f,
										(vertex.width + next.width) * 0.5f, other, vertex.next, false, true).finalize();
							next.prev = newV;
							vertex.next = newV;
							vertex.selected = false;
							isDirty = true;
						}
						if (vertex.selected && deleteSelected)
						{
							vertex.prev.get!MapVertex.next = vertex.next;
							vertex.next.get!MapVertex.prev = vertex.prev;
							if (other == entity)
								entity = vertex.prev;
							other.alive = false;
							isDirty = true;
						}
						vec2 modPos = vertex.pos;
						float modWidth = vertex.width;
						if (mode == EditMode.grab && vertex.selected)
							modPos += lastMouse - relativeTo;
						if (mode == EditMode.width && vertex.selected)
							modWidth += (lastMouse - relativeTo).length * 0.01f - 1.0f;
						entityNum++;
						controlPoints ~= vec4(modPos, modWidth, vertex.selected ? 1 : 0);
						if (applyEdit)
						{
							vertex.pos = modPos;
							vertex.width = modWidth;
							isDirty = true;
						}
						if (vertex.selectNext)
						{
							vertex.selected = true;
							vertex.selectNext = false;
						}
						if (vertex.next == other)
							throw new Exception("Broken linked list (Cause: " ~ other.name ~ ")");
						other = vertex.next;
					}
					else
						throw new Exception("Invalid entity in linked list");
				}
				while (other != entity && other);
				break;
			}
		}
		if (foundSelect && clearSelect)
			for (ptrdiff_t i = 0; i < foundSelect; i++)
				vertices[i].selected = false;
		if (extend)
		{
			mode = EditMode.grab;
			relativeTo = lastMouse;
		}

		foreach (i, vec; controlPoints)
		{
			vec2 prev = controlPoints[(i + $ - 1) % $].xy;
			vec2 next = controlPoints[(i + 1) % $].xy;

			vec2 dirA = (prev - vec.xy).normalized;
			vec2 dirB = (vec.xy - next).normalized;

			vec2 avgDir = (dirA + dirB).normalized;
			vec2 ortho = vec2(-avgDir.y, avgDir.x);

			float uvX = (i % 2) == 0 ? 1 : 0;

			positions ~= vec.xy;
			texCoords ~= vec2(uvX, 0);
			selected ~= vec.a > 0.5f;
			positions ~= vec.xy - ortho * RoadWidth * vec.z;
			texCoords ~= vec2(uvX, 1);
			selected ~= vec.a > 0.5f;
		}
		positions ~= positions[0];
		texCoords ~= vec2((controlPoints.length % 2) == 0 ? 1 : 0, 0);
		selected ~= selected[0];
		positions ~= positions[1];
		texCoords ~= vec2((controlPoints.length % 2) == 0 ? 1 : 0, 1);
		selected ~= selected[1];

		renderer.projection.top = ortho3D(window.width / cast(float) window.height,
				-100.0f, 100.0f, 1.0f / zoom);
		renderer.modelview.push(mat4.xrotation(cradians!90) * mat4.translation(-offset.x,
				0, -offset.y));
		renderer.bind(editTexture);
		renderer.bind(testShader);
		renderer.drawMesh(test);
		mesh.fillPosition(positions);
		mesh.fillTexCoord(texCoords);
		mesh.fillSelected(selected);
		renderer.bind(editShader);
		mesh.vertexLength = cast(int) positions.length;
		renderer.drawMesh(mesh);
		renderer.modelview.pop();

		mouseWasDown = mouseDown;
		mouseWheelWasDown = mouseWheelDown;
		rightMouseWasDown = rightMouseDown;

		if (applyEdit)
			mode = EditMode.select;

		gWasDown = Keyboard.state.isKeyPressed(Key.G);
		wWasDown = Keyboard.state.isKeyPressed(Key.W);
		eWasDown = Keyboard.state.isKeyPressed(Key.E);
		delWasDown = Keyboard.state.isKeyPressed(Key.Delete);
		resetRelativeTo = false;
		extend = false;
		deleteSelected = false;

		renderer.bind2D();

		renderer.modelview.push(mat4.identity);
		if (exiting)
		{
			vec4 dialog = vec4(window.width * 0.5f - 200, window.height * 0.5f - 50, 400, 100);
			renderer.fillRectangle(dialog, vec4(0.216f, 0.278f, 0.31f, 1));
			renderer.modelview.push();
			text.text = "Are you sure you want to exit without saving?";
			renderer.modelview.top *= mat4.translation(window.width * 0.5f - 190,
					window.height * 0.5f - 10, 0) * mat4.scaling(768 * 0.5f, 512 * 0.5f, 1);
			text.draw(renderer);
			renderer.modelview.pop();
			if (Mouse.state.x >= dialog.x && Mouse.state.x <= dialog.x + dialog.z
					&& Mouse.state.y > window.height * 0.5f && Mouse.state.y <= dialog.y + dialog.a)
			{
				if (Mouse.state.x < window.width * 0.5f)
				{
					renderer.fillRectangle(vec4(window.width * 0.5f - 200,
							window.height * 0.5f, 200, 50), vec4(1, 1, 1, 0.5f));
					if (Mouse.state.isButtonPressed(1))
						sceneManager.setScene("main");
				}
				else
				{
					renderer.fillRectangle(vec4(window.width * 0.5f, window.height * 0.5f,
							200, 50), vec4(1, 1, 1, 0.5f));
					if (Mouse.state.isButtonPressed(1))
						exiting = false;
				}
			}
			renderer.modelview.push();
			text.text = "Discard Changes";
			renderer.modelview.top *= mat4.translation(window.width * 0.5f - 190,
					window.height * 0.5f + 40, 0) * mat4.scaling(768 * 0.5f, 512 * 0.5f, 1);
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			text.text = "Cancel";
			renderer.modelview.top *= mat4.translation(window.width * 0.5f + 10,
					window.height * 0.5f + 40, 0) * mat4.scaling(768 * 0.5f, 512 * 0.5f, 1);
			text.draw(renderer);
			renderer.modelview.pop();
		}
		else if (saving)
		{
			renderer.modelview.push();
			text.text = "Name: "d ~ name.to!dstring;
			renderer.modelview.top *= mat4.translation(window.width * 0.5f - text.textWidth * 768 * 0.5f,
					window.height * 0.5f, 0) * mat4.scaling(768, 512, 1);
			text.draw(renderer);
			renderer.modelview.pop();
		}
		else
		{
			vec4 sidebar = vec4(window.width - 200, 0, 200, window.height);
			renderer.fillRectangle(sidebar, vec4(0.216f, 0.278f, 0.31f, 1));

			if (mode == EditMode.select && Mouse.state.x >= window.width - 200)
			{
				if (Mouse.state.y < 64)
					renderer.fillRectangle(vec4(window.width - 200, 0, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 128)
					renderer.fillRectangle(vec4(window.width - 200, 64, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 192)
					renderer.fillRectangle(vec4(window.width - 200, 128, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 256)
					renderer.fillRectangle(vec4(window.width - 200, 192, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 320)
					renderer.fillRectangle(vec4(window.width - 200, 256, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 384)
					renderer.fillRectangle(vec4(window.width - 200, 320, 200, 64), vec4(1, 1, 1, 0.2f));
				else if (Mouse.state.y < 448)
					renderer.fillRectangle(vec4(window.width - 200, 384, 200, 64), vec4(1, 1, 1, 0.2f));
			}

			float x = window.width - 190;
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 48, 0) * mat4.scaling(768, 512, 1);
			text.text = "Save"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 112, 0) * mat4.scaling(768, 512, 1);
			text.text = "Test"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 176, 0) * mat4.scaling(768, 512, 1);
			text.text = "Exit"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 240, 0) * mat4.scaling(768, 512, 1);
			text.text = "Grab (G)"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 304, 0) * mat4.scaling(768, 512, 1);
			text.text = "Resize Width (W)"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 368, 0) * mat4.scaling(768, 512, 1);
			text.text = "Extend (E)"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.push();
			renderer.modelview.top *= mat4.translation(x, 432, 0) * mat4.scaling(768, 512, 1);
			text.text = "Delete"d;
			text.draw(renderer);
			renderer.modelview.pop();
			renderer.modelview.pop();
		}

		renderer.bind3D();
		renderer.end(window);
	}

	Track toTrack(string name = "Test Course")
	{
		Track track;
		foreach (p; controlPoints)
		{
			track.innerRing ~= p.xy;
			track.widths ~= p.z;
		}
		track.name = name;
		return track;
	}

	void saveTrack()
	{
		saving = false;
		firstSave = false;
		isDirty = false;
		if (!file)
		{
			int num;
			do
			{
				file = "res/maps/" ~ name.replaceAll(invalid, "_") ~ (num ? num.to!string : "") ~ ".map";
				num++;
			}
			while (file.exists);
		}
		ubyte[] data;
		data ~= cast(ubyte) name.length;
		data ~= cast(ubyte[]) name;
		data ~= (cast(uint) controlPoints.length).nativeToBigEndian;
		foreach (ctrl; controlPoints)
		{
			data ~= ctrl.x.nativeToBigEndian;
			data ~= ctrl.y.nativeToBigEndian;
			data ~= ctrl.z.nativeToBigEndian;
		}
		write(file, data);
	}

	string name = "";
	string file = null;
	bool firstSave = true;
private:
	Renderer renderer;
	View window;
	Text text;
	SceneManager sceneManager;
	Texture editTexture;
	Shader editShader, testShader;
	EditableMesh mesh;
	Mesh test;
	bool mouseDown, mouseWheelDown, rightMouseDown;
	bool mouseWasDown, mouseWheelWasDown, rightMouseWasDown;
	bool gWasDown, wWasDown, eWasDown, delWasDown;
	bool saving, exiting;
	bool resetRelativeTo, extend, deleteSelected;
	bool isDirty;
	EditMode mode;
	int zoom = 100;
	vec2 offset = vec2(0);
	vec2 lastMouse = vec2(0);
	vec2 relativeTo = vec2(0);
	vec4[] controlPoints;
}
