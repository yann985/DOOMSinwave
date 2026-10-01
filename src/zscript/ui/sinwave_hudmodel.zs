// =============================================================================
//  Modèle de l'interface.
// =============================================================================
//
//  Tout ce que l'interface affiche, et rien d'autre. Il est écrit uniquement par
//  Sinwave_HudPresenter (côté jeu) et seulement LU par le HUD et les menus (côté
//  interface). ZScript le garantit : la classe est de portée « play », donc le
//  code « ui » ne peut pas la modifier (le compilateur le refuse).

class Sinwave_HudModel : Sinwave_Service
{
	enum EScreen
	{
		SCREEN_NONE,
		SCREEN_MENU,
		SCREEN_ARENA_SELECT,
		SCREEN_RULES,
		SCREEN_SHOP,
		SCREEN_RUN,
		SCREEN_PAUSE,
		SCREEN_UPGRADE,
		SCREEN_GAMEOVER
	}

	int mScreen;

	// Arène courante
	String mArenaName;
	String mArenaDescription;

	// Run en cours
	bool mRunActive;
	int mRunTics;
	int mScore;
	int mKills;
	int mLevel;
	int mXp;
	int mXpNeeded;
	int mCircle;
	int mCircleCount;
	String mCircleName;
	int mWave;				// vague en cours dans le cercle
	int mWaveCount;			// vagues du cercle
	int mWaveTicsLeft;		// 0 pendant la vague du boss
	bool mBetweenWaves;		// répit entre deux vagues du cercle
	bool mBetweenCircles;	// répit avant le cercle suivant
	String mCurseName;
	String mCurseDescription;
	String mChallengeDescription;	// défi du péché coché pour ce cercle (vide : aucun)
	// Balance de l'âme (data/soul.txt)
	int mCorruption;
	int mSoulMin;
	int mSoulMax;
	int mSoulBalance;
	int mSoulSide;				// +1 : péché ; -1 : vertu ; 0 : équilibre
	int mSoulLevel;				// paliers atteints (0 à 3)
	String mSoulTierName;		// le plus extrême des paliers atteints, ou « équilibre »
	Array<int> mSoulMarks;		// position des paliers, pour la jauge

	// Attaques qui se préparent contre le joueur (Sinwave_ThreatSystem). Le HUD ne
	// montre que celles venues de l'angle mort, en suivant leur source.
	Array<Actor> mThreatSources;	// ennemi ou projectile
	Array<int> mThreatAge;			// tics depuis l'annonce (apparition en fondu)
	Array<int> mThreatFade;			// -1 : en cours ; sinon tics restants du fondu de fin

	// Boss
	bool mBossActive;
	String mBossName;
	double mBossHealth;		// fraction de 0 à 1
	bool mBossEnraged;

	// Méta-progression
	int mIndulgences;
	int mBestScore;
	int mRuns;
	// Jugement de l'âme, gardé d'une run à l'autre (data/judgement.txt)
	int mJudgement;
	int mJudgementMin;
	int mJudgementMax;
	int mJudgementNeutral;
	int mJudgementNeutralZone;			// rayon Équilibre ouvert à cette distance du neutre
	Array<int> mJudgementGraceTiers;		// seuils de Grâce I, II, III, pour la jauge
	Array<int> mJudgementCorruptionTiers;	// seuils de Corruption I, II, III
	int mJudgementTier;			// -3 à -1 : Grâce ; 0 : neutralité ; 1 à 3 : Corruption
	String mJudgementTierName;
	int mJudgementBefore;		// Jugement avant la dernière run (égal au Jugement s'il n'y en a pas eu)

	// Choix d'une vertu, d'un neutre ou d'un péché. Le numéro change à chaque proposition.
	int mOfferSerial;
	Array<String> mOfferNames;
	Array<String> mOfferDescriptions;
	Array<int> mOfferKinds;			// Sinwave_UpgradeDef.KIND_...
	Array<int> mOfferCorruption;

	// Pause (numéro de la pause en cours, pour n'ouvrir le menu qu'une fois)
	int mPauseSerial;

	// Choix de l'arène
	int mArenaSelectSerial;
	int mCurrentArena;
	Array<String> mArenaNames;
	Array<String> mArenaDescriptions;

	// Règles de la descente. mRulesRevision change à chaque réglage.
	int mRulesSerial;
	int mRulesRevision;
	String mRulesArenaName;
	String mRulesPresetName;		// vide : défi personnalisé
	String mRulesPresetDescription;
	double mRulesEnemyHealth;
	double mRulesEnemySpeed;
	double mRulesSpawnRate;
	double mRulesDamageTaken;
	int mRulesStartCircle;
	int mRulesCircleCount;
	String mRulesCircleName;
	double mRulesReward;
	// Défis des péchés : une ligne par cercle de l'arène choisie.
	Array<String> mRulesChallengeCircles;	// nom du cercle
	Array<String> mRulesChallengeTexts;		// vide : pas de défi pour ce cercle
	Array<bool> mRulesChallengeOn;
	int mRulesChallengeCount;				// défis cochés

	// Boutique : une ligne par article. mShopRevision change à chaque achat.
	int mShopSerial;
	int mShopRevision;
	Array<String> mShopNames;
	Array<String> mShopDescriptions;
	Array<int> mShopPrices;
	Array<int> mShopLevels;
	Array<int> mShopMaxLevels;
	Array<bool> mShopIsWeapon;
	Array<int> mShopSides;			// rayon : Sinwave_ShopItemDef.SIDE_...
	Array<bool> mShopLocked;		// rayon fermé par le Jugement, et jamais acheté
	Array<String> mShopRequirements;
	Array<int> mShopRangeMin;		// Jugement qui ouvre l'article : de mShopRangeMin
	Array<int> mShopRangeMax;		// à mShopRangeMax
	String mShopMessage;
	bool mShopMessageOk;

	// Bilan de fin de run
	int mEndReason;
	bool mResultReady;
	int mEarned;
	bool mNewBest;
	int mVerdict;				// Sinwave_CorruptionChangedEvent.VERDICT_...

	// Bandeau temporaire au centre de l'écran
	String mBanner;
	String mBannerDetail;
	int mBannerTics;

	// Mode histoire : le dernier texte à lire. Le numéro change à chaque texte.
	int mStorySerial;
	String mStoryTitle;
	String mStoryText;

	static Sinwave_HudModel From(Sinwave_Services services)
	{
		return Sinwave_HudModel(services.Get('HudModel'));
	}
}
