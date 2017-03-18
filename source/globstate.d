module globstate;

import std.file;
import std.math;
import std.bitmanip;
import std.digest.crc;

enum SymmetricKey = "lol security";

struct GlobalState
{
	uint money;
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
			binUpgrades[0 .. serialized.length - 4] = serialized[4 .. $];
		}
	}
}

__gshared GlobalState globalState;
