// =============================================================================
//  Corruption : la balance de l'âme.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, UpgradeChosen, SoulShift (débogage)
//  Publie : CorruptionChanged, SoulTierChanged, EffectGranted (effets des paliers)
//
//  Chaque run commence à l'équilibre (data/soul.txt). Chaque amélioration porte
//  une valeur de corruption (data/upgrades.txt) : positive pour un péché,
//  négative pour une vertu. Plus l'âme s'éloigne de l'équilibre, plus elle
//  franchit de paliers ; chaque palier atteint applique ses effets, qui se
//  retirent s'il est perdu. Le butin qui dépend de l'âme est l'affaire de
//  Sinwave_LootSystem ; le verdict, celle de Sinwave_CorruptionChangedEvent.

class Sinwave_CorruptionSystem : Sinwave_System
{
	private Sinwave_SoulDef mSoul;
	private bool mRunning;
	private int mCorruption;
	private bool mSyncPending;		// paliers à appliquer au prochain tic
	private Array<Sinwave_SoulTierDef> mActive;

	override void Setup()
	{
		mSoul = Sinwave_GameData.From(mServices).mSoul;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_UpgradeChosenEvent');
		mBus.Subscribe(self, 'Sinwave_SoulShiftEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mCorruption = mSoul.mBalance;
			// Le joueur est remis à zéro pendant RunStarted, sans ordre garanti entre
			// les systèmes : les paliers seront (re)appliqués au prochain tic.
			mActive.Clear();
			mSyncPending = true;
			mBus.Publish(Sinwave_CorruptionChangedEvent.Create(mCorruption, mSoul));
		}
		else if (e is 'Sinwave_RunEndedEvent')
		{
			mRunning = false;
		}
		else if (e is 'Sinwave_UpgradeChosenEvent')
		{
			Shift(Sinwave_UpgradeChosenEvent(e).mUpgrade.mCorruption);
		}
		else if (e is 'Sinwave_SoulShiftEvent')
		{
			Shift(Sinwave_SoulShiftEvent(e).mDelta);
		}
	}

	private void Shift(int delta)
	{
		if (!mRunning || delta == 0) return;
		mCorruption = clamp(mCorruption + delta, mSoul.mMin, mSoul.mMax);
		UpdateTiers();
		mBus.Publish(Sinwave_CorruptionChangedEvent.Create(mCorruption, mSoul));
	}

	override void Tick()
	{
		if (!mRunning || !mSyncPending) return;
		mSyncPending = false;
		UpdateTiers();
	}

	// Retire les paliers perdus (du plus extrême au plus proche de l'équilibre),
	// puis applique les paliers nouvellement atteints.
	private void UpdateTiers()
	{
		Array<Sinwave_SoulTierDef> reached;
		mSoul.ReachedTiers(mCorruption, reached);

		for (int i = mActive.Size() - 1; i >= 0; i--)
		{
			let tier = mActive[i];
			if (reached.Find(tier) < reached.Size()) continue;
			for (int k = 0; k < tier.mEffects.Size(); k++)
			{
				let undo = tier.mEffects[k].Negated();
				if (undo != null) mBus.Publish(Sinwave_EffectGrantedEvent.Create(undo, tier.mName));
			}
			mActive.Delete(i);
			mBus.Publish(Sinwave_SoulTierChangedEvent.Create(tier, false));
		}

		for (int i = 0; i < reached.Size(); i++)
		{
			let tier = reached[i];
			if (mActive.Find(tier) < mActive.Size()) continue;
			for (int k = 0; k < tier.mEffects.Size(); k++)
			{
				mBus.Publish(Sinwave_EffectGrantedEvent.Create(tier.mEffects[k], tier.mName));
			}
			mActive.Push(tier);
			mBus.Publish(Sinwave_SoulTierChangedEvent.Create(tier, true));
		}
	}
}
