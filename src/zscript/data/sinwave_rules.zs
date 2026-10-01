// =============================================================================
//  Règles de la descente : difficulté prédéfinie ou défi personnalisé.
// =============================================================================

// Une difficulté prédéfinie (data/difficulties.txt).
class Sinwave_DifficultyDef play
{
	Name mId;
	String mName;
	String mDescription;
	double mEnemyHealth;
	double mEnemySpeed;
	double mSpawnRate;
	double mDamageTaken;

	static Sinwave_DifficultyDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_DifficultyDef');
		def.mId = block.mId;
		def.mName = block.GetString("name", block.mId);
		def.mDescription = block.GetString("description");
		def.mEnemyHealth = block.GetDouble("enemy_health", 1);
		def.mEnemySpeed = block.GetDouble("enemy_speed", 1);
		def.mSpawnRate = block.GetDouble("spawn_rate", 1);
		def.mDamageTaken = block.GetDouble("damage_taken", 1);
		return def;
	}
}

// Les règles choisies pour la prochaine run. C'est un service : écrit uniquement par
// Sinwave_RulesSystem, lu par les systèmes qui les appliquent (vagues, joueur, méta).
// Elles s'ajoutent aux règles propres à l'arène (data/arenas.txt).
class Sinwave_RunRules : Sinwave_Service
{
	// Bornes et pas des réglages, communs au système et aux tests.
	const HEALTH_MIN = 0.5;		const HEALTH_MAX = 3.0;		const HEALTH_STEP = 0.25;
	const SPEED_MIN = 0.5;		const SPEED_MAX = 2.0;		const SPEED_STEP = 0.1;
	const SPAWN_MIN = 0.5;		const SPAWN_MAX = 3.0;		const SPAWN_STEP = 0.25;
	const DAMAGE_MIN = 0.25;	const DAMAGE_MAX = 3.0;		const DAMAGE_STEP = 0.25;
	const MAX_CHALLENGES = 30;		// cercles qui peuvent avoir un défi coché
	const CHALLENGE_REWARD = 0.1;	// récompense : +10 % par défi joué

	double mEnemyHealth;
	double mEnemySpeed;
	double mSpawnRate;
	double mDamageTaken;
	int mStartCircle;		// 1 = premier cercle
	int mChallenges;		// défis des péchés cochés : un bit par cercle (bit 0 : premier)
	Name mPreset;			// 'None' : défi personnalisé
	int mArenaIndex;		// arène choisie (non sauvegardée)

	static Sinwave_RunRules From(Sinwave_Services services)
	{
		return Sinwave_RunRules(services.Get('Rules'));
	}

	static Sinwave_RunRules Create()
	{
		let rules = new('Sinwave_RunRules');
		rules.mEnemyHealth = 1;
		rules.mEnemySpeed = 1;
		rules.mSpawnRate = 1;
		rules.mDamageTaken = 1;
		rules.mStartCircle = 1;
		rules.mPreset = 'penitent';
		return rules;
	}

	void ApplyPreset(Sinwave_DifficultyDef preset)
	{
		mEnemyHealth = preset.mEnemyHealth;
		mEnemySpeed = preset.mEnemySpeed;
		mSpawnRate = preset.mSpawnRate;
		mDamageTaken = preset.mDamageTaken;
		mPreset = preset.mId;
	}

	bool Matches(Sinwave_DifficultyDef preset)
	{
		return abs(mEnemyHealth - preset.mEnemyHealth) < 0.001 && abs(mEnemySpeed - preset.mEnemySpeed) < 0.001
			&& abs(mSpawnRate - preset.mSpawnRate) < 0.001 && abs(mDamageTaken - preset.mDamageTaken) < 0.001;
	}

	// Défi du péché coché pour le cercle `circle` (0 : premier cercle).
	bool HasChallenge(int circle)
	{
		return circle >= 0 && circle < MAX_CHALLENGES && (mChallenges & (1 << circle)) != 0;
	}

	void SetChallenge(int circle, bool on)
	{
		if (circle < 0 || circle >= MAX_CHALLENGES) return;
		if (on) mChallenges |= 1 << circle;
		else mChallenges &= ~(1 << circle);
	}

	// Défis cochés sur les cercles joués (ceux d'avant le cercle de départ ne comptent pas).
	int PlayedChallenges()
	{
		int count = 0;
		for (int i = max(0, mStartCircle - 1); i < MAX_CHALLENGES; i++)
		{
			if (HasChallenge(i)) count++;
		}
		return count;
	}

	// Plus c'est dur, plus la run rapporte d'indulgences.
	double RewardFactor()
	{
		// Pèlerin : environ x0,6 ; Damné : x1,6 ; Enfer : x2,5. Chaque défi ajoute 10 %.
		double reward = (mEnemyHealth ** 0.4) * (mEnemySpeed ** 0.5) * (mSpawnRate ** 0.3) * (mDamageTaken ** 0.4);
		reward *= 1 + CHALLENGE_REWARD * PlayedChallenges();
		return clamp(int(reward * 20 + 0.5) / 20.0, 0.25, 5.0);	// arrondi à 0,05
	}

	// Sauvegarde sous forme de texte : « health=1.25;speed=1;spawn=1;damage=1;circle=1;challenges=0;preset=penitent ».
	String Encode()
	{
		return String.Format("health=%.2f;speed=%.2f;spawn=%.2f;damage=%.2f;circle=%d;challenges=%d;preset=%s",
			mEnemyHealth, mEnemySpeed, mSpawnRate, mDamageTaken, mStartCircle, mChallenges, mPreset);
	}

	void Decode(String text)
	{
		Array<String> entries;
		text.Split(entries, ";", TOK_SKIPEMPTY);
		for (int i = 0; i < entries.Size(); i++)
		{
			Array<String> parts;
			entries[i].Split(parts, "=");
			if (parts.Size() != 2) continue;
			String key = parts[0].MakeLower();
			if (key == "health") mEnemyHealth = clamp(parts[1].ToDouble(), HEALTH_MIN, HEALTH_MAX);
			else if (key == "speed") mEnemySpeed = clamp(parts[1].ToDouble(), SPEED_MIN, SPEED_MAX);
			else if (key == "spawn") mSpawnRate = clamp(parts[1].ToDouble(), SPAWN_MIN, SPAWN_MAX);
			else if (key == "damage") mDamageTaken = clamp(parts[1].ToDouble(), DAMAGE_MIN, DAMAGE_MAX);
			else if (key == "circle") mStartCircle = max(1, parts[1].ToInt(10));
			else if (key == "challenges") mChallenges = parts[1].ToInt(10) & ((1 << MAX_CHALLENGES) - 1);
			else if (key == "preset") mPreset = parts[1];
		}
	}
}
