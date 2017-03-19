module globstate;

import std.file;
import std.math;
import std.bitmanip;
import std.digest.crc;
import std.json;
import std.conv;

import avocado.sdl2;
import components;

enum SymmetricKey = "lol security";

struct GlobalState
{
	uint money;
	ulong bestTime;
	ubyte[32] reserved;
	struct Upgrades
	{
		ubyte boostLevel;
		ubyte betterControls;
	}

	union
	{
		Upgrades upgrades;
		ubyte[Upgrades.sizeof] binUpgrades;
	}

	int upgradeCost(int upgrade)
	{
		int baseCost = 100;
		if (upgrade == 1)
			baseCost = 300;
		return cast(int)(baseCost * pow(1.5f, binUpgrades[upgrade]));
	}

	void save()
	{
		ubyte[] serialized;
		serialized ~= money.nativeToBigEndian;
		serialized ~= bestTime.nativeToBigEndian;
		serialized ~= reserved;
		serialized ~= binUpgrades;
		serialized ~= crc32Of(serialized)[];
		foreach (i, ref b; serialized)
			b += cast(ubyte) SymmetricKey[i % $];
		write(".savegame", serialized);
	}

	void load()
	{
		if (exists(".savegame"))
		{
			ubyte[] serialized = cast(ubyte[]) read(".savegame");
			foreach (i, ref b; serialized)
				b -= cast(ubyte) SymmetricKey[i % $];
			if (serialized.length < 4)
				return;
			if (crc32Of(serialized[0 .. $ - 4]) != serialized[$ - 4 .. $])
			{
				import std.stdio;

				writeln("Invalid checksum");
				return;
			}
			serialized.length -= 4;
			size_t index;
			if (index + 4 >= serialized.length)
				return;
			money = serialized.peek!uint(&index);
			if (serialized.length < 40)
				return;
			bestTime = serialized.peek!ulong(&index);
			index += 32;
			binUpgrades[0 .. serialized.length - 44] = serialized[44 .. $];
		}
	}
}

__gshared GlobalState globalState;

struct PlayerSettings
{
	PlayerControls.ControlScheme controls;

	void save()
	{
		//dfmt off
		write("config.json", JSONValue([
			"controls": JSONValue([
				"accelerate": JSONValue(controls.accelerate.to!string),
				"steerLeft": JSONValue(controls.steerLeft.to!string),
				"decelerate": JSONValue(controls.decelerate.to!string),
				"steerRight": JSONValue(controls.steerRight.to!string),
				"boost": JSONValue(controls.boost.to!string),
				"lookBack": JSONValue(controls.lookBack.to!string)
			])
		]).toPrettyString);
		//dfmt on
	}

	static PlayerSettings load()
	{
		if (exists("config.json"))
		{
			auto json = parseJSON(readText("config.json"));
			PlayerSettings set;
			set.controls.accelerate = json["controls"]["accelerate"].str.to!Key;
			set.controls.steerLeft = json["controls"]["steerLeft"].str.to!Key;
			set.controls.decelerate = json["controls"]["decelerate"].str.to!Key;
			set.controls.steerRight = json["controls"]["steerRight"].str.to!Key;
			set.controls.boost = json["controls"]["boost"].str.to!Key;
			set.controls.lookBack = json["controls"]["lookBack"].str.to!Key;
			return set;
		}
		else
			return PlayerSettings.init;
	}
}

__gshared PlayerSettings settings;
