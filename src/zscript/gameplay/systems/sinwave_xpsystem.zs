// =============================================================================
//  Expérience et niveaux.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, EnemyKilled, XpCollected, EffectGranted
//  Publie : XpOrbDropped, XpChanged, LevelUp
//
//  Chaque ennemi tué lâche une orbe (Sinwave_XpOrb). Quand le joueur la ramasse,
//  l'orbe publie XpCollected : elle connaît le bus, pas ce système.
//  Effets appliqués ici : magnet (rayon d'attraction), xpgain (XP gagnée).

class Sinwave_XpSystem : Sinwave_System
{
	private Sinwave_ProgressionDef mProgression;
	private bool mRunning;
	private int mXp;
	private int mLevel;
	private int mNeeded;
	private double mMagnetFactor;
	private double mGainFactor;

	override void Setup()
	{
		mProgression = Sinwave_GameData.From(mServices).mProgression;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_EnemyKilledEvent');
		mBus.Subscribe(self, 'Sinwave_XpCollectedEvent');
		mBus.Subscribe(self, 'Sinwave_EffectGrantedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mXp = 0;
			mLevel = 1;
			mNeeded = XpForLevel(1);
			mMagnetFactor = 1;
			mGainFactor = 1;
			mBus.Publish(Sinwave_XpChangedEvent.Create(mXp, mNeeded, mLevel));
			return;
		}
		if (e is 'Sinwave_RunEndedEvent')
		{
			mRunning = false;
			RemoveOrbs();
			return;
		}
		if (!mRunning) return;

		let killed = Sinwave_EnemyKilledEvent(e);
		if (killed != null)
		{
			DropOrb(killed.mPos, killed.mDef.mXp);
			return;
		}
		let collected = Sinwave_XpCollectedEvent(e);
		if (collected != null)
		{
			Gain(collected.mAmount);
			return;
		}
		let granted = Sinwave_EffectGrantedEvent(e);
		if (granted != null)
		{
			if (granted.mEffect.mType == 'magnet') mMagnetFactor += granted.mEffect.mValue;
			else if (granted.mEffect.mType == 'xpgain') mGainFactor += granted.mEffect.mValue;
		}
	}

	private void DropOrb(Vector3 pos, int value)
	{
		if (value <= 0) return;
		let orb = Sinwave_XpOrb(Actor.Spawn('Sinwave_XpOrb', pos + (0, 0, 16)));
		if (orb == null) return;
		orb.Setup(mBus, value, mProgression.mMagnetRadius * max(0.1, mMagnetFactor));
		mBus.Publish(Sinwave_XpOrbDroppedEvent.Create(orb));
	}

	private void Gain(int amount)
	{
		mXp += max(1, int(amount * max(0.1, mGainFactor) + 0.5));
		while (mXp >= mNeeded)
		{
			mXp -= mNeeded;
			mLevel++;
			mNeeded = XpForLevel(mLevel);
			mBus.Publish(Sinwave_LevelUpEvent.Create(mLevel));
		}
		mBus.Publish(Sinwave_XpChangedEvent.Create(mXp, mNeeded, mLevel));
	}

	// XP nécessaire pour passer du niveau `level` au suivant.
	private int XpForLevel(int level)
	{
		return max(1, int(mProgression.mXpFirstLevel * (mProgression.mXpGrowth ** (level - 1)) + 0.5));
	}

	private void RemoveOrbs()
	{
		let it = ThinkerIterator.Create('Sinwave_XpOrb');
		Actor orb;
		while (orb = Actor(it.Next()))
		{
			orb.Destroy();
		}
	}
}
