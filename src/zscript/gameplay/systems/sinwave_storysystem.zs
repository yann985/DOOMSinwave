// =============================================================================
//  Mode histoire : le récit entre les cercles, selon l'âme du joueur.
// =============================================================================
//
//  Écoute : CircleStarted, CorruptionChanged, RunEnded
//  Publie : StoryShown
//
//  Un cercle peut porter un texte (clé « story » de data/waves/...) et une arène un
//  texte de victoire et de mort (clés « ending » et « death » de data/arenas.txt).
//  Les textes sont dans data/story.txt, avec une variante par côté de l'âme : le
//  système choisit la bonne d'après le dernier palier annoncé. Il ne sait pas comment
//  le texte est affiché : l'interface s'en charge.
//
//  La corruption n'est pas remise à zéro au début d'une run : CircleStarted, publié
//  pendant RunStarted, peut arriver avant lui. Elle l'est à la fin de chaque run.

class Sinwave_StorySystem : Sinwave_System
{
	private Sinwave_GameData mData;
	private int mCorruption;
	private int mSide;		// côté du palier de l'âme atteint (0 : aucun)

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self, 'Sinwave_CircleStartedEvent');
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		ResetSoul();
	}

	override void OnEvent(Sinwave_Event e)
	{
		let started = Sinwave_CircleStartedEvent(e);
		if (started != null)
		{
			if (started.mIndex < mData.mCircles.Size()) Show(mData.mCircles[started.mIndex].mStoryId);
			return;
		}
		let soul = Sinwave_CorruptionChangedEvent(e);
		if (soul != null)
		{
			mCorruption = soul.mCorruption;
			mSide = soul.mLevel > 0 ? soul.mSide : 0;
			return;
		}
		let ended = Sinwave_RunEndedEvent(e);
		if (ended != null)
		{
			if (ended.mReason == Sinwave_RunEndedEvent.REASON_VICTORY) Show(mData.mArena.mEndingId);
			else if (ended.mReason == Sinwave_RunEndedEvent.REASON_DEATH) Show(mData.mArena.mDeathId);
			ResetSoul();
		}
	}

	private void Show(Name id)
	{
		let def = mData.FindStory(id);
		if (def == null) return;
		String text = def.TextFor(mSide, mCorruption >= mData.mSoul.mMax);
		mBus.Publish(Sinwave_StoryShownEvent.Create(def.mId, def.mTitle, text));
	}

	private void ResetSoul()
	{
		mCorruption = mData.mSoul.mBalance;
		mSide = 0;
	}
}
