// =============================================================================
//  Présentateur : traduit les événements du jeu en données d'affichage.
// =============================================================================
//
//  Écoute : tout.  Publie : rien.
//
//  C'est un système comme les autres (côté jeu) : il remplit Sinwave_HudModel.
//  Le HUD et les menus lisent ensuite ce modèle. Désactiver ce système dans
//  data/systems.txt retire l'interface sans empêcher le jeu de tourner.

class Sinwave_HudPresenter : Sinwave_System
{
	const BANNER_TICS = 3 * TICRATE;

	private Sinwave_HudModel mModel;
	private bool mSuspended;

	override void Setup()
	{
		mModel = Sinwave_HudModel.From(mServices);
		mBus.Subscribe(self);
	}

	override void Tick()
	{
		if (mModel.mBannerTics > 0) mModel.mBannerTics--;
		if (mModel.mRunActive && !mSuspended)
		{
			mModel.mRunTics++;
			if (mModel.mWaveTicsLeft > 0) mModel.mWaveTicsLeft--;
		}
	}

	override void OnEvent(Sinwave_Event e)
	{
		let m = mModel;

		let changed = Sinwave_StateChangedEvent(e);
		if (changed != null)
		{
			m.mScreen = ScreenFor(changed.mTo);
			if (m.mScreen == Sinwave_HudModel.SCREEN_PAUSE) m.mPauseSerial++;
			return;
		}
		if (e is 'Sinwave_RunStartedEvent')
		{
			m.mRunActive = true;
			m.mRunTics = 0;
			m.mScore = 0;
			m.mKills = 0;
			m.mResultReady = false;
			ShowBanner("Le Purgatoire s'ouvre...");
			return;
		}
		if (e is 'Sinwave_RunSuspendedEvent') { mSuspended = true; return; }
		if (e is 'Sinwave_RunResumedEvent') { mSuspended = false; return; }

		let ended = Sinwave_RunEndedEvent(e);
		if (ended != null)
		{
			m.mRunActive = false;
			m.mEndReason = ended.mReason;
			m.mBannerTics = 0;
			return;
		}
		let wave = Sinwave_WaveStartedEvent(e);
		if (wave != null)
		{
			m.mWave = wave.mIndex;
			m.mWaveCount = wave.mCount;
			m.mWaveName = wave.mName;
			m.mWaveTicsLeft = wave.mDurationTics;
			m.mBetweenWaves = false;
			ShowBanner(wave.mName);
			return;
		}
		if (e is 'Sinwave_WaveEndedEvent')
		{
			m.mBetweenWaves = true;
			m.mWaveTicsLeft = 0;
			return;
		}
		let score = Sinwave_ScoreChangedEvent(e);
		if (score != null)
		{
			m.mScore = score.mScore;
			m.mKills = score.mKills;
			return;
		}
		let xp = Sinwave_XpChangedEvent(e);
		if (xp != null)
		{
			m.mXp = xp.mXp;
			m.mXpNeeded = xp.mNeeded;
			m.mLevel = xp.mLevel;
			return;
		}
		let levelUp = Sinwave_LevelUpEvent(e);
		if (levelUp != null)
		{
			ShowBanner(String.Format("Niveau %d !", levelUp.mLevel));
			return;
		}
		let offer = Sinwave_UpgradeOfferedEvent(e);
		if (offer != null)
		{
			m.mOfferNames.Clear();
			m.mOfferDescriptions.Clear();
			for (int i = 0; i < offer.mChoices.Size(); i++)
			{
				m.mOfferNames.Push(offer.mChoices[i].mName);
				m.mOfferDescriptions.Push(offer.mChoices[i].mDescription);
			}
			m.mOfferSerial++;
			return;
		}
		let chosen = Sinwave_UpgradeChosenEvent(e);
		if (chosen != null)
		{
			ShowBanner(chosen.mUpgrade.mName .. " t'accompagne");
			return;
		}
		let loaded = Sinwave_MetaLoadedEvent(e);
		if (loaded != null)
		{
			m.mSouls = loaded.mMeta.mSouls;
			m.mBestScore = loaded.mMeta.mBestScore;
			m.mRuns = loaded.mMeta.mRuns;
			m.mNextUnlockName = loaded.mNextUnlock != null ? loaded.mNextUnlock.mName : "";
			m.mNextUnlockSouls = loaded.mNextUnlock != null ? loaded.mNextUnlock.mSoulsRequired : 0;
			return;
		}
		let saved = Sinwave_MetaSavedEvent(e);
		if (saved != null)
		{
			m.mSoulsEarned = saved.mSoulsEarned;
			m.mNewBest = saved.mNewBest;
			m.mUnlocked = saved.mUnlocked;
			m.mResultReady = true;
		}
	}

	private void ShowBanner(String text)
	{
		mModel.mBanner = text;
		mModel.mBannerTics = BANNER_TICS;
	}

	private static int ScreenFor(Name stateId)
	{
		switch (stateId)
		{
		case 'Menu':		return Sinwave_HudModel.SCREEN_MENU;
		case 'InGame':		return Sinwave_HudModel.SCREEN_RUN;
		case 'Pause':		return Sinwave_HudModel.SCREEN_PAUSE;
		case 'Upgrade':		return Sinwave_HudModel.SCREEN_UPGRADE;
		case 'GameOver':	return Sinwave_HudModel.SCREEN_GAMEOVER;
		}
		return Sinwave_HudModel.SCREEN_NONE;
	}
}
