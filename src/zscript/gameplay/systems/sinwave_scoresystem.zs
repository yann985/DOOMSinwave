// =============================================================================
//  Score.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, EnemyKilled
//  Publie : ScoreChanged

class Sinwave_ScoreSystem : Sinwave_System
{
	private bool mRunning;
	private int mScore;
	private int mKills;

	override void Setup()
	{
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_EnemyKilledEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mScore = 0;
			mKills = 0;
			mBus.Publish(Sinwave_ScoreChangedEvent.Create(mScore, mKills));
		}
		else if (e is 'Sinwave_RunEndedEvent')
		{
			mRunning = false;
		}
		else if (mRunning)
		{
			let killed = Sinwave_EnemyKilledEvent(e);
			if (killed == null) return;
			mScore += killed.mDef.mScore;
			mKills++;
			mBus.Publish(Sinwave_ScoreChangedEvent.Create(mScore, mKills));
		}
	}
}
