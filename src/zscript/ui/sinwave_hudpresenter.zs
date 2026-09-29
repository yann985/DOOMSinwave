// =============================================================================
//  Présentateur : traduit les événements du jeu en données d'affichage.
// =============================================================================
//
//  Écoute : tout.  Publie : rien.
//
//  C'est un système comme les autres (côté jeu) : il remplit Sinwave_HudModel à
//  partir des événements et des données (liste des arènes, articles de la
//  boutique). Le HUD et les menus lisent ensuite ce modèle. Désactiver ce système
//  dans data/systems.txt retire l'interface sans empêcher le jeu de tourner.

class Sinwave_HudPresenter : Sinwave_System
{
	const BANNER_TICS = 3 * TICRATE;

	private Sinwave_HudModel mModel;
	private Sinwave_GameData mData;
	private bool mSuspended;

	override void Setup()
	{
		mModel = Sinwave_HudModel.From(mServices);
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self);
	}

	override void Start()
	{
		let m = mModel;
		m.mArenaName = mData.mArena.mName;
		m.mArenaDescription = mData.mArena.mDescription;
		m.mCurrentArena = mData.mArenaIndex;
		m.mCorruptionThreshold = mData.mProgression.mDamnationThreshold;
		for (int i = 0; i < mData.mArenas.Size(); i++)
		{
			m.mArenaNames.Push(mData.mArenas[i].mName);
			m.mArenaDescriptions.Push(mData.mArenas[i].mDescription);
		}
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
			else if (m.mScreen == Sinwave_HudModel.SCREEN_SHOP) { m.mShopSerial++; m.mShopMessage = ""; }
			else if (m.mScreen == Sinwave_HudModel.SCREEN_ARENA_SELECT) m.mArenaSelectSerial++;
			return;
		}
		if (e is 'Sinwave_RunStartedEvent')
		{
			m.mRunActive = true;
			m.mRunTics = 0;
			m.mScore = 0;
			m.mKills = 0;
			m.mCorruption = 0;
			m.mBossActive = false;
			m.mResultReady = false;
			ShowBanner(m.mArenaName, "La descente commence...");
			return;
		}
		if (e is 'Sinwave_RunSuspendedEvent') { mSuspended = true; return; }
		if (e is 'Sinwave_RunResumedEvent') { mSuspended = false; return; }

		let ended = Sinwave_RunEndedEvent(e);
		if (ended != null)
		{
			m.mRunActive = false;
			m.mBossActive = false;
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
			m.mCurseName = "";
			m.mCurseDescription = "";
			ShowBanner(String.Format("Cercle %d : %s", wave.mIndex + 1, wave.mName), "");
			return;
		}
		if (e is 'Sinwave_WaveEndedEvent')
		{
			m.mBetweenWaves = true;
			m.mWaveTicsLeft = 0;
			return;
		}
		let curse = Sinwave_CurseStartedEvent(e);
		if (curse != null)
		{
			m.mCurseName = curse.mDef.mName;
			m.mCurseDescription = curse.mDef.mDescription;
			m.mBannerDetail = curse.mDef.mDescription;
			return;
		}
		if (e is 'Sinwave_CurseEndedEvent')
		{
			m.mCurseName = "";
			m.mCurseDescription = "";
			return;
		}
		let boss = Sinwave_BossSpawnedEvent(e);
		if (boss != null)
		{
			m.mBossActive = true;
			m.mBossName = boss.mDef.mName;
			m.mBossHealth = 1;
			m.mBossEnraged = false;
			return;
		}
		let bossHealth = Sinwave_BossHealthChangedEvent(e);
		if (bossHealth != null) { m.mBossHealth = bossHealth.mFraction; return; }
		if (e is 'Sinwave_BossEnragedEvent')
		{
			m.mBossEnraged = true;
			ShowBanner(m.mBossName .. " entre en rage !", "Des renforts arrivent");
			return;
		}
		if (e is 'Sinwave_BossDefeatedEvent') { m.mBossActive = false; return; }

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
		let corruption = Sinwave_CorruptionChangedEvent(e);
		if (corruption != null)
		{
			m.mCorruption = corruption.mCorruption;
			m.mCorruptionThreshold = corruption.mThreshold;
			return;
		}
		let offer = Sinwave_UpgradeOfferedEvent(e);
		if (offer != null)
		{
			m.mOfferNames.Clear();
			m.mOfferDescriptions.Clear();
			m.mOfferIsSin.Clear();
			m.mOfferCorruption.Clear();
			for (int i = 0; i < offer.mChoices.Size(); i++)
			{
				let choice = offer.mChoices[i];
				m.mOfferNames.Push(choice.mName);
				m.mOfferDescriptions.Push(choice.mDescription);
				m.mOfferIsSin.Push(choice.mIsSin);
				m.mOfferCorruption.Push(choice.mCorruption);
			}
			m.mOfferSerial++;
			return;
		}
		let chosen = Sinwave_UpgradeChosenEvent(e);
		if (chosen != null)
		{
			let upgrade = chosen.mUpgrade;
			if (upgrade.mIsSin) ShowBanner(upgrade.mName .. " te corrompt", upgrade.mDescription);
			else ShowBanner(upgrade.mName .. " t'accompagne", upgrade.mDescription);
			return;
		}
		let loaded = Sinwave_MetaLoadedEvent(e);
		if (loaded != null)
		{
			m.mIndulgences = loaded.mMeta.mIndulgences;
			m.mBestScore = loaded.mMeta.mBestScore;
			m.mRuns = loaded.mMeta.mRuns;
			RefreshShop(loaded.mMeta);
			return;
		}
		let purchase = Sinwave_PurchaseEvent(e);
		if (purchase != null)
		{
			m.mShopMessage = purchase.mMessage;
			m.mShopMessageOk = purchase.mSuccess;
			m.mShopRevision++;
			return;
		}
		let saved = Sinwave_MetaSavedEvent(e);
		if (saved != null)
		{
			m.mEarned = saved.mEarned;
			m.mNewBest = saved.mNewBest;
			m.mDamned = saved.mDamned;
			m.mResultReady = true;
		}
	}

	// Une ligne par article : nom, niveau possédé et prix du niveau suivant.
	private void RefreshShop(Sinwave_MetaData metaData)
	{
		let m = mModel;
		m.mShopNames.Clear();
		m.mShopDescriptions.Clear();
		m.mShopPrices.Clear();
		m.mShopLevels.Clear();
		m.mShopMaxLevels.Clear();
		m.mShopIsWeapon.Clear();
		for (int i = 0; i < mData.mShopItems.Size(); i++)
		{
			let item = mData.mShopItems[i];
			int level = metaData.GetLevel(item.mId);
			m.mShopNames.Push(item.mName);
			m.mShopDescriptions.Push(item.mDescription);
			m.mShopPrices.Push(item.PriceForLevel(level));
			m.mShopLevels.Push(level);
			m.mShopMaxLevels.Push(item.mMaxLevel);
			m.mShopIsWeapon.Push(item.mIsWeapon);
		}
		m.mShopRevision++;
	}

	private void ShowBanner(String text, String detail)
	{
		mModel.mBanner = text;
		mModel.mBannerDetail = detail;
		mModel.mBannerTics = BANNER_TICS;
	}

	private static int ScreenFor(Name stateId)
	{
		switch (stateId)
		{
		case 'Menu':		return Sinwave_HudModel.SCREEN_MENU;
		case 'ArenaSelect':	return Sinwave_HudModel.SCREEN_ARENA_SELECT;
		case 'Shop':		return Sinwave_HudModel.SCREEN_SHOP;
		case 'InGame':		return Sinwave_HudModel.SCREEN_RUN;
		case 'Pause':		return Sinwave_HudModel.SCREEN_PAUSE;
		case 'Upgrade':		return Sinwave_HudModel.SCREEN_UPGRADE;
		case 'GameOver':	return Sinwave_HudModel.SCREEN_GAMEOVER;
		}
		return Sinwave_HudModel.SCREEN_NONE;
	}
}
