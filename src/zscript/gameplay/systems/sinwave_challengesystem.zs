// =============================================================================
//  Défis des péchés : une contrainte en plus, cochée pour un cercle.
// =============================================================================
//
//  Écoute : CircleStarted, CircleEnded, RunEnded
//  Publie : ChallengeStarted, ChallengeEnded, EffectGranted
//
//  Dans les règles de la descente, le joueur peut cocher le défi de chaque cercle
//  (service Rules). Le défi est décrit par la malédiction du cercle (data/curses.txt,
//  clés challenge...). Ce système applique ses effets sur le joueur pendant le
//  cercle, comme une vertu, puis les retire ; les vagues et le butin lisent ses
//  autres réglages dans ChallengeStarted.

class Sinwave_ChallengeSystem : Sinwave_System
{
	private Sinwave_GameData mData;
	private Sinwave_RunRules mRules;
	private Sinwave_CurseDef mActive;

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mRules = Sinwave_RunRules.From(mServices);
		mBus.Subscribe(self, 'Sinwave_CircleStartedEvent');
		mBus.Subscribe(self, 'Sinwave_CircleEndedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		let started = Sinwave_CircleStartedEvent(e);
		if (started != null)
		{
			Finish();
			if (!mRules.HasChallenge(started.mIndex) || started.mIndex >= mData.mCircles.Size()) return;
			let curse = mData.FindCurse(mData.mCircles[started.mIndex].mCurseId);
			if (curse != null && curse.HasChallenge()) Launch(curse);
			return;
		}
		Finish();	// fin du cercle ou de la run
	}

	private void Launch(Sinwave_CurseDef def)
	{
		mActive = def;
		mBus.Publish(Sinwave_ChallengeStartedEvent.Create(def));
		for (int i = 0; i < def.mChallengeEffects.Size(); i++)
		{
			mBus.Publish(Sinwave_EffectGrantedEvent.Create(def.mChallengeEffects[i], "Défi : " .. def.mName));
		}
	}

	private void Finish()
	{
		if (mActive == null) return;
		let ending = mActive;
		mActive = null;
		for (int i = 0; i < ending.mChallengeEffects.Size(); i++)
		{
			let undo = ending.mChallengeEffects[i].Negated();
			if (undo != null) mBus.Publish(Sinwave_EffectGrantedEvent.Create(undo, "Défi : " .. ending.mName));
		}
		mBus.Publish(new('Sinwave_ChallengeEndedEvent'));
	}
}
