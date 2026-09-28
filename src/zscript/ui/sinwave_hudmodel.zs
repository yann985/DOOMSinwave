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
		SCREEN_RUN,
		SCREEN_PAUSE,
		SCREEN_UPGRADE,
		SCREEN_GAMEOVER
	}

	int mScreen;

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
	int mWaveTicsLeft;
	bool mBetweenWaves;

	// Méta-progression
	int mSouls;
	int mBestScore;
	int mRuns;
	String mNextUnlockName;
	int mNextUnlockSouls;

	// Choix d'amélioration. Le numéro change à chaque nouvelle proposition.
	int mOfferSerial;
	Array<String> mOfferNames;
	Array<String> mOfferDescriptions;

	// Numéro de la pause en cours (pour n'ouvrir le menu qu'une fois par pause).
	int mPauseSerial;

	// Bilan de fin de run
	int mEndReason;
	bool mResultReady;
	int mSoulsEarned;
	bool mNewBest;
	String mUnlocked;

	// Bandeau temporaire au centre de l'écran
	String mBanner;
	int mBannerTics;

	static Sinwave_HudModel From(Sinwave_Services services)
	{
		return Sinwave_HudModel(services.Get('HudModel'));
	}
}
