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
	int mWave;
	int mWaveCount;
	String mWaveName;
	int mWaveTicsLeft;		// 0 pendant un cercle de boss
	bool mBetweenWaves;
	String mCurseName;
	String mCurseDescription;
	int mCorruption;
	int mCorruptionThreshold;

	// Boss
	bool mBossActive;
	String mBossName;
	double mBossHealth;		// fraction de 0 à 1
	bool mBossEnraged;

	// Méta-progression
	int mIndulgences;
	int mBestScore;
	int mRuns;

	// Choix d'une vertu ou d'un péché. Le numéro change à chaque proposition.
	int mOfferSerial;
	Array<String> mOfferNames;
	Array<String> mOfferDescriptions;
	Array<bool> mOfferIsSin;
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

	// Boutique : une ligne par article. mShopRevision change à chaque achat.
	int mShopSerial;
	int mShopRevision;
	Array<String> mShopNames;
	Array<String> mShopDescriptions;
	Array<int> mShopPrices;
	Array<int> mShopLevels;
	Array<int> mShopMaxLevels;
	Array<bool> mShopIsWeapon;
	String mShopMessage;
	bool mShopMessageOk;

	// Bilan de fin de run
	int mEndReason;
	bool mResultReady;
	int mEarned;
	bool mNewBest;
	bool mDamned;

	// Bandeau temporaire au centre de l'écran
	String mBanner;
	String mBannerDetail;
	int mBannerTics;

	static Sinwave_HudModel From(Sinwave_Services services)
	{
		return Sinwave_HudModel(services.Get('HudModel'));
	}
}
