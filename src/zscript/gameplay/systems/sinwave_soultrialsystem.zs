// =============================================================================
//  Épreuves de l'âme : rester au bout de la balance a des conséquences.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, RunSuspended, RunResumed, CorruptionChanged
//  Publie : SoulTrial, SpawnRequested (côté péché), EffectGranted (côté vertu)
//
//  Côté péché : rester trial_seconds à la corruption maximale fait surgir ton
//  reflet damné (trial_enemy, data/soul.txt), un mini-boss qui rapporte
//  énormément d'XP. Côté vertu : rester autant à zéro fait venir un ange qui te
//  soigne. Une seule épreuve par séjour au bout de la balance.

class Sinwave_SoulTrialSystem : Sinwave_System
{
	private Sinwave_SoulDef mSoul;
	private bool mRunning;
	private bool mSuspended;
	private int mCorruption;
	private int mTics;		// temps passé au bout de la balance
	private bool mDone;		// épreuve déjà passée pendant ce séjour

	override void Setup()
	{
		mSoul = Sinwave_GameData.From(mServices).mSoul;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_RunSuspendedEvent');
		mBus.Subscribe(self, 'Sinwave_RunResumedEvent');
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mSuspended = false;
			mCorruption = mSoul.mBalance;
			mTics = 0;
			mDone = false;
		}
		else if (e is 'Sinwave_RunEndedEvent') mRunning = false;
		else if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;
		else if (e is 'Sinwave_CorruptionChangedEvent')
		{
			mCorruption = Sinwave_CorruptionChangedEvent(e).mCorruption;
			if (!AtExtreme())
			{
				mTics = 0;
				mDone = false;
			}
		}
	}

	override void Tick()
	{
		if (!mRunning || mSuspended || mDone || mSoul.mTrialTics <= 0 || !AtExtreme()) return;
		if (++mTics < mSoul.mTrialTics) return;
		mDone = true;
		if (mCorruption >= mSoul.mMax) SummonReflection();
		else SendAngel();
	}

	private bool AtExtreme()
	{
		return mCorruption >= mSoul.mMax || mCorruption <= mSoul.mMin;
	}

	private void SummonReflection()
	{
		if (mSoul.mTrialEnemy != 'None' && mSoul.mTrialEnemy != '') mBus.Publish(Sinwave_SpawnRequestedEvent.Create(mSoul.mTrialEnemy, 1));
		mBus.Publish(Sinwave_SoulTrialEvent.Create(1));
	}

	// L'ange soigne, dans une gerbe de lumière dorée qui monte autour du joueur.
	private void SendAngel()
	{
		mBus.Publish(Sinwave_EffectGrantedEvent.Create(Sinwave_Effect.Create('heal', mSoul.mAngelHeal), "Ange"));
		mBus.Publish(Sinwave_SoulTrialEvent.Create(-1));
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;
		pawn.A_StartSound("misc/p_pkup", CHAN_ITEM);
		for (int i = 0; i < 48; i++)
		{
			Vector2 dir = Actor.AngleToVector(i * 7.5);
			pawn.A_SpawnParticle(Color(255, 235, 150), SPF_FULLBRIGHT, 45, 10, 0,
				dir.x * 40, dir.y * 40, 8, dir.x * 0.5, dir.y * 0.5, 2.5);
		}
	}
}
