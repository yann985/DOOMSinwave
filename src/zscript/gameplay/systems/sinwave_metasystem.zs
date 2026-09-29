// =============================================================================
//  Méta-progression : indulgences, record et boutique, conservés entre les runs.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, ScoreChanged, CircleEnded, CorruptionChanged,
//           ShopBuyRequested, GameLoaded
//  Publie : MetaLoaded, MetaSaved, Purchase, EffectGranted (achats de la boutique)
//
//  Gagner : à la fin de la run, les indulgences viennent du score, des cercles
//  franchis et du verdict (Absolution, Purgatoire ou Damnation), multipliées par la
//  récompense de l'arène et celle des règles de la descente (difficulté).
//  Dépenser : à la boutique, entre les runs, contre des armes et des améliorations
//  permanentes, accordées au début de chaque run.
//  Juger : à la fin de la run, le Jugement (data/judgement.txt) bouge selon le
//  palier de l'âme atteint ; il décide des rayons ouverts de la boutique. Un
//  article déjà acheté reste achetable, même si son rayon se referme.
//
//  Ne connaît ni les vagues, ni le score, ni la corruption : il retient seulement
//  les valeurs annoncées sur le bus, et passe par le service de sauvegarde sans
//  savoir comment celui-ci enregistre les données.

class Sinwave_MetaSystem : Sinwave_System
{
	private Sinwave_SaveService mSave;
	private Sinwave_GameData mData;
	private Sinwave_MetaData mMeta;
	private bool mRunning;
	private int mScore;
	private int mCirclesEnded;
	private int mVerdict;	// Sinwave_CorruptionChangedEvent.VERDICT_...
	private int mSoulSide;	// côté et palier de l'âme, pour le Jugement
	private int mSoulLevel;

	override void Setup()
	{
		mSave = Sinwave_SaveService.From(mServices);
		mData = Sinwave_GameData.From(mServices);
		mMeta = LoadMeta();
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_ScoreChangedEvent');
		mBus.Subscribe(self, 'Sinwave_CircleEndedEvent');
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
		mBus.Subscribe(self, 'Sinwave_ShopBuyRequestedEvent');
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
			mCirclesEnded = 0;
			mVerdict = Sinwave_CorruptionChangedEvent.VERDICT_PURGATORY;
			mSoulSide = 0;
			mSoulLevel = 0;
			GrantPurchases();
		}
		else if (e is 'Sinwave_ScoreChangedEvent')
		{
			mScore = Sinwave_ScoreChangedEvent(e).mScore;
		}
		else if (e is 'Sinwave_CircleEndedEvent')
		{
			mCirclesEnded++;
		}
		else if (e is 'Sinwave_CorruptionChangedEvent')
		{
			let soul = Sinwave_CorruptionChangedEvent(e);
			mVerdict = soul.Verdict();
			mSoulSide = soul.mSide;
			mSoulLevel = soul.mLevel;
		}
		else if (e is 'Sinwave_RunEndedEvent' && mRunning)
		{
			mRunning = false;
			SaveRun(Sinwave_RunEndedEvent(e).mReason);
		}
		else if (e is 'Sinwave_ShopBuyRequestedEvent')
		{
			Buy(Sinwave_ShopBuyRequestedEvent(e).mIndex);
		}
		else if (e is 'Sinwave_GameLoadedEvent')
		{
			// La sauvegarde de partie contient d'anciennes valeurs : on relit la méta.
			mMeta = LoadMeta();
			PublishMeta();
		}
	}

	// Un Jugement jamais fixé (première partie) part de la neutralité.
	private Sinwave_MetaData LoadMeta()
	{
		let metaData = mSave.Load();
		if (metaData.mJudgement < 0) metaData.mJudgement = mData.mJudgement.mNeutral;
		return metaData;
	}

	// Chaque niveau acheté d'un article applique ses effets au début de la run.
	private void GrantPurchases()
	{
		for (int i = 0; i < mData.mShopItems.Size(); i++)
		{
			let item = mData.mShopItems[i];
			int level = mMeta.GetLevel(item.mId);
			for (int n = 0; n < level; n++)
			{
				for (int k = 0; k < item.mEffects.Size(); k++)
				{
					mBus.Publish(Sinwave_EffectGrantedEvent.Create(item.mEffects[k], item.mName));
				}
			}
		}
	}

	private void Buy(int index)
	{
		if (index < 0 || index >= mData.mShopItems.Size()) return;
		let item = mData.mShopItems[index];

		if (mRunning)
		{
			mBus.Publish(Sinwave_PurchaseEvent.Create(item, false, "La boutique est fermée pendant une run."));
			return;
		}
		int level = mMeta.GetLevel(item.mId);
		if (!mData.mJudgement.CanBuy(item, mMeta.mJudgement, level))
		{
			mBus.Publish(Sinwave_PurchaseEvent.Create(item, false, "Verrouillé. " .. mData.mJudgement.Requirement(item) .. "."));
			return;
		}
		if (level >= item.mMaxLevel)
		{
			mBus.Publish(Sinwave_PurchaseEvent.Create(item, false, "Déjà au niveau maximum."));
			return;
		}
		int price = item.PriceForLevel(level);
		if (mMeta.mIndulgences < price)
		{
			mBus.Publish(Sinwave_PurchaseEvent.Create(item, false, "Pas assez d'indulgences."));
			return;
		}

		mMeta.mIndulgences -= price;
		mMeta.SetLevel(item.mId, level + 1);
		mSave.Save(mMeta);
		mBus.Publish(Sinwave_PurchaseEvent.Create(item, true, item.mName .. " acquis !"));
		PublishMeta();
	}

	private void SaveRun(int reason)
	{
		let progression = mData.mProgression;
		int earned = mScore / progression.mIndulgencesPerScore + mCirclesEnded * progression.mIndulgencesPerCircle;
		if (reason == Sinwave_RunEndedEvent.REASON_VICTORY)
		{
			switch (mVerdict)
			{
			case Sinwave_CorruptionChangedEvent.VERDICT_ABSOLUTION:	earned += progression.mIndulgencesAbsolution; break;
			case Sinwave_CorruptionChangedEvent.VERDICT_DAMNATION:	earned += progression.mIndulgencesDamnation; break;
			default:												earned += progression.mIndulgencesPurgatory; break;
			}
		}
		// Arènes et règles plus dures rapportent davantage.
		earned = int(earned * mData.mArena.mRewardFactor * Sinwave_RunRules.From(mServices).RewardFactor() + 0.5);

		mMeta.mIndulgences += earned;
		mMeta.mRuns++;
		bool newBest = mScore > mMeta.mBestScore;
		if (newBest) mMeta.mBestScore = mScore;
		int judgementBefore = mMeta.mJudgement;
		mMeta.mJudgement = mData.mJudgement.AfterRun(judgementBefore, mSoulSide, mSoulLevel);
		mSave.Save(mMeta);

		mBus.Publish(Sinwave_MetaSavedEvent.Create(mMeta, earned, newBest, mVerdict, judgementBefore));
		PublishMeta();
	}

	private void PublishMeta()
	{
		mBus.Publish(Sinwave_MetaLoadedEvent.Create(mMeta));
	}
}
