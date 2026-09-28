// =============================================================================
//  Améliorations proposées à la montée de niveau.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, LevelUp, UpgradePicked
//  Publie : UpgradeOffered, UpgradeChosen, EffectGranted
//
//  Tire au hasard des améliorations dans GameData (en respectant leur maximum
//  par run). Ce système ne sait pas ce que fait une amélioration : il publie
//  EffectGranted, et le système concerné l'applique.

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
		Array<int> candidates;
		for (int i = 0; i < mData.mUpgrades.Size(); i++)
		{
			if (mStacks[i] < mData.mUpgrades[i].mMaxStacks) candidates.Push(i);
		}
		int count = min(mData.mProgression.mUpgradeChoices, candidates.Size());
		if (count == 0)
		{
			mPending = 0;	// tout est au maximum : plus rien à proposer
			return;
		}

		let offer = new('Sinwave_UpgradeOfferedEvent');
		for (int n = 0; n < count; n++)
		{
			int pick = Random[SinwaveUpgrades](0, candidates.Size() - 1);
			let upgrade = mData.mUpgrades[candidates[pick]];
			mOffer.Push(upgrade);
			offer.mChoices.Push(upgrade);
			candidates.Delete(pick);
		}
		mBus.Publish(offer);
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
		mBus.Publish(Sinwave_EffectGrantedEvent.Create(upgrade.mEffect, upgrade.mName));
		if (mPending > 0) MakeOffer();
	}
}
