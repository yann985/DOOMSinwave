// =============================================================================
//  Définitions de données (l'équivalent des ScriptableObject d'Unity).
// =============================================================================
//
//  Chaque classe est un simple conteneur construit depuis un bloc de data/*.txt.
//  Aucune logique de jeu ici : les systèmes lisent ces définitions et décident
//  quoi en faire. Les erreurs de saisie sont signalées au chargement.

// Recherche de classes du moteur à partir d'un nom écrit dans un fichier.
class Sinwave_ClassLookup play
{
	static class<Actor> FindActor(Sinwave_DataBlock block, String className)
	{
		Name typeName = className;
		let type = (class<Actor>)(typeName);
		if (type == null) block.Warn(String.Format("classe d'acteur inconnue : \"%s\"", className));
		return type;
	}

	static class<Inventory> FindItem(Sinwave_DataBlock block, String className)
	{
		Name typeName = className;
		let type = (class<Inventory>)(typeName);
		if (type == null) block.Warn(String.Format("objet inconnu : \"%s\"", className));
		return type;
	}
}

// Un objet donné au joueur, écrit « Shotgun » ou « Shell:20 ».
class Sinwave_ItemStack play
{
	class<Inventory> mType;
	int mAmount;

	static void ParseList(Sinwave_DataBlock block, String key, out Array<Sinwave_ItemStack> result)
	{
		result.Clear();
		Array<String> entries;
		block.GetList(key, entries);
		for (int i = 0; i < entries.Size(); i++)
		{
			Array<String> parts;
			entries[i].Split(parts, ":");
			String className = parts[0];
			className.StripLeftRight();
			let type = Sinwave_ClassLookup.FindItem(block, className);
			if (type == null) continue;

			let stack = new('Sinwave_ItemStack');
			stack.mType = type;
			stack.mAmount = parts.Size() > 1 ? max(1, parts[1].ToInt(10)) : 1;
			result.Push(stack);
		}
	}
}

// Un effet appliqué au joueur, partagé par les améliorations et les déblocages.
class Sinwave_Effect play
{
	Name mType;					// voir IsKnownType()
	double mValue;
	class<Inventory> mItem;		// pour l'effet « give »
	int mAmount;

	static Sinwave_Effect FromBlock(Sinwave_DataBlock block)
	{
		let effect = new('Sinwave_Effect');
		effect.mType = block.GetString("effect");
		effect.mValue = block.GetDouble("value");
		effect.mAmount = max(1, block.GetInt("amount", 1));
		if (!IsKnownType(effect.mType))
		{
			block.Warn(String.Format("effet inconnu : \"%s\"", effect.mType));
		}
		if (effect.mType == 'give')
		{
			effect.mItem = Sinwave_ClassLookup.FindItem(block, block.GetString("item"));
		}
		return effect;
	}

	// Effets reconnus. Chacun est appliqué par un seul système :
	//   Sinwave_PlayerSystem : maxhealth, heal, armor, damage, speed, regen, give
	//   Sinwave_XpSystem     : magnet, xpgain
	static bool IsKnownType(Name type)
	{
		switch (type)
		{
		case 'maxhealth':
		case 'heal':
		case 'armor':
		case 'damage':
		case 'speed':
		case 'regen':
		case 'give':
		case 'magnet':
		case 'xpgain':
			return true;
		}
		return false;
	}
}

// Un type d'ennemi (data/enemies.txt) : un péché capital.
class Sinwave_EnemyDef play
{
	Name mId;
	String mName;
	class<Actor> mActor;
	double mHealthFactor;
	double mSpeedFactor;
	int mXp;
	int mScore;

	static Sinwave_EnemyDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_EnemyDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mActor = Sinwave_ClassLookup.FindActor(block, block.GetString("actor"));
		def.mHealthFactor = max(0.05, block.GetDouble("health", 1.0));
		def.mSpeedFactor = max(0.05, block.GetDouble("speed", 1.0));
		def.mXp = max(0, block.GetInt("xp", 1));
		def.mScore = max(0, block.GetInt("score", 10));
		return def.mActor != null ? def : null;
	}
}

// Une vague d'ennemis (data/waves.txt).
class Sinwave_WaveDef play
{
	Name mId;
	String mName;
	int mDurationTics;
	int mIntervalTics;
	int mMaxAlive;
	int mBreakTics;
	Array<Name> mEnemyIds;
	Array<int> mWeights;
	int mTotalWeight;

	static Sinwave_WaveDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_WaveDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDurationTics = SecondsToTics(block.GetDouble("duration", 60));
		def.mIntervalTics = max(1, SecondsToTics(block.GetDouble("interval", 1)));
		def.mMaxAlive = max(1, block.GetInt("max", 10));
		def.mBreakTics = SecondsToTics(block.GetDouble("break", 5));

		// « sloth:3, gluttony:2 » : identifiant d'ennemi et poids du tirage.
		Array<String> entries;
		block.GetList("enemies", entries);
		for (int i = 0; i < entries.Size(); i++)
		{
			Array<String> parts;
			entries[i].Split(parts, ":");
			String id = parts[0];
			id.StripLeftRight();
			int weight = parts.Size() > 1 ? parts[1].ToInt(10) : 1;
			if (weight <= 0) continue;
			def.mEnemyIds.Push(id.MakeLower());
			def.mWeights.Push(weight);
			def.mTotalWeight += weight;
		}
		if (def.mDurationTics <= 0) block.Warn("durée nulle.");
		return def;
	}

	// Tire un type d'ennemi selon les poids. `roll` est compris entre 0 et mTotalWeight - 1.
	Name PickEnemy(int roll)
	{
		for (int i = 0; i < mEnemyIds.Size(); i++)
		{
			roll -= mWeights[i];
			if (roll < 0) return mEnemyIds[i];
		}
		return mEnemyIds.Size() > 0 ? mEnemyIds[0] : 'None';
	}

	void RemoveEnemyAt(int index)
	{
		mTotalWeight -= mWeights[index];
		mEnemyIds.Delete(index);
		mWeights.Delete(index);
	}

	static int SecondsToTics(double seconds)
	{
		return int(seconds * TICRATE + 0.5);
	}
}

// Une amélioration proposée à la montée de niveau (data/upgrades.txt).
class Sinwave_UpgradeDef play
{
	Name mId;
	String mName;
	String mDescription;
	int mMaxStacks;
	Sinwave_Effect mEffect;

	static Sinwave_UpgradeDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_UpgradeDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		def.mMaxStacks = max(1, block.GetInt("max", 1));
		def.mEffect = Sinwave_Effect.FromBlock(block);
		return def;
	}
}

// Un déblocage permanent de méta-progression (data/unlocks.txt).
class Sinwave_UnlockDef play
{
	Name mId;
	String mName;
	int mSoulsRequired;
	Sinwave_Effect mEffect;

	static Sinwave_UnlockDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_UnlockDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mSoulsRequired = max(0, block.GetInt("souls", 0));
		def.mEffect = Sinwave_Effect.FromBlock(block);
		return def;
	}
}

// Réglages généraux de progression (data/progression.txt).
class Sinwave_ProgressionDef play
{
	int mXpFirstLevel;
	double mXpGrowth;
	int mUpgradeChoices;
	double mMagnetRadius;
	int mSoulsPerScore;
	int mSoulsPerWave;
	int mSoulsVictory;
	Array<Sinwave_ItemStack> mStartItems;
	int mSupplyTics;
	Array<Sinwave_ItemStack> mSupplyItems;

	// `block` peut être null : on garde alors les valeurs par défaut.
	static Sinwave_ProgressionDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_ProgressionDef');
		if (block == null) block = new('Sinwave_DataBlock');
		def.mXpFirstLevel = max(1, block.GetInt("xp_first_level", 5));
		def.mXpGrowth = max(1.0, block.GetDouble("xp_growth", 1.5));
		def.mUpgradeChoices = max(1, block.GetInt("upgrade_choices", 3));
		def.mMagnetRadius = max(0.0, block.GetDouble("magnet_radius", 192));
		def.mSoulsPerScore = max(1, block.GetInt("souls_per_score", 20));
		def.mSoulsPerWave = max(0, block.GetInt("souls_per_wave", 3));
		def.mSoulsVictory = max(0, block.GetInt("souls_victory", 10));
		def.mSupplyTics = Sinwave_WaveDef.SecondsToTics(block.GetDouble("supply_seconds", 0));
		Sinwave_ItemStack.ParseList(block, "start_items", def.mStartItems);
		Sinwave_ItemStack.ParseList(block, "supply_items", def.mSupplyItems);
		return def;
	}
}

// Un système à instancier au lancement (data/systems.txt).
class Sinwave_SystemDef play
{
	Name mId;
	class<Sinwave_System> mClass;
	bool mEnabled;

	static Sinwave_SystemDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_SystemDef');
		def.mId = block.mId;
		def.mEnabled = block.GetBool("enabled", true);
		Name className = block.GetString("class");
		def.mClass = (class<Sinwave_System>)(className);
		if (def.mClass == null)
		{
			block.Warn(String.Format("classe de système inconnue : \"%s\"", className));
			return null;
		}
		return def;
	}
}
