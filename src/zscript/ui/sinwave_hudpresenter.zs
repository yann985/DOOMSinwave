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
	const THREAT_FADE_TICS = 8;		// fondu de l'indicateur une fois l'attaque partie

	private Sinwave_HudModel mModel;
	private Sinwave_GameData mData;
	private int mTierBannerTime;	// instant du dernier bandeau de palier
	private bool mSuspended;

	override void Setup()
	{
		mModel = Sinwave_HudModel.From(mServices);
		mData = Sinwave_GameData.From(mServices);
		mTierBannerTime = -1;
		mBus.Subscribe(self);
	}

	override void Start()
	{
		let m = mModel;
		m.mArenaName = mData.mArena.mName;
		m.mArenaDescription = mData.mArena.mDescription;
		m.mCurrentArena = mData.mArenaIndex;
		let soul = mData.mSoul;
		m.mSoulMin = soul.mMin;
		m.mSoulMax = soul.mMax;
		m.mSoulBalance = soul.mBalance;
		m.mCorruption = soul.mBalance;
		m.mSoulTierName = "équilibre";
		for (int i = 0; i < soul.mTiers.Size(); i++) m.mSoulMarks.Push(soul.mTiers[i].mAt);
		let judgement = mData.mJudgement;
		m.mJudgementMin = judgement.mMin;
		m.mJudgementMax = judgement.mMax;
		m.mJudgementNeutral = judgement.mNeutral;
		m.mJudgementNeutralZone = judgement.mNeutralZone;
		m.mJudgementGraceTiers.Copy(judgement.mGraceTiers);
		m.mJudgementCorruptionTiers.Copy(judgement.mCorruptionTiers);
		for (int i = 0; i < mData.mArenas.Size(); i++)
		{
			m.mArenaNames.Push(mData.mArenas[i].mName);
			m.mArenaDescriptions.Push(mData.mArenas[i].mDescription);
		}
	}

	override void Tick()
	{
		if (mModel.mBannerTics > 0) mModel.mBannerTics--;
		TickThreats();
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
			else if (m.mScreen == Sinwave_HudModel.SCREEN_RULES) m.mRulesSerial++;
			return;
		}
		let rules = Sinwave_RulesChangedEvent(e);
		if (rules != null)
		{
			RefreshRules(rules.mRules);
			return;
		}
		if (e is 'Sinwave_RunStartedEvent')
		{
			m.mRunActive = true;
			m.mRunTics = 0;
			m.mScore = 0;
			m.mKills = 0;
			// La corruption n'est pas remise ici : CorruptionChanged, publié pendant
			// RunStarted, arrive avant lui et donne déjà l'équilibre de départ.
			m.mBossActive = false;
			m.mResultReady = false;
			// Pas de bandeau ici : le premier cercle, annoncé pendant RunStarted, a le sien.
			return;
		}
		if (e is 'Sinwave_ShopRequestedEvent' && m.mRunActive)
		{
			ShowBanner("La boutique ouvre entre les runs", "Termine ou abandonne la run (P ou Start) pour y accéder");
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
			m.mThreatSources.Clear();
			m.mThreatAge.Clear();
			m.mThreatFade.Clear();
			return;
		}
		let threat = Sinwave_ThreatStartedEvent(e);
		if (threat != null && threat.mSource != null)
		{
			int index = m.mThreatSources.Find(threat.mSource);
			if (index < m.mThreatSources.Size())
			{
				m.mThreatFade[index] = -1;	// la même source menace de nouveau
				return;
			}
			m.mThreatSources.Push(threat.mSource);
			m.mThreatAge.Push(0);
			m.mThreatFade.Push(-1);
			return;
		}
		let threatEnded = Sinwave_ThreatEndedEvent(e);
		if (threatEnded != null)
		{
			int index = m.mThreatSources.Find(threatEnded.mSource);
			if (index < m.mThreatSources.Size()) m.mThreatFade[index] = THREAT_FADE_TICS;
			return;
		}
		let circle = Sinwave_CircleStartedEvent(e);
		if (circle != null)
		{
			m.mCircle = circle.mIndex;
			m.mCircleCount = circle.mCount;
			m.mCircleName = circle.mName;
			m.mBetweenCircles = false;
			// La malédiction du cercle peut être annoncée avant ou après lui (le bus ne
			// garantit pas l'ordre) : on ne l'efface pas ici, CurseEnded s'en charge à la
			// fin du cercle précédent, et le bandeau reprend celle déjà connue.
			ShowBanner(String.Format("Cercle %d : %s", circle.mIndex + 1, circle.mName), m.mCurseDescription);
			return;
		}
		let wave = Sinwave_WaveStartedEvent(e);
		if (wave != null)
		{
			m.mWave = wave.mIndex;
			m.mWaveCount = wave.mCount;
			m.mWaveTicsLeft = wave.mDurationTics;
			m.mBetweenWaves = false;
			// La première vague partage le bandeau du cercle.
			if (wave.mIndex > 0)
			{
				String detail = wave.mDurationTics == 0 ? "Le boss arrive !" : "Les damnés se pressent...";
				ShowBanner(String.Format("Vague %d/%d", wave.mIndex + 1, wave.mCount), detail);
			}
			return;
		}
		let waveEnded = Sinwave_WaveEndedEvent(e);
		if (waveEnded != null)
		{
			m.mBetweenWaves = waveEnded.mIndex + 1 < m.mWaveCount;
			m.mWaveTicsLeft = 0;
			return;
		}
		if (e is 'Sinwave_CircleEndedEvent')
		{
			m.mBetweenWaves = false;
			m.mBetweenCircles = true;
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
			m.mSoulSide = corruption.mSide;
			m.mSoulLevel = corruption.mLevel;
			m.mSoulTierName = corruption.mTier != null ? corruption.mTier.mName : "équilibre";
			m.mVerdict = corruption.Verdict();
			return;
		}
		let trial = Sinwave_SoulTrialEvent(e);
		if (trial != null)
		{
			if (trial.mSide > 0) ShowBanner("Ton reflet damné surgit !", "Abats-le : il porte une part de ton âme (beaucoup d'XP)");
			else ShowBanner("Un ange te visite", "Sa lumière referme tes plaies");
			return;
		}
		let tier = Sinwave_SoulTierChangedEvent(e);
		if (tier != null)
		{
			if (tier.mReached) ShowBanner("Palier : " .. tier.mTier.mName, tier.mTier.mDescription);
			else ShowBanner(tier.mTier.mName .. " s'efface", "Ton âme revient vers l'équilibre");
			mTierBannerTime = level.maptime;
			return;
		}
		let offer = Sinwave_UpgradeOfferedEvent(e);
		if (offer != null)
		{
			m.mOfferNames.Clear();
			m.mOfferDescriptions.Clear();
			m.mOfferKinds.Clear();
			m.mOfferCorruption.Clear();
			for (int i = 0; i < offer.mChoices.Size(); i++)
			{
				let choice = offer.mChoices[i];
				m.mOfferNames.Push(choice.mName);
				m.mOfferDescriptions.Push(choice.mDescription);
				m.mOfferKinds.Push(choice.mKind);
				m.mOfferCorruption.Push(choice.mCorruption);
			}
			m.mOfferSerial++;
			return;
		}
		let chosen = Sinwave_UpgradeChosenEvent(e);
		if (chosen != null)
		{
			// Un palier franchi par ce choix a déjà son bandeau, plus important (il a pu
			// arriver avant ce choix : il est publié pendant sa diffusion).
			if (mTierBannerTime == level.maptime) return;
			let upgrade = chosen.mUpgrade;
			if (upgrade.mKind == Sinwave_UpgradeDef.KIND_SIN) ShowBanner(upgrade.mName .. " te corrompt", upgrade.mDescription);
			else if (upgrade.mKind == Sinwave_UpgradeDef.KIND_NEUTRAL) ShowBanner(upgrade.mName .. " te renforce", upgrade.mDescription);
			else ShowBanner(upgrade.mName .. " t'accompagne", upgrade.mDescription);
			return;
		}
		let loaded = Sinwave_MetaLoadedEvent(e);
		if (loaded != null)
		{
			m.mIndulgences = loaded.mMeta.mIndulgences;
			m.mBestScore = loaded.mMeta.mBestScore;
			m.mRuns = loaded.mMeta.mRuns;
			m.mJudgement = loaded.mMeta.mJudgement;
			m.mJudgementTier = mData.mJudgement.Tier(m.mJudgement);
			m.mJudgementTierName = Sinwave_JudgementDef.TierName(m.mJudgementTier);
			int last = loaded.mMeta.mJudgementLast;
			m.mJudgementBefore = last >= 0 ? last : m.mJudgement;
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
			m.mJudgementBefore = saved.mJudgementBefore;
			m.mResultReady = true;
		}
	}

	private void RefreshRules(Sinwave_RunRules rules)
	{
		let m = mModel;
		let preset = mData.FindDifficulty(rules.mPreset);
		m.mRulesPresetName = preset != null ? preset.mName : "";
		m.mRulesPresetDescription = preset != null ? preset.mDescription : "Défi personnalisé";
		m.mRulesEnemyHealth = rules.mEnemyHealth;
		m.mRulesEnemySpeed = rules.mEnemySpeed;
		m.mRulesSpawnRate = rules.mSpawnRate;
		m.mRulesDamageTaken = rules.mDamageTaken;
		m.mRulesStartCircle = rules.mStartCircle;
		m.mRulesReward = rules.RewardFactor();
		m.mRulesArenaName = "";
		m.mRulesCircleName = "";
		m.mRulesCircleCount = 0;
		if (rules.mArenaIndex < mData.mArenas.Size())
		{
			let arena = mData.mArenas[rules.mArenaIndex];
			m.mRulesArenaName = arena.mName;
			m.mRulesCircleCount = arena.mCircleNames.Size();
			if (rules.mStartCircle <= arena.mCircleNames.Size()) m.mRulesCircleName = arena.mCircleNames[rules.mStartCircle - 1];
		}
		m.mRulesRevision++;
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
		m.mShopSides.Clear();
		m.mShopLocked.Clear();
		m.mShopRequirements.Clear();
		m.mShopRangeMin.Clear();
		m.mShopRangeMax.Clear();
		let judgement = mData.mJudgement;
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
			m.mShopSides.Push(item.mSide);
			m.mShopLocked.Push(!judgement.CanBuy(item, metaData.mJudgement, level));
			String requirement = judgement.Requirement(item);
			int distance = judgement.Distance(item, metaData.mJudgement);
			if (distance > 0) requirement = requirement .. String.Format(" (encore %d)", distance);
			m.mShopRequirements.Push(requirement);
			int low, high;
			[low, high] = judgement.Range(item);
			m.mShopRangeMin.Push(low);
			m.mShopRangeMax.Push(high);
		}
		m.mShopRevision++;
	}

	// Menaces : apparition, fondu de fin, et retrait des sources disparues (un
	// projectile arrivé n'est plus une menace : l'indicateur s'éteint à l'impact).
	private void TickThreats()
	{
		let m = mModel;
		for (int i = m.mThreatSources.Size() - 1; i >= 0; i--)
		{
			m.mThreatAge[i]++;
			if (m.mThreatFade[i] > 0) m.mThreatFade[i]--;
			// Disparue : ennemi mort, ou projectile qui a touché (il n'est plus un projectile).
			let source = m.mThreatSources[i];
			bool gone = source == null || (source.bIsMonster ? source.health <= 0 : !source.bMissile);
			if (gone || m.mThreatFade[i] == 0)
			{
				m.mThreatSources.Delete(i);
				m.mThreatAge.Delete(i);
				m.mThreatFade.Delete(i);
			}
		}
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
		case 'Rules':		return Sinwave_HudModel.SCREEN_RULES;
		case 'Shop':		return Sinwave_HudModel.SCREEN_SHOP;
		case 'InGame':		return Sinwave_HudModel.SCREEN_RUN;
		case 'Pause':		return Sinwave_HudModel.SCREEN_PAUSE;
		case 'Upgrade':		return Sinwave_HudModel.SCREEN_UPGRADE;
		case 'GameOver':	return Sinwave_HudModel.SCREEN_GAMEOVER;
		}
		return Sinwave_HudModel.SCREEN_NONE;
	}
}
