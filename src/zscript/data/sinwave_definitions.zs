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
	//   Sinwave_PlayerSystem : maxhealth, heal, armor, damage, vulnerability, speed,
	//                          regen, give, aura, infiniteammo
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
		case 'aura':
		case 'infiniteammo':
		case 'magnet':
		case 'xpgain':
			return true;
		}
		return false;
	}

	// L'effet inverse, pour retirer un effet temporaire (palier de l'âme...).
	// Un objet donné, des soins ou de l'armure ne se reprennent pas : null.
	Sinwave_Effect Negated()
	{
		if (mType == 'give' || mType == 'heal' || mType == 'armor') return null;
		return Create(mType, -mValue);
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
	Name mTranslation;		// teinte (TRNSLATE), ou 'None'

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
		def.mTranslation = block.GetString("translation");

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

// Un cercle de l'arène (data/waves/*.txt) : un péché, sa malédiction, et
// plusieurs vagues d'ennemis de plus en plus serrées. Les réglages du bloc sont
// ceux de la première vague ; les suivantes accélèrent selon data/progression.txt.
// Avec un boss, la dernière vague est la sienne et dure jusqu'à sa mort.
class Sinwave_CircleDef play
{
	Name mId;
	String mName;
	int mWaveCount;
	int mWaveTics;			// durée d'une vague
	int mPauseTics;			// répit entre deux vagues du cercle
	int mBreakTics;			// répit avant le cercle suivant
	int mIntervalTics;		// entre deux apparitions, à la première vague
	int mMaxAlive;			// ennemis vivants au maximum, à la première vague
	Name mCurseId;
	Name mBossId;
	Array<Name> mEnemyIds;
	Array<int> mWeights;
	int mTotalWeight;

	static Sinwave_CircleDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_CircleDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mWaveCount = max(1, block.GetInt("waves", 3));
		def.mWaveTics = max(1, block.GetTics("duration", 8));
		def.mPauseTics = max(1, block.GetTics("pause", 2));
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
		return def;
	}

	bool HasBoss()
	{
		return mBossId != 'None' && mBossId != '';
	}

	// Vague du boss : la dernière du cercle. Elle dure jusqu'à la mort du boss.
	bool IsBossWave(int wave)
	{
		return HasBoss() && wave == mWaveCount - 1;
	}

	// Durée de la vague, en tics (0 : jusqu'à la mort du boss).
	int WaveTics(int wave)
	{
		return IsBossWave(wave) ? 0 : mWaveTics;
	}

	// Montée en difficulté à l'intérieur du cercle : chaque vague fait apparaître
	// les ennemis `spawnGrowth` fois plus vite (0,15 : +15 %) que la première...
	int IntervalTicsForWave(int wave, double spawnGrowth)
	{
		return max(1, int(mIntervalTics / (1.0 + spawnGrowth * wave) + 0.5));
	}

	// ... et autorise `maxGrowth` ennemis vivants de plus.
	int MaxAliveForWave(int wave, int maxGrowth)
	{
		return mMaxAlive + maxGrowth * wave;
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
	// Rayons de la boutique (dans l'ordre des onglets).
	enum ESide
	{
		SIDE_ARMORY,		// toujours ouvert
		SIDE_GRACE,			// ouvert quand le Jugement penche vers la grâce
		SIDE_NEUTRAL,		// ouvert près de la neutralité
		SIDE_CORRUPTION,	// ouvert quand il penche vers la corruption
		NUM_SIDES
	}

	Name mId;
	String mName;
	String mDescription;
	bool mIsWeapon;
	int mSide;
	int mTier;				// palier du Jugement demandé (Grâce ou Corruption 1 à 3)
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
		String side = block.GetString("side", "armory").MakeLower();
		if (side == "grace") def.mSide = SIDE_GRACE;
		else if (side == "neutral") def.mSide = SIDE_NEUTRAL;
		else if (side == "corruption") def.mSide = SIDE_CORRUPTION;
		else
		{
			if (side != "armory") block.Warn("side doit valoir armory, grace, neutral ou corruption.");
			def.mSide = SIDE_ARMORY;
		}
		def.mTier = clamp(block.GetInt("tier", 1), 1, 3);
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

// Le Jugement (data/judgement.txt) : la réputation de l'âme, gardée d'une run à
// l'autre. Une balance de mMin (Grâce) à mMax (Corruption), neutre au milieu. Il
// décide des rayons ouverts de la boutique et bouge à la fin de chaque run.
class Sinwave_JudgementDef play
{
	int mMin;
	int mMax;
	int mNeutral;
	int mNeutralZone;
	Array<int> mGraceTiers;			// seuils de Grâce I, II, III (au plus)
	Array<int> mCorruptionTiers;	// seuils de Corruption I, II, III (au moins)
	Array<int> mRunShift;			// déplacement selon le palier de l'âme atteint
	int mBalancePull;

	// `block` peut être null : valeurs par défaut.
	static Sinwave_JudgementDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_JudgementDef');
		if (block == null) block = new('Sinwave_DataBlock');
		def.mMin = block.GetInt("min", 0);
		def.mMax = max(def.mMin + 2, block.GetInt("max", 100));
		def.mNeutral = clamp(block.GetInt("neutral", 50), def.mMin + 1, def.mMax - 1);
		def.mNeutralZone = max(0, block.GetInt("neutral_zone", 15));
		ReadInts(block, "grace_tiers", "40, 25, 10", def.mGraceTiers);
		ReadInts(block, "corruption_tiers", "60, 75, 90", def.mCorruptionTiers);
		ReadInts(block, "run_shift", "6, 10, 15", def.mRunShift);
		def.mBalancePull = max(0, block.GetInt("balance_pull", 4));
		return def;
	}

	private static void ReadInts(Sinwave_DataBlock block, String key, String fallback, out Array<int> result)
	{
		result.Clear();
		Array<String> parts;
		String text = block.GetString(key, fallback);
		text.Split(parts, ",");
		for (int i = 0; i < parts.Size(); i++)
		{
			parts[i].StripLeftRight();
			if (parts[i].Length() > 0) result.Push(parts[i].ToInt(10));
		}
	}

	// Palier du Jugement : +1 à +3 côté Corruption, -1 à -3 côté Grâce, 0 sinon.
	int Tier(int judgement)
	{
		for (int i = mCorruptionTiers.Size() - 1; i >= 0; i--)
		{
			if (judgement >= mCorruptionTiers[i]) return i + 1;
		}
		for (int i = mGraceTiers.Size() - 1; i >= 0; i--)
		{
			if (judgement <= mGraceTiers[i]) return -(i + 1);
		}
		return 0;
	}

	static String TierName(int tier)
	{
		static const String NUMBERS[] = { "I", "II", "III" };
		if (tier == 0) return "Neutralité";
		return String.Format("%s %s", tier > 0 ? "Corruption" : "Grâce", NUMBERS[clamp(abs(tier), 1, 3) - 1]);
	}

	bool IsNeutral(int judgement)
	{
		return abs(judgement - mNeutral) <= mNeutralZone;
	}

	// L'article est-il en vente pour ce Jugement ?
	bool IsUnlocked(Sinwave_ShopItemDef item, int judgement)
	{
		switch (item.mSide)
		{
		case Sinwave_ShopItemDef.SIDE_GRACE:
			return item.mTier <= mGraceTiers.Size() && judgement <= mGraceTiers[item.mTier - 1];
		case Sinwave_ShopItemDef.SIDE_CORRUPTION:
			return item.mTier <= mCorruptionTiers.Size() && judgement >= mCorruptionTiers[item.mTier - 1];
		case Sinwave_ShopItemDef.SIDE_NEUTRAL:
			return IsNeutral(judgement);
		}
		return true;
	}

	// Achetable : en vente, ou déjà acheté une fois (débloqué pour toujours).
	bool CanBuy(Sinwave_ShopItemDef item, int judgement, int level)
	{
		return level > 0 || IsUnlocked(item, judgement);
	}

	// Ce qu'il faut pour débloquer l'article.
	String Requirement(Sinwave_ShopItemDef item)
	{
		switch (item.mSide)
		{
		case Sinwave_ShopItemDef.SIDE_GRACE:
			if (item.mTier > mGraceTiers.Size()) return "";
			return String.Format("%s : Jugement %d ou moins", TierName(-item.mTier), mGraceTiers[item.mTier - 1]);
		case Sinwave_ShopItemDef.SIDE_CORRUPTION:
			if (item.mTier > mCorruptionTiers.Size()) return "";
			return String.Format("%s : Jugement %d ou plus", TierName(item.mTier), mCorruptionTiers[item.mTier - 1]);
		case Sinwave_ShopItemDef.SIDE_NEUTRAL:
			return String.Format("Neutralité : Jugement entre %d et %d", mNeutral - mNeutralZone, mNeutral + mNeutralZone);
		}
		return "";
	}

	// Jugement après une run, selon le côté et le palier de l'âme à la fin :
	// plus l'âme a penché, plus il bouge ; sans palier, il revient vers le neutre.
	int AfterRun(int judgement, int soulSide, int soulLevel)
	{
		if (soulSide == 0 || soulLevel <= 0)
		{
			if (judgement > mNeutral) return max(mNeutral, judgement - mBalancePull);
			return min(mNeutral, judgement + mBalancePull);
		}
		int shift = mRunShift.Size() > 0 ? mRunShift[clamp(soulLevel, 1, mRunShift.Size()) - 1] : 0;
		return clamp(judgement + soulSide * shift, mMin, mMax);
	}
}

// Une arène jouable (data/arenas.txt) : une carte, ses cercles et ses règles.
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

// Un palier de la balance de l'âme (data/soul.txt) : atteint quand l'âme penche
// assez d'un côté ; ses effets durent tant qu'il reste atteint.
class Sinwave_SoulTierDef play
{
	Name mId;
	String mName;
	String mDescription;
	int mSide;					// +1 : péché ; -1 : vertu
	int mAt;					// valeur de l'âme qui déclenche le palier
	Array<Sinwave_Effect> mEffects;
	double mHealthDrop;			// chance de butin ajoutée, en %
	double mAmmoDrop;
	int mTemptation;			// choix de niveau tirés vers ce camp
	double mBossHealth;			// vie du boss : +0.15 = +15 %
	double mBossEscort;			// ennemis autour du boss : +0.2 = +20 %

	static Sinwave_SoulTierDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_SoulTierDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		String side = block.GetString("side").MakeLower();
		if (side != "sin" && side != "virtue")
		{
			block.Warn("side doit valoir sin ou virtue.");
			return null;
		}
		def.mSide = side == "sin" ? 1 : -1;
		def.mAt = block.GetInt("at", 0);
		Sinwave_Effect.ParseList(block, "effects", def.mEffects);
		def.mHealthDrop = block.GetDouble("health_drop", 0);
		def.mAmmoDrop = block.GetDouble("ammo_drop", 0);
		def.mTemptation = max(0, block.GetInt("temptation", 0));
		def.mBossHealth = block.GetDouble("boss_health", 0);
		def.mBossEscort = block.GetDouble("boss_escort", 0);
		return def;
	}

	bool IsReached(int soul)
	{
		return mSide > 0 ? soul >= mAt : soul <= mAt;
	}
}

// La balance de l'âme (data/soul.txt) : bornes, équilibre, butin et paliers.
class Sinwave_SoulDef play
{
	enum EMonsterDrops
	{
		MONSTER_DROPS_NONE,			// les monstres ne lâchent plus rien d'eux-mêmes
		MONSTER_DROPS_WEAPONS,		// seulement leurs armes (fusil, mitrailleuse...)
		MONSTER_DROPS_ALL			// comme dans Doom (chargeurs compris)
	}

	int mMin;
	int mMax;
	int mBalance;
	int mMonsterDrops;
	class<Inventory> mHealthItem;
	double mHealthDrop;			// chance de butin à l'équilibre, en %
	double mAmmoDrop;
	double mSinHealthDrop;		// par point au-dessus de l'équilibre
	double mSinAmmoDrop;
	double mVirtueHealthDrop;	// par point en dessous
	double mVirtueAmmoDrop;
	int mTrialTics;				// temps au bout de la balance avant une épreuve
	Name mTrialEnemy;			// côté péché : l'ennemi qui surgit
	int mAngelHeal;				// côté vertu : soins de l'ange
	// Paliers, du plus proche de l'équilibre au plus extrême, pour chaque côté.
	Array<Sinwave_SoulTierDef> mTiers;

	// Lit le bloc [soul] et les blocs [tier] ; sans fichier, une balance sans effet.
	static Sinwave_SoulDef FromBlocks(Array<Sinwave_DataBlock> blocks)
	{
		let def = new('Sinwave_SoulDef');
		Sinwave_DataBlock soul = null;
		for (int i = 0; i < blocks.Size() && soul == null; i++)
		{
			if (blocks[i].mType == 'soul') soul = blocks[i];
		}
		if (soul == null) soul = new('Sinwave_DataBlock');
		def.mMin = soul.GetInt("min", 0);
		def.mMax = max(def.mMin + 2, soul.GetInt("max", 30));
		def.mBalance = clamp(soul.GetInt("balance", 15), def.mMin + 1, def.mMax - 1);
		def.mHealthItem = Sinwave_ClassLookup.FindItem(soul, soul.GetString("health_item", "Stimpack"));
		String drops = soul.GetString("monster_drops", "weapons").MakeLower();
		if (drops == "none") def.mMonsterDrops = MONSTER_DROPS_NONE;
		else if (drops == "all") def.mMonsterDrops = MONSTER_DROPS_ALL;
		else
		{
			if (drops != "weapons") soul.Warn("monster_drops doit valoir none, weapons ou all.");
			def.mMonsterDrops = MONSTER_DROPS_WEAPONS;
		}
		def.mHealthDrop = soul.GetDouble("health_drop", 0);
		def.mAmmoDrop = soul.GetDouble("ammo_drop", 0);
		def.mSinHealthDrop = soul.GetDouble("sin_health_drop", 0);
		def.mSinAmmoDrop = soul.GetDouble("sin_ammo_drop", 0);
		def.mVirtueHealthDrop = soul.GetDouble("virtue_health_drop", 0);
		def.mVirtueAmmoDrop = soul.GetDouble("virtue_ammo_drop", 0);
		def.mTrialTics = soul.GetTics("trial_seconds", 0);
		def.mTrialEnemy = soul.GetString("trial_enemy").MakeLower();
		def.mAngelHeal = max(0, soul.GetInt("angel_heal", 0));

		for (int i = 0; i < blocks.Size(); i++)
		{
			if (blocks[i].mType == 'soul') continue;
			if (blocks[i].mType != 'tier')
			{
				blocks[i].Warn("type de bloc inattendu, [soul ...] ou [tier ...] attendu.");
				continue;
			}
			let tier = Sinwave_SoulTierDef.FromBlock(blocks[i]);
			if (tier == null) continue;
			if (tier.mSide * (tier.mAt - def.mBalance) <= 0)
			{
				blocks[i].Warn("un palier doit être du côté de son camp par rapport à l'équilibre.");
				continue;
			}
			def.InsertTier(tier);
		}
		return def;
	}

	// Rangement par distance à l'équilibre : les paliers se franchissent dans cet ordre.
	private void InsertTier(Sinwave_SoulTierDef tier)
	{
		int distance = abs(tier.mAt - mBalance);
		int i = 0;
		while (i < mTiers.Size() && abs(mTiers[i].mAt - mBalance) <= distance) i++;
		mTiers.Insert(i, tier);
	}

	// Faux : cet objet lâché par un monstre (à sa mort) doit disparaître, pour que
	// le butin ne dépende que de la balance.
	bool KeepsMonsterDrop(Inventory item)
	{
		if (mMonsterDrops == MONSTER_DROPS_ALL) return true;
		return mMonsterDrops == MONSTER_DROPS_WEAPONS && item is 'Weapon';
	}

	// +1 : l'âme penche vers le péché ; -1 : vers la vertu ; 0 : équilibre.
	int Side(int soul)
	{
		return soul > mBalance ? 1 : (soul < mBalance ? -1 : 0);
	}

	// Paliers atteints, du plus proche de l'équilibre au plus extrême.
	void ReachedTiers(int soul, out Array<Sinwave_SoulTierDef> result)
	{
		result.Clear();
		for (int i = 0; i < mTiers.Size(); i++)
		{
			if (mTiers[i].IsReached(soul)) result.Push(mTiers[i]);
		}
	}

	// Chance (en %) qu'un ennemi tué lâche un soin (health) ou des munitions :
	// valeur à l'équilibre, plus un petit changement par point d'écart, plus les
	// paliers atteints.
	double DropChance(int soul, bool health)
	{
		double chance = health ? mHealthDrop : mAmmoDrop;
		int distance = abs(soul - mBalance);
		if (soul > mBalance) chance += distance * (health ? mSinHealthDrop : mSinAmmoDrop);
		else if (soul < mBalance) chance += distance * (health ? mVirtueHealthDrop : mVirtueAmmoDrop);
		Array<Sinwave_SoulTierDef> reached;
		ReachedTiers(soul, reached);
		for (int i = 0; i < reached.Size(); i++) chance += health ? reached[i].mHealthDrop : reached[i].mAmmoDrop;
		return clamp(chance, 0.0, 100.0);
	}

	// Choix de niveau tirés vers le camp où penche l'âme (la pente glissante).
	int Temptation(int soul)
	{
		Array<Sinwave_SoulTierDef> reached;
		ReachedTiers(soul, reached);
		int total = 0;
		for (int i = 0; i < reached.Size(); i++) total += reached[i].mTemptation;
		return total;
	}

	// Multiplicateurs pour le boss : sa vie, et le nombre d'ennemis autour de lui.
	double BossHealthFactor(int soul)
	{
		Array<Sinwave_SoulTierDef> reached;
		ReachedTiers(soul, reached);
		double factor = 1;
		for (int i = 0; i < reached.Size(); i++) factor += reached[i].mBossHealth;
		return max(0.2, factor);
	}

	double BossEscortFactor(int soul)
	{
		Array<Sinwave_SoulTierDef> reached;
		ReachedTiers(soul, reached);
		double factor = 1;
		for (int i = 0; i < reached.Size(); i++) factor += reached[i].mBossEscort;
		return max(0.2, factor);
	}
}

// Réglages généraux de progression (data/progression.txt).
class Sinwave_ProgressionDef play
{
	int mXpFirstLevel;
	double mXpGrowth;
	int mOfferVirtues;
	int mOfferSins;
	int mOfferFree;			// choix de l'un ou l'autre camp (tirés par l'âme, sinon au hasard)
	double mMagnetRadius;
	int mIndulgencesPerScore;
	int mIndulgencesPerCircle;
	int mIndulgencesAbsolution;		// bonus de victoire selon le verdict
	int mIndulgencesPurgatory;
	int mIndulgencesDamnation;
	Array<Sinwave_ItemStack> mStartItems;
	int mSupplyTics;
	Array<Sinwave_ItemStack> mSupplyItems;
	// Montée en difficulté d'une vague à l'autre (voir Sinwave_CircleDef).
	double mWaveSpawnGrowth;
	int mWaveMaxGrowth;
	double mWaveHealthGrowth;	// vie des ennemis, par vague depuis le début de l'arène
	int mThreatWarningTics;		// un projectile ennemi est signalé s'il arrive dans ce délai

	// `block` peut être null : on garde alors les valeurs par défaut.
	static Sinwave_ProgressionDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_ProgressionDef');
		if (block == null) block = new('Sinwave_DataBlock');
		def.mXpFirstLevel = max(1, block.GetInt("xp_first_level", 5));
		def.mXpGrowth = max(1.0, block.GetDouble("xp_growth", 1.5));
		def.mOfferVirtues = max(0, block.GetInt("offer_virtues", 2));
		def.mOfferSins = max(0, block.GetInt("offer_sins", 1));
		def.mOfferFree = max(0, block.GetInt("offer_free", 0));
		def.mMagnetRadius = max(0.0, block.GetDouble("magnet_radius", 192));
		def.mIndulgencesPerScore = max(1, block.GetInt("indulgences_per_score", 20));
		def.mIndulgencesPerCircle = max(0, block.GetInt("indulgences_per_circle", 2));
		def.mIndulgencesAbsolution = max(0, block.GetInt("indulgences_absolution", 20));
		def.mIndulgencesPurgatory = max(0, block.GetInt("indulgences_purgatory", 12));
		def.mIndulgencesDamnation = max(0, block.GetInt("indulgences_damnation", 5));
		def.mSupplyTics = block.GetTics("supply_seconds", 0);
		def.mWaveSpawnGrowth = max(0.0, block.GetDouble("wave_spawn_growth", 0.15));
		def.mWaveMaxGrowth = max(0, block.GetInt("wave_max_growth", 2));
		def.mWaveHealthGrowth = max(0.0, block.GetDouble("wave_health_growth", 0.03));
		def.mThreatWarningTics = max(1, block.GetTics("threat_warning_seconds", 1.0));
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
