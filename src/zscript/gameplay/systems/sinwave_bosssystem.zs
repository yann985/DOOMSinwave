// =============================================================================
//  Comportement du boss (Lucifer, l'Orgueil).
// =============================================================================
//
//  Écoute : BossSpawned, BossDefeated, RunEnded
//  Publie : BossHealthChanged, BossEnraged, SpawnRequested
//
//  Suit la vie du boss pour l'interface, et le fait entrer en rage sous un seuil
//  de vie (données de data/enemies.txt : rage_at, rage_speed, rage_summon).
//  Les renforts sont demandés au système de vagues par un événement : ce système
//  ne sait pas faire apparaître d'ennemis lui-même.

class Sinwave_BossSystem : Sinwave_System
{
	private Actor mBoss;
	private Sinwave_EnemyDef mDef;
	private int mMaxHealth;
	private int mLastHealth;
	private bool mEnraged;

	override void Setup()
	{
		mBus.Subscribe(self, 'Sinwave_BossSpawnedEvent');
		mBus.Subscribe(self, 'Sinwave_BossDefeatedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		let spawned = Sinwave_BossSpawnedEvent(e);
		if (spawned != null)
		{
			mBoss = spawned.mBoss;
			mDef = spawned.mDef;
			mMaxHealth = max(1, mBoss.health);
			mLastHealth = mMaxHealth;
			mEnraged = false;
			mBus.Publish(Sinwave_BossHealthChangedEvent.Create(1.0));
			return;
		}
		// Boss vaincu ou run terminée.
		mBoss = null;
	}

	override void Tick()
	{
		if (mBoss == null || mBoss.health <= 0 || mBoss.health == mLastHealth) return;

		mLastHealth = mBoss.health;
		double fraction = clamp(double(mBoss.health) / mMaxHealth, 0.0, 1.0);
		mBus.Publish(Sinwave_BossHealthChangedEvent.Create(fraction));

		if (!mEnraged && mDef.mRageAt > 0 && fraction <= mDef.mRageAt)
		{
			mEnraged = true;
			mBoss.Speed *= mDef.mRageSpeed;
			mBoss.Scale *= 1.15;
			mBoss.A_StartSound(mBoss.SeeSound, CHAN_VOICE, 0, 1.0, ATTN_NONE);
			mBus.Publish(new('Sinwave_BossEnragedEvent'));
			if (mDef.mRageSummonCount > 0)
			{
				mBus.Publish(Sinwave_SpawnRequestedEvent.Create(mDef.mRageSummonId, mDef.mRageSummonCount, true));
			}
		}
	}
}
