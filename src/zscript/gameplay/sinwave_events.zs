// =============================================================================
//  Catalogue des événements du jeu.
// =============================================================================
//
//  Tous les échanges entre systèmes passent par ces classes. Lire ce fichier
//  suffit pour connaître tout ce qui peut « se passer » dans le jeu.

// --- Moteur et interface -> jeu (publiés par Sinwave_Game, le pont) ----------

// Le joueur appuie sur la touche Utiliser (ou « netevent sinwave_confirm »).
class Sinwave_ConfirmEvent : Sinwave_Event
{
	bool mFromConsole;

	static Sinwave_ConfirmEvent Create(bool fromConsole)
	{
		let e = new('Sinwave_ConfirmEvent');
		e.mFromConsole = fromConsole;
		return e;
	}

	override String Describe()
	{
		return mFromConsole ? "console" : "touche Utiliser";
	}
}

class Sinwave_PauseRequestedEvent : Sinwave_Event {}
class Sinwave_ResumeRequestedEvent : Sinwave_Event {}
class Sinwave_AbandonRequestedEvent : Sinwave_Event {}
class Sinwave_ShopRequestedEvent : Sinwave_Event {}
// Quitter un écran de menu (boutique, choix d'arène).
class Sinwave_BackRequestedEvent : Sinwave_Event {}

// Commandes avec un numéro : amélioration, article ou arène choisis.
class Sinwave_IndexEvent : Sinwave_Event
{
	int mIndex;

	override String Describe()
	{
		return String.Format("%d", mIndex);
	}
}

class Sinwave_UpgradePickedEvent : Sinwave_IndexEvent
{
	static Sinwave_UpgradePickedEvent Create(int index)
	{
		let e = new('Sinwave_UpgradePickedEvent');
		e.mIndex = index;
		return e;
	}
}

class Sinwave_ShopBuyRequestedEvent : Sinwave_IndexEvent
{
	static Sinwave_ShopBuyRequestedEvent Create(int index)
	{
		let e = new('Sinwave_ShopBuyRequestedEvent');
		e.mIndex = index;
		return e;
	}
}

class Sinwave_ArenaChosenEvent : Sinwave_IndexEvent
{
	static Sinwave_ArenaChosenEvent Create(int index)
	{
		let e = new('Sinwave_ArenaChosenEvent');
		e.mIndex = index;
		return e;
	}
}

// Règles de la descente : un réglage change (mField) d'un cran (mDelta = -1 ou +1).
class Sinwave_RuleAdjustedEvent : Sinwave_Event
{
	enum EField
	{
		FIELD_PRESET,
		FIELD_HEALTH,
		FIELD_SPEED,
		FIELD_SPAWN,
		FIELD_DAMAGE,
		FIELD_CIRCLE
	}

	int mField;
	int mDelta;

	static Sinwave_RuleAdjustedEvent Create(int field, int delta)
	{
		let e = new('Sinwave_RuleAdjustedEvent');
		e.mField = field;
		e.mDelta = delta >= 0 ? 1 : -1;
		return e;
	}

	override String Describe()
	{
		return String.Format("réglage %d, %+d", mField, mDelta);
	}
}

// Le joueur valide les règles : la descente commence.
class Sinwave_DescendRequestedEvent : Sinwave_Event {}

// Une partie a été rechargée depuis une sauvegarde du moteur.
class Sinwave_GameLoadedEvent : Sinwave_Event {}

class Sinwave_PlayerDiedEvent : Sinwave_Event {}

// Un acteur (n'importe lequel) est mort. Le système de vagues reconnaît les siens.
class Sinwave_ActorDiedEvent : Sinwave_Event
{
	Actor mThing;

	static Sinwave_ActorDiedEvent Create(Actor thing)
	{
		let e = new('Sinwave_ActorDiedEvent');
		e.mThing = thing;
		return e;
	}

	override String Describe()
	{
		return mThing != null ? String.Format("%s", mThing.GetClassName()) : "";
	}
}

// Le joueur a blessé un acteur.
class Sinwave_ActorDamagedEvent : Sinwave_Event
{
	Actor mThing;
	int mDamage;

	static Sinwave_ActorDamagedEvent Create(Actor thing, int damage)
	{
		let e = new('Sinwave_ActorDamagedEvent');
		e.mThing = thing;
		e.mDamage = damage;
		return e;
	}

	override String Describe()
	{
		return mThing != null ? String.Format("%s -%d", mThing.GetClassName(), mDamage) : "";
	}
}

// --- Déroulement de la run (publiés par les états) ---------------------------

class Sinwave_RunStartedEvent : Sinwave_Event {}
// La run est mise en attente (pause, choix d'amélioration) puis reprend.
class Sinwave_RunSuspendedEvent : Sinwave_Event {}
class Sinwave_RunResumedEvent : Sinwave_Event {}

class Sinwave_RunEndedEvent : Sinwave_Event
{
	enum EReason
	{
		REASON_VICTORY,
		REASON_DEATH,
		REASON_ABANDON
	}

	int mReason;

	static Sinwave_RunEndedEvent Create(int reason)
	{
		let e = new('Sinwave_RunEndedEvent');
		e.mReason = reason;
		return e;
	}

	override String Describe()
	{
		static const String REASONS[] = { "victoire", "mort", "abandon" };
		return REASONS[clamp(mReason, 0, 2)];
	}
}

// --- Cercles, ennemis et boss (Sinwave_WaveSystem, Sinwave_BossSystem) -------

class Sinwave_WaveStartedEvent : Sinwave_Event
{
	int mIndex;
	int mCount;
	String mName;
	int mDurationTics;	// 0 : jusqu'à la mort du boss

	static Sinwave_WaveStartedEvent Create(int index, int count, String name, int durationTics)
	{
		let e = new('Sinwave_WaveStartedEvent');
		e.mIndex = index;
		e.mCount = count;
		e.mName = name;
		e.mDurationTics = durationTics;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d/%d \"%s\"", mIndex + 1, mCount, mName);
	}
}

class Sinwave_WaveEndedEvent : Sinwave_Event
{
	int mIndex;

	static Sinwave_WaveEndedEvent Create(int index)
	{
		let e = new('Sinwave_WaveEndedEvent');
		e.mIndex = index;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d", mIndex + 1);
	}
}

// Tous les cercles sont franchis : la run est gagnée.
class Sinwave_AllWavesClearedEvent : Sinwave_Event {}

class Sinwave_EnemyKilledEvent : Sinwave_Event
{
	Sinwave_EnemyDef mDef;
	Vector3 mPos;

	static Sinwave_EnemyKilledEvent Create(Sinwave_EnemyDef def, Vector3 pos)
	{
		let e = new('Sinwave_EnemyKilledEvent');
		e.mDef = def;
		e.mPos = pos;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s (+%d XP, +%d pts)", mDef.mId, mDef.mXp, mDef.mScore);
	}
}

// Demande d'apparition d'ennemis hors du rythme normal (renforts d'un boss...).
class Sinwave_SpawnRequestedEvent : Sinwave_Event
{
	Name mEnemyId;
	int mCount;

	static Sinwave_SpawnRequestedEvent Create(Name enemyId, int count)
	{
		let e = new('Sinwave_SpawnRequestedEvent');
		e.mEnemyId = enemyId;
		e.mCount = count;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s x%d", mEnemyId, mCount);
	}
}

class Sinwave_BossSpawnedEvent : Sinwave_Event
{
	Actor mBoss;
	Sinwave_EnemyDef mDef;

	static Sinwave_BossSpawnedEvent Create(Actor boss, Sinwave_EnemyDef def)
	{
		let e = new('Sinwave_BossSpawnedEvent');
		e.mBoss = boss;
		e.mDef = def;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s", mDef.mId);
	}
}

class Sinwave_BossDefeatedEvent : Sinwave_Event {}

class Sinwave_BossHealthChangedEvent : Sinwave_Event
{
	double mFraction;

	static Sinwave_BossHealthChangedEvent Create(double fraction)
	{
		let e = new('Sinwave_BossHealthChangedEvent');
		e.mFraction = fraction;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d %%", int(mFraction * 100));
	}
}

class Sinwave_BossEnragedEvent : Sinwave_Event {}

// --- Malédictions de cercle (Sinwave_CurseSystem) ----------------------------

class Sinwave_CurseStartedEvent : Sinwave_Event
{
	Sinwave_CurseDef mDef;

	static Sinwave_CurseStartedEvent Create(Sinwave_CurseDef def)
	{
		let e = new('Sinwave_CurseStartedEvent');
		e.mDef = def;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s", mDef.mId);
	}
}

class Sinwave_CurseEndedEvent : Sinwave_Event {}

// --- Expérience (Sinwave_XpOrb, Sinwave_XpSystem) ----------------------------

class Sinwave_XpOrbDroppedEvent : Sinwave_Event
{
	Sinwave_XpOrb mOrb;

	static Sinwave_XpOrbDroppedEvent Create(Sinwave_XpOrb orb)
	{
		let e = new('Sinwave_XpOrbDroppedEvent');
		e.mOrb = orb;
		return e;
	}
}

class Sinwave_XpCollectedEvent : Sinwave_Event
{
	int mAmount;

	static Sinwave_XpCollectedEvent Create(int amount)
	{
		let e = new('Sinwave_XpCollectedEvent');
		e.mAmount = amount;
		return e;
	}

	override String Describe()
	{
		return String.Format("+%d", mAmount);
	}
}

class Sinwave_XpChangedEvent : Sinwave_Event
{
	int mXp;
	int mNeeded;
	int mLevel;

	static Sinwave_XpChangedEvent Create(int xp, int needed, int level)
	{
		let e = new('Sinwave_XpChangedEvent');
		e.mXp = xp;
		e.mNeeded = needed;
		e.mLevel = level;
		return e;
	}

	override String Describe()
	{
		return String.Format("niveau %d, %d/%d", mLevel, mXp, mNeeded);
	}
}

class Sinwave_LevelUpEvent : Sinwave_Event
{
	int mLevel;

	static Sinwave_LevelUpEvent Create(int level)
	{
		let e = new('Sinwave_LevelUpEvent');
		e.mLevel = level;
		return e;
	}

	override String Describe()
	{
		return String.Format("niveau %d", mLevel);
	}
}

// --- Vertus, péchés et corruption --------------------------------------------

class Sinwave_UpgradeOfferedEvent : Sinwave_Event
{
	Array<Sinwave_UpgradeDef> mChoices;

	override String Describe()
	{
		String text = "";
		for (int i = 0; i < mChoices.Size(); i++)
		{
			text = text .. (i > 0 ? ", " : "") .. mChoices[i].mId;
		}
		return text;
	}
}

class Sinwave_UpgradeChosenEvent : Sinwave_Event
{
	Sinwave_UpgradeDef mUpgrade;

	static Sinwave_UpgradeChosenEvent Create(Sinwave_UpgradeDef upgrade)
	{
		let e = new('Sinwave_UpgradeChosenEvent');
		e.mUpgrade = upgrade;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s", mUpgrade.mId);
	}
}

// Un effet doit être appliqué au joueur (vertu, péché, article de boutique, malédiction).
class Sinwave_EffectGrantedEvent : Sinwave_Event
{
	Sinwave_Effect mEffect;
	String mSource;

	static Sinwave_EffectGrantedEvent Create(Sinwave_Effect effect, String source)
	{
		let e = new('Sinwave_EffectGrantedEvent');
		e.mEffect = effect;
		e.mSource = source;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s (%s)", mEffect.Describe(), mSource);
	}
}

// La corruption de la run a changé. La règle du verdict est ici, à un seul endroit.
class Sinwave_CorruptionChangedEvent : Sinwave_Event
{
	int mCorruption;
	int mThreshold;

	static Sinwave_CorruptionChangedEvent Create(int corruption, int threshold)
	{
		let e = new('Sinwave_CorruptionChangedEvent');
		e.mCorruption = corruption;
		e.mThreshold = threshold;
		return e;
	}

	bool IsDamned()
	{
		return mCorruption >= mThreshold;
	}

	override String Describe()
	{
		return String.Format("%d/%d", mCorruption, mThreshold);
	}
}

// --- Règles de la descente (Sinwave_RulesSystem) -----------------------------

class Sinwave_RulesChangedEvent : Sinwave_Event
{
	Sinwave_RunRules mRules;

	static Sinwave_RulesChangedEvent Create(Sinwave_RunRules rules)
	{
		let e = new('Sinwave_RulesChangedEvent');
		e.mRules = rules;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s, récompense x%.2f", mRules.Encode(), mRules.RewardFactor());
	}
}

// --- Score, méta-progression et boutique -------------------------------------

class Sinwave_ScoreChangedEvent : Sinwave_Event
{
	int mScore;
	int mKills;

	static Sinwave_ScoreChangedEvent Create(int score, int kills)
	{
		let e = new('Sinwave_ScoreChangedEvent');
		e.mScore = score;
		e.mKills = kills;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d pts, %d victimes", mScore, mKills);
	}
}

// État actuel de la méta-progression (au démarrage, après un achat ou une sauvegarde).
class Sinwave_MetaLoadedEvent : Sinwave_Event
{
	Sinwave_MetaData mMeta;

	static Sinwave_MetaLoadedEvent Create(Sinwave_MetaData metaData)
	{
		let e = new('Sinwave_MetaLoadedEvent');
		e.mMeta = metaData;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d indulgences, record %d, %d runs", mMeta.mIndulgences, mMeta.mBestScore, mMeta.mRuns);
	}
}

// Résultat d'une tentative d'achat à la boutique.
class Sinwave_PurchaseEvent : Sinwave_Event
{
	Sinwave_ShopItemDef mItem;
	bool mSuccess;
	String mMessage;

	static Sinwave_PurchaseEvent Create(Sinwave_ShopItemDef item, bool success, String message)
	{
		let e = new('Sinwave_PurchaseEvent');
		e.mItem = item;
		e.mSuccess = success;
		e.mMessage = message;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s %s", mItem != null ? String.Format("%s", mItem.mId) : "?", mSuccess ? "ok" : "refusé");
	}
}

// La run est terminée et la méta-progression vient d'être sauvegardée.
class Sinwave_MetaSavedEvent : Sinwave_Event
{
	Sinwave_MetaData mMeta;
	int mEarned;
	bool mNewBest;
	bool mDamned;

	static Sinwave_MetaSavedEvent Create(Sinwave_MetaData metaData, int earned, bool newBest, bool damned)
	{
		let e = new('Sinwave_MetaSavedEvent');
		e.mMeta = metaData;
		e.mEarned = earned;
		e.mNewBest = newBest;
		e.mDamned = damned;
		return e;
	}

	override String Describe()
	{
		return String.Format("+%d indulgences (total %d), %s", mEarned, mMeta.mIndulgences, mDamned ? "damnation" : "absolution");
	}
}
