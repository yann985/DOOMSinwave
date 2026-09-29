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

// Un effet appliqué au joueur. Utilisé par les vertus, les péchés, les articles de
// la boutique et certaines malédictions. Écrit « damage:0.4 », « give:Shotgun »
// ou « give:Shell:20 ».
class Sinwave_Effect play
{
	Name mType;					// voir IsKnownType()
	double mValue;
	class<Inventory> mItem;		// pour « give »
	Name mItemName;
	int mAmount;

	static Sinwave_Effect Create(Name type, double value)
	{
		let effect = new('Sinwave_Effect');
		effect.mType = type;
		effect.mValue = value;
		effect.mAmount = 1;
		return effect;
	}

	static Sinwave_Effect Parse(Sinwave_DataBlock block, String spec)
	{
		Array<String> parts;
		spec.Split(parts, ":");
		for (int i = 0; i < parts.Size(); i++) parts[i].StripLeftRight();

		let effect = Create(parts[0].MakeLower(), 0);
		if (!IsKnownType(effect.mType))
		{
			block.Warn(String.Format("effet inconnu : \"%s\"", spec));
			return null;
		}
		if (parts.Size() < 2)
		{
			block.Warn(String.Format("valeur manquante : \"%s\"", spec));
			return null;
		}
		if (effect.mType == 'give')
		{
			effect.mItem = Sinwave_ClassLookup.FindItem(block, parts[1]);
			if (effect.mItem == null) return null;
			effect.mItemName = parts[1];
			if (parts.Size() > 2) effect.mAmount = max(1, parts[2].ToInt(10));
		}
		else
		{
			effect.mValue = parts[1].ToDouble();
		}
		return effect;
	}

	// « damage:0.4, speed:-0.1 » : plusieurs effets séparés par des virgules.
	static void ParseList(Sinwave_DataBlock block, String key, out Array<Sinwave_Effect> result)
	{
		result.Clear();
		Array<String> specs;
		block.GetList(key, specs);
		for (int i = 0; i < specs.Size(); i++)
		{
			let effect = Parse(block, specs[i]);
			if (effect != null) result.Push(effect);
		}
	}

	// Effets reconnus. Chacun est appliqué par un seul système :
	//   Sinwave_PlayerSystem : maxhealth, heal, armor, damage, vulnerability, speed, regen, give
	//   Sinwave_XpSystem     : magnet, xpgain
	static bool IsKnownType(Name type)
	{
		switch (type)
		{
		case 'maxhealth':
		case 'heal':
		case 'armor':
		case 'damage':
		case 'vulnerability':
		case 'speed':
		case 'regen':
		case 'give':
		case 'magnet':
		case 'xpgain':
			return true;
		}
		return false;
	}

	String Describe()
	{
		if (mType == 'give') return String.Format("give %s x%d", mItemName, mAmount);
		return String.Format("%s %.2f", mType, mValue);
	}
}

// Un type d'ennemi (data/enemies.txt) : un péché capital, ou un boss.
class Sinwave_EnemyDef play
{
	Name mId;
	String mName;
	class<Actor> mActor;
	double mHealthFactor;
	double mSpeedFactor;
	double mScale;
	int mXp;
	int mScore;

	// Boss : rage quand ses PV passent sous mRageAt (fraction), avec renforts.
	bool mIsBoss;
	double mRageAt;
	double mRageSpeed;
	Name mRageSummonId;
	int mRageSummonCount;

	static Sinwave_EnemyDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_EnemyDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mActor = Sinwave_ClassLookup.FindActor(block, block.GetString("actor"));
		def.mHealthFactor = max(0.05, block.GetDouble("health", 1.0));
		def.mSpeedFactor = max(0.05, block.GetDouble("speed", 1.0));
		def.mScale = max(0.1, block.GetDouble("scale", 1.0));
		def.mXp = max(0, block.GetInt("xp", 1));
		def.mScore = max(0, block.GetInt("score", 10));

		def.mIsBoss = block.GetBool("boss");
		def.mRageAt = clamp(block.GetDouble("rage_at", 0), 0.0, 1.0);
		def.mRageSpeed = max(0.1, block.GetDouble("rage_speed", 1.0));
		Array<String> summon;
		block.GetList("rage_summon", summon);
		if (summon.Size() > 0)
		{
			Array<String> parts;
			summon[0].Split(parts, ":");
			def.mRageSummonId = parts[0].MakeLower();
			def.mRageSummonCount = parts.Size() > 1 ? max(1, parts[1].ToInt(10)) : 1;
		}
		return def.mActor != null ? def : null;
	}
}

// Une malédiction de cercle (data/curses.txt). Son comportement est une classe
// ZScript (pattern Stratégie) ; ses réglages restent dans le bloc de données.
class Sinwave_CurseDef play
{
	Name mId;
	String mName;
	String mDescription;
	Name mClassName;
	Sinwave_DataBlock mParams;

	static Sinwave_CurseDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_CurseDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		def.mClassName = block.GetString("class");
		def.mParams = block;
		if ((class<Object>)(def.mClassName) == null)
		{
			block.Warn(String.Format("classe de malédiction inconnue : \"%s\"", def.mClassName));
			return null;
		}
		return def;
	}
}

// Une vague : un cercle du Purgatoire (data/waves/*.txt).
class Sinwave_WaveDef play
{
	Name mId;
	String mName;
	int mDurationTics;		// 0 : la vague dure jusqu'à la mort du boss
	int mIntervalTics;
	int mMaxAlive;
	int mBreakTics;
	Name mCurseId;
	Name mBossId;
	Array<Name> mEnemyIds;
	Array<int> mWeights;
	int mTotalWeight;

	static Sinwave_WaveDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_WaveDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDurationTics = max(0, block.GetTics("duration", 30));
		def.mIntervalTics = max(1, block.GetTics("interval", 1));
		def.mMaxAlive = max(1, block.GetInt("max", 10));
		def.mBreakTics = max(0, block.GetTics("break", 3));
		def.mCurseId = block.GetString("curse").MakeLower();
		def.mBossId = block.GetString("boss").MakeLower();

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
		if (def.mDurationTics == 0 && def.mBossId == 'None')
		{
			block.Warn("une vague sans durée doit avoir un boss.");
		}
		return def;
	}

	bool HasBoss()
	{
		return mBossId != 'None' && mBossId != '';
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
}

// Une amélioration proposée à la montée de niveau (data/upgrades.txt) :
// une vertu (sûre) ou un péché (puissant, avec un défaut, et qui corrompt).
class Sinwave_UpgradeDef play
{
	Name mId;
	String mName;
	String mDescription;
	bool mIsSin;
	int mCorruption;
	int mMaxStacks;
	Array<Sinwave_Effect> mEffects;

	static Sinwave_UpgradeDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_UpgradeDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		String kind = block.GetString("kind", "virtue").MakeLower();
		if (kind != "virtue" && kind != "sin") block.Warn("kind doit valoir virtue ou sin.");
		def.mIsSin = kind == "sin";
		def.mCorruption = block.GetInt("corruption", 0);
		def.mMaxStacks = max(1, block.GetInt("max", 1));
		Sinwave_Effect.ParseList(block, "effects", def.mEffects);
		return def;
	}
}

// Un article de la boutique des indulgences (data/shop.txt) : une arme ou une
// amélioration permanente, achetée entre les runs et appliquée au début de chacune.
class Sinwave_ShopItemDef play
{
	Name mId;
	String mName;
	String mDescription;
	bool mIsWeapon;
	int mPrice;
	double mPriceGrowth;
	int mMaxLevel;
	Array<Sinwave_Effect> mEffects;

	static Sinwave_ShopItemDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_ShopItemDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		def.mIsWeapon = block.GetString("category").MakeLower() == "weapon";
		def.mPrice = max(0, block.GetInt("price", 10));
		def.mPriceGrowth = max(1.0, block.GetDouble("price_growth", 1.0));
		def.mMaxLevel = max(1, block.GetInt("max", 1));
		Sinwave_Effect.ParseList(block, "effects", def.mEffects);
		return def;
	}

	// Prix du niveau suivant, quand on possède déjà `level` niveaux.
	int PriceForLevel(int level)
	{
		return int(mPrice * (mPriceGrowth ** level) + 0.5);
	}
}

// Une arène jouable (data/arenas.txt) : une carte, ses vagues et ses règles.
class Sinwave_ArenaDef play
{
	Name mId;
	String mName;
	String mDescription;
	String mMap;
	String mWavesFile;
	double mEnemyHealth;
	double mEnemySpeed;
	double mSpawnRate;
	double mRewardFactor;
	bool mSpawnAroundPlayer;	// vrai : autour du joueur ; faux : points d'apparition de la carte
	Array<String> mCircleNames;

	// Arène neutre, utilisée si data/arenas.txt est vide ou absent.
	static Sinwave_ArenaDef Neutral()
	{
		let def = new('Sinwave_ArenaDef');
		def.mName = "Arène sans nom";
		def.mEnemyHealth = 1;
		def.mEnemySpeed = 1;
		def.mSpawnRate = 1;
		def.mRewardFactor = 1;
		def.mSpawnAroundPlayer = true;
		return def;
	}

	static Sinwave_ArenaDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_ArenaDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		def.mMap = block.GetString("map").MakeUpper();
		def.mWavesFile = block.GetString("waves");
		def.mEnemyHealth = max(0.1, block.GetDouble("enemy_health", 1.0));
		def.mEnemySpeed = max(0.1, block.GetDouble("enemy_speed", 1.0));
		def.mSpawnRate = max(0.1, block.GetDouble("spawn_rate", 1.0));
		def.mRewardFactor = max(0.0, block.GetDouble("reward", 1.0));
		String spawn = block.GetString("spawn", "player").MakeLower();
		if (spawn != "player" && spawn != "points") block.Warn("spawn doit valoir player ou points.");
		def.mSpawnAroundPlayer = spawn != "points";
		if (def.mMap.Length() == 0 || def.mWavesFile.Length() == 0)
		{
			block.Warn("une arène doit indiquer « map » et « waves ».");
			return null;
		}
		return def;
	}
}

// Réglages généraux de progression (data/progression.txt).
class Sinwave_ProgressionDef play
{
	int mXpFirstLevel;
	double mXpGrowth;
	int mOfferVirtues;
	int mOfferSins;
	double mMagnetRadius;
	int mDamnationThreshold;
	int mIndulgencesPerScore;
	int mIndulgencesPerCircle;
	int mIndulgencesAbsolution;
	int mIndulgencesDamnation;
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
		def.mOfferVirtues = max(0, block.GetInt("offer_virtues", 2));
		def.mOfferSins = max(0, block.GetInt("offer_sins", 1));
		def.mMagnetRadius = max(0.0, block.GetDouble("magnet_radius", 192));
		def.mDamnationThreshold = max(1, block.GetInt("damnation_threshold", 5));
		def.mIndulgencesPerScore = max(1, block.GetInt("indulgences_per_score", 20));
		def.mIndulgencesPerCircle = max(0, block.GetInt("indulgences_per_circle", 2));
		def.mIndulgencesAbsolution = max(0, block.GetInt("indulgences_absolution", 20));
		def.mIndulgencesDamnation = max(0, block.GetInt("indulgences_damnation", 5));
		def.mSupplyTics = block.GetTics("supply_seconds", 0);
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
