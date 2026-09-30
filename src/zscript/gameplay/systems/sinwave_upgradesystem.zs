// =============================================================================
//  Choix d'une vertu, d'un neutre ou d'un péché à la montée de niveau.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, LevelUp, UpgradePicked, CorruptionChanged
//  Publie : UpgradeOffered, UpgradeChosen, EffectGranted
//
//  Propose des vertus (modestes, qui purifient), des neutres (meilleurs, sans
//  toucher à l'âme) et des péchés (puissants, avec un défaut, qui corrompent),
//  tirés au hasard dans data/upgrades.txt en respectant leur maximum par run.
//  Un choix libre (offer_free) est d'abord neutre, avec une chance qui baisse
//  quand l'âme penche (offer_neutral_chance, data/progression.txt). Sinon, la
//  pente glissante le fait basculer vers le camp où penche l'âme, un par point
//  de « temptation » des paliers atteints (data/soul.txt) ; à l'équilibre, au hasard.
//  Ce système ne sait pas ce que fait un effet : il publie EffectGranted et le
//  système concerné l'applique. Il ne gère pas non plus la corruption :
//  Sinwave_CorruptionSystem réagit à UpgradeChosen.

class Sinwave_UpgradeSystem : Sinwave_System
{
	private Sinwave_GameData mData;
	private bool mRunning;
	private Array<int> mStacks;					// nombre de prises, par amélioration
	private Array<Sinwave_UpgradeDef> mOffer;	// proposition en cours
	private int mPending;						// niveaux gagnés pas encore récompensés
	private int mSoul;							// balance de l'âme

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_LevelUpEvent');
		mBus.Subscribe(self, 'Sinwave_UpgradePickedEvent');
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
		mSoul = mData.mSoul.mBalance;
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mStacks.Clear();
			for (int i = 0; i < mData.mUpgrades.Size(); i++) mStacks.Push(0);
			mOffer.Clear();
			mPending = 0;
		}
		else if (e is 'Sinwave_RunEndedEvent')
		{
			mRunning = false;
			mOffer.Clear();
			mPending = 0;
		}
		else if (e is 'Sinwave_LevelUpEvent' && mRunning)
		{
			mPending++;
			if (mOffer.Size() == 0) MakeOffer();
		}
		else if (e is 'Sinwave_UpgradePickedEvent' && mRunning)
		{
			Pick(Sinwave_UpgradePickedEvent(e).mIndex);
		}
		else if (e is 'Sinwave_CorruptionChangedEvent')
		{
			mSoul = Sinwave_CorruptionChangedEvent(e).mCorruption;
		}
	}

	private void MakeOffer()
	{
		mOffer.Clear();
		int virtues, neutrals, sins;
		[virtues, neutrals, sins] = OfferSplit();
		// Dans l'ordre de la balance : vertus, neutres, péchés.
		PickRandom(Sinwave_UpgradeDef.KIND_VIRTUE, virtues);
		int missing = neutrals - PickRandom(Sinwave_UpgradeDef.KIND_NEUTRAL, neutrals);
		PickRandom(Sinwave_UpgradeDef.KIND_SIN, sins);
		// Plus aucun neutre disponible : le choix revient à l'un des deux camps.
		for (int i = 0; i < missing; i++)
		{
			PickRandom(Random[SinwaveUpgrades](0, 1) == 0 ? Sinwave_UpgradeDef.KIND_VIRTUE : Sinwave_UpgradeDef.KIND_SIN, 1);
		}
		if (mOffer.Size() == 0)
		{
			mPending = 0;	// tout est au maximum : plus rien à proposer
			return;
		}

		let offer = new('Sinwave_UpgradeOfferedEvent');
		for (int i = 0; i < mOffer.Size(); i++) offer.mChoices.Push(mOffer[i]);
		mBus.Publish(offer);
	}

	// Nombre de vertus, de neutres et de péchés proposés.
	// Un choix libre est d'abord neutre, avec une chance qui baisse quand l'âme penche
	// (nulle au bout de la balance). Ensuite, chaque point de tentation fait basculer
	// vers le camp de l'âme un choix libre (un neutre compte, sans changer de camp),
	// puis un choix de l'autre camp. Les choix libres restants sont tirés au hasard.
	private int, int, int OfferSplit()
	{
		let progression = mData.mProgression;
		let soul = mData.mSoul;
		int virtues = progression.mOfferVirtues;
		int sins = progression.mOfferSins;
		int free = progression.mOfferFree;

		int neutrals = 0;
		double chance = progression.mOfferNeutralChance * (1 - soul.Lean(mSoul));
		for (int i = 0; i < free; i++)
		{
			if (FRandom[SinwaveUpgrades](0, 1) < chance) neutrals++;
		}

		int side = soul.Side(mSoul);
		int pull = side != 0 ? soul.Temptation(mSoul) : 0;
		int fromFree = min(pull, free - neutrals);
		int fromOther = min(max(0, pull - free), side > 0 ? virtues : sins);
		if (side > 0)
		{
			sins += fromFree + fromOther;
			virtues -= fromOther;
		}
		else if (side < 0)
		{
			virtues += fromFree + fromOther;
			sins -= fromOther;
		}
		for (int i = 0; i < free - neutrals - fromFree; i++)
		{
			if (Random[SinwaveUpgrades](0, 1) == 0) virtues++;
			else sins++;
		}
		return virtues, neutrals, sins;
	}

	// Ajoute à la proposition jusqu'à `count` améliorations de la famille demandée,
	// différentes et pas encore proposées. Renvoie le nombre ajouté.
	private int PickRandom(int kind, int count)
	{
		Array<int> candidates;
		for (int i = 0; i < mData.mUpgrades.Size(); i++)
		{
			let upgrade = mData.mUpgrades[i];
			if (upgrade.mKind != kind || mStacks[i] >= upgrade.mMaxStacks) continue;
			if (mOffer.Find(upgrade) < mOffer.Size()) continue;
			candidates.Push(i);
		}
		int added = 0;
		while (added < count && candidates.Size() > 0)
		{
			int pick = Random[SinwaveUpgrades](0, candidates.Size() - 1);
			mOffer.Push(mData.mUpgrades[candidates[pick]]);
			candidates.Delete(pick);
			added++;
		}
		return added;
	}

	private void Pick(int index)
	{
		if (index < 0 || index >= mOffer.Size()) return;
		let upgrade = mOffer[index];
		for (int i = 0; i < mData.mUpgrades.Size(); i++)
		{
			if (mData.mUpgrades[i] == upgrade) mStacks[i]++;
		}
		mOffer.Clear();
		mPending--;

		mBus.Publish(Sinwave_UpgradeChosenEvent.Create(upgrade));
		for (int i = 0; i < upgrade.mEffects.Size(); i++)
		{
			mBus.Publish(Sinwave_EffectGrantedEvent.Create(upgrade.mEffects[i], upgrade.mName));
		}
		if (mPending > 0) MakeOffer();
	}
}
