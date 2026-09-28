// =============================================================================
//  Méta-progression : âmes, record et déblocages conservés entre les runs.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, ScoreChanged, WaveEnded, GameLoaded
//  Publie : MetaLoaded, MetaSaved, EffectGranted (bénédictions débloquées)
//
//  Ne connaît ni les vagues ni le score : il retient seulement les valeurs
//  annoncées sur le bus, et passe par le service de sauvegarde (Sinwave_SaveService)
//  sans savoir comment celui-ci enregistre les données.

class Sinwave_MetaSystem : Sinwave_System
{
	private Sinwave_SaveService mSave;
	private Sinwave_GameData mData;
	private Sinwave_MetaData mMeta;
	private bool mRunning;
	private int mScore;
	private int mWavesEnded;

	override void Setup()
	{
		mSave = Sinwave_SaveService.From(mServices);
		mData = Sinwave_GameData.From(mServices);
		mMeta = mSave.Load();
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_ScoreChangedEvent');
		mBus.Subscribe(self, 'Sinwave_WaveEndedEvent');
		mBus.Subscribe(self, 'Sinwave_GameLoadedEvent');
	}

	override void Start()
	{
		PublishMeta();
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mScore = 0;
			mWavesEnded = 0;
			GrantUnlocks();
		}
		else if (e is 'Sinwave_ScoreChangedEvent')
		{
			mScore = Sinwave_ScoreChangedEvent(e).mScore;
		}
		else if (e is 'Sinwave_WaveEndedEvent')
		{
			mWavesEnded++;
		}
		else if (e is 'Sinwave_RunEndedEvent' && mRunning)
		{
			mRunning = false;
			SaveRun(Sinwave_RunEndedEvent(e).mReason);
		}
		else if (e is 'Sinwave_GameLoadedEvent')
		{
			// La sauvegarde de partie contient d'anciennes valeurs : on relit la méta.
			mMeta = mSave.Load();
			PublishMeta();
		}
	}

	// Chaque bénédiction débloquée est accordée au début de la run.
	private void GrantUnlocks()
	{
		for (int i = 0; i < mData.mUnlocks.Size(); i++)
		{
			let unlock = mData.mUnlocks[i];
			if (mMeta.mSouls >= unlock.mSoulsRequired)
			{
				mBus.Publish(Sinwave_EffectGrantedEvent.Create(unlock.mEffect, unlock.mName));
			}
		}
	}

	private void SaveRun(int reason)
	{
		let progression = mData.mProgression;
		int earned = mScore / progression.mSoulsPerScore + mWavesEnded * progression.mSoulsPerWave;
		if (reason == Sinwave_RunEndedEvent.REASON_VICTORY) earned += progression.mSoulsVictory;

		int soulsBefore = mMeta.mSouls;
		mMeta.mSouls += earned;
		mMeta.mRuns++;
		bool newBest = mScore > mMeta.mBestScore;
		if (newBest) mMeta.mBestScore = mScore;
		mSave.Save(mMeta);

		String unlocked = "";
		for (int i = 0; i < mData.mUnlocks.Size(); i++)
		{
			let unlock = mData.mUnlocks[i];
			if (soulsBefore < unlock.mSoulsRequired && mMeta.mSouls >= unlock.mSoulsRequired)
			{
				unlocked = unlocked .. (unlocked.Length() > 0 ? ", " : "") .. unlock.mName;
			}
		}

		mBus.Publish(Sinwave_MetaSavedEvent.Create(mMeta, earned, newBest, unlocked));
		PublishMeta();
	}

	private void PublishMeta()
	{
		mBus.Publish(Sinwave_MetaLoadedEvent.Create(mMeta, NextUnlock()));
	}

	// Le prochain déblocage à atteindre (le moins cher parmi ceux non obtenus).
	private Sinwave_UnlockDef NextUnlock()
	{
		Sinwave_UnlockDef next = null;
		for (int i = 0; i < mData.mUnlocks.Size(); i++)
		{
			let unlock = mData.mUnlocks[i];
			if (unlock.mSoulsRequired <= mMeta.mSouls) continue;
			if (next == null || unlock.mSoulsRequired < next.mSoulsRequired) next = unlock;
		}
		return next;
	}
}
