// =============================================================================
//  Corruption : ce que coûtent les péchés choisis pendant la run.
// =============================================================================
//
//  Écoute : RunStarted, UpgradeChosen
//  Publie : CorruptionChanged
//
//  Chaque amélioration porte une valeur de corruption (data/upgrades.txt) :
//  positive pour un péché, négative pour une vertu de pénitence. À la fin de la
//  run, la corruption décide du verdict : Absolution ou Damnation.

class Sinwave_CorruptionSystem : Sinwave_System
{
	private int mCorruption;
	private int mThreshold;

	override void Setup()
	{
		mThreshold = Sinwave_GameData.From(mServices).mProgression.mDamnationThreshold;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_UpgradeChosenEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mCorruption = 0;
		}
		else
		{
			let chosen = Sinwave_UpgradeChosenEvent(e);
			if (chosen == null || chosen.mUpgrade.mCorruption == 0) return;
			mCorruption = max(0, mCorruption + chosen.mUpgrade.mCorruption);
		}
		mBus.Publish(Sinwave_CorruptionChangedEvent.Create(mCorruption, mThreshold));
	}
}
