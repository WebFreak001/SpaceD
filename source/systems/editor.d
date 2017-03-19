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
	scale,
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
			if (mode == EditMode.select && ev.x >= window.width - 200 && mouseDown)
			{
				if (ev.y < 64)
				{

				}
				else if (ev.y < 128)
					sceneManager.setScene("ingame");
				else if (ev.y < 192)
				{

				}
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

	void update(World world)
	{
		renderer.begin(window);
		renderer.enableBlend();
		renderer.clear();

		vec2[] positions;
		vec2[] texCoords;
		int[] selected;

		bool applyEdit;
		bool resetRelativeTo;
		bool extend, deleteSelected;
		if (Keyboard.state.isKeyPressed(Key.G) && !gWasDown)
		{
			mode = EditMode.grab;
			relativeTo = lastMouse;
		}
		else if (Keyboard.state.isKeyPressed(Key.S) && !sWasDown)
		{
			mode = EditMode.scale;
			resetRelativeTo = true;
		}
		else if (Keyboard.state.isKeyPressed(Key.W) && !wWasDown)
		{
			mode = EditMode.width;
			resetRelativeTo = true;
		}
		else if (Keyboard.state.isKeyPressed(Key.E) && !eWasDown)
			extend = true;
		else if (Keyboard.state.isKeyPressed(Key.Delete) && !delWasDown)
			deleteSelected = true;
		if (!rightMouseDown && rightMouseWasDown)
			mode = EditMode.select;
		if (!mouseDown && mouseWasDown)
			applyEdit = true;

		bool select = rightMouseDown && !rightMouseWasDown && mode == EditMode.select;
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
						}
						if (vertex.selected && deleteSelected)
						{
							vertex.prev.get!MapVertex.next = vertex.next;
							vertex.next.get!MapVertex.prev = vertex.prev;
							if (other == entity)
								entity = vertex.prev;
							other.alive = false;
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
		sWasDown = Keyboard.state.isKeyPressed(Key.S);
		wWasDown = Keyboard.state.isKeyPressed(Key.W);
		eWasDown = Keyboard.state.isKeyPressed(Key.E);
		delWasDown = Keyboard.state.isKeyPressed(Key.Delete);

		renderer.bind2D();

		renderer.modelview.push(mat4.identity);
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
		renderer.modelview.pop();

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
	bool gWasDown, sWasDown, wWasDown, eWasDown, delWasDown;
	EditMode mode;
	int zoom = 100;
	vec2 offset = vec2(0);
	vec2 lastMouse = vec2(0);
	vec2 relativeTo = vec2(0);
	vec4[] controlPoints;
}
