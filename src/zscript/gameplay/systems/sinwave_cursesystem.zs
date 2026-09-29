// =============================================================================
//  Malédictions de cercle.
// =============================================================================
//
//  Écoute : CircleStarted, CircleEnded, RunEnded, RunSuspended, RunResumed, et
//           transmet tout le reste à la malédiction active
//  Publie : CurseStarted, CurseEnded (+ ce que publient les malédictions)
//
//  Chaque cercle (data/waves/...) peut porter une malédiction (data/curses.txt)
//  qui change les règles tant que le cercle dure, sur toutes ses vagues et
//  pendant les répits entre elles. Le système ne sait pas ce que
//  fait une malédiction : il crée l'objet décrit par les données (pattern
//  Stratégie, voir gameplay/curses/) et lui transmet les événements.

class Sinwave_CurseSystem : Sinwave_System
{
	private Sinwave_GameData mData;
	private Sinwave_Curse mActive;
	private bool mSuspended;

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self);
	}

	override void OnEvent(Sinwave_Event e)
	{
		let started = Sinwave_CircleStartedEvent(e);
		if (started != null)
		{
			Activate(mData.mCircles[started.mIndex].mCurseId);
			return;
		}
		if (e is 'Sinwave_CircleEndedEvent' || e is 'Sinwave_RunEndedEvent')
		{
			Deactivate();
			return;
		}
		if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;

		if (mActive != null) mActive.OnEvent(e);
	}

	override void Tick()
	{
		if (mActive != null && !mSuspended) mActive.Tick();
	}

	private void Activate(Name curseId)
	{
		Deactivate();
		let def = mData.FindCurse(curseId);
		if (def == null) return;

		let type = (class<Sinwave_Curse>)(def.mClassName);
		if (type == null)
		{
			Console.Printf("\cg[Sinwave] %s n'est pas une malédiction.", def.mClassName);
			return;
		}
		mActive = Sinwave_Curse(new(type));
		mActive.Init(def, mServices);
		mBus.Publish(Sinwave_CurseStartedEvent.Create(def));
		mActive.Begin();
	}

	private void Deactivate()
	{
		if (mActive == null) return;
		let ending = mActive;
		mActive = null;
		ending.End();
		mBus.Publish(new('Sinwave_CurseEndedEvent'));
	}
}
