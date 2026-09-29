// =============================================================================
//  Choix d'une vertu ou d'un péché à la montée de niveau.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, LevelUp, UpgradePicked
//  Publie : UpgradeOffered, UpgradeChosen, EffectGranted
//
//  Propose des vertus (sûres) et des péchés (puissants, avec un défaut et de la
//  corruption), tirés au hasard dans data/upgrades.txt en respectant leur maximum
//  par run. Ce système ne sait pas ce que fait un effet : il publie EffectGranted
//  et le système concerné l'applique. Il ne gère pas non plus la corruption :
//  Sinwave_CorruptionSystem réagit à UpgradeChosen.

class Sinwave_UpgradeSystem : Sinwave_System
{
	private Sinwave_GameData mData;
	private bool mRunning;
	private Array<int> mStacks;					// nombre de prises, par amélioration
	private Array<Sinwave_UpgradeDef> mOffer;	// proposition en cours
	private int mPending;						// niveaux gagnés pas encore récompensés

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_LevelUpEvent');
		mBus.Subscribe(self, 'Sinwave_UpgradePickedEvent');
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
	}

	private void MakeOffer()
	{
		mOffer.Clear();
		PickRandom(false, mData.mProgression.mOfferVirtues);
		PickRandom(true, mData.mProgression.mOfferSins);
		if (mOffer.Size() == 0)
		{
			mPending = 0;	// tout est au maximum : plus rien à proposer
			return;
		}

		let offer = new('Sinwave_UpgradeOfferedEvent');
		for (int i = 0; i < mOffer.Size(); i++) offer.mChoices.Push(mOffer[i]);
		mBus.Publish(offer);
	}

	// Ajoute à la proposition `count` améliorations différentes du type demandé.
	private void PickRandom(bool sins, int count)
	{
		Array<int> candidates;
		for (int i = 0; i < mData.mUpgrades.Size(); i++)
		{
			let upgrade = mData.mUpgrades[i];
			if (upgrade.mIsSin == sins && mStacks[i] < upgrade.mMaxStacks) candidates.Push(i);
		}
		for (int n = 0; n < count && candidates.Size() > 0; n++)
		{
			int pick = Random[SinwaveUpgrades](0, candidates.Size() - 1);
			mOffer.Push(mData.mUpgrades[candidates[pick]]);
			candidates.Delete(pick);
		}
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
