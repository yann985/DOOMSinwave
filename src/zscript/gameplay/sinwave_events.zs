// =============================================================================
//  Catalogue des événements du jeu.
// =============================================================================
//
//  Tous les échanges entre systèmes passent par ces classes. Lire ce fichier
//  suffit pour connaître tout ce qui peut « se passer » dans une run.

// --- Moteur -> jeu (publiés par Sinwave_Game, le pont avec le moteur) --------

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

// L'interface a choisi l'amélioration numéro mIndex.
class Sinwave_UpgradePickedEvent : Sinwave_Event
{
	int mIndex;

	static Sinwave_UpgradePickedEvent Create(int index)
	{
		let e = new('Sinwave_UpgradePickedEvent');
		e.mIndex = index;
		return e;
	}

	override String Describe()
	{
		return String.Format("choix %d", mIndex);
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

// --- Vagues (publiés par Sinwave_WaveSystem) ---------------------------------

class Sinwave_WaveStartedEvent : Sinwave_Event
{
	int mIndex;
	int mCount;
	String mName;
	int mDurationTics;

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

// Toutes les vagues sont terminées : la run est gagnée.
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

// --- Expérience (Sinwave_XpOrb, Sinwave_XpSystem) ----------------------------

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

// --- Améliorations (Sinwave_UpgradeSystem, Sinwave_MetaSystem) ---------------

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

// Un effet doit être appliqué (amélioration choisie ou bénédiction débloquée).
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
		return String.Format("%s %.2f (%s)", mEffect.mType, mEffect.mValue, mSource);
	}
}

// --- Score et méta-progression -----------------------------------------------

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

// État actuel de la méta-progression (au démarrage, après un chargement ou une sauvegarde).
class Sinwave_MetaLoadedEvent : Sinwave_Event
{
	Sinwave_MetaData mMeta;
	Sinwave_UnlockDef mNextUnlock;	// null si tout est débloqué

	static Sinwave_MetaLoadedEvent Create(Sinwave_MetaData metaData, Sinwave_UnlockDef nextUnlock)
	{
		let e = new('Sinwave_MetaLoadedEvent');
		e.mMeta = metaData;
		e.mNextUnlock = nextUnlock;
		return e;
	}

	override String Describe()
	{
		return String.Format("%d âmes, record %d, %d runs", mMeta.mSouls, mMeta.mBestScore, mMeta.mRuns);
	}
}

// La run est terminée et la méta-progression vient d'être sauvegardée.
class Sinwave_MetaSavedEvent : Sinwave_Event
{
	Sinwave_MetaData mMeta;
	int mSoulsEarned;
	bool mNewBest;
	String mUnlocked;	// noms des déblocages obtenus pendant cette run

	static Sinwave_MetaSavedEvent Create(Sinwave_MetaData metaData, int soulsEarned, bool newBest, String unlocked)
	{
		let e = new('Sinwave_MetaSavedEvent');
		e.mMeta = metaData;
		e.mSoulsEarned = soulsEarned;
		e.mNewBest = newBest;
		e.mUnlocked = unlocked;
		return e;
	}

	override String Describe()
	{
		return String.Format("+%d âmes (total %d)", mSoulsEarned, mMeta.mSouls);
	}
}
