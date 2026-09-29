// =============================================================================
//  Cercles (vagues d'ennemis) et apparition du boss.
// =============================================================================
//
//  Écoute : RunStarted, RunSuspended, RunResumed, RunEnded, ActorDied, SpawnRequested
//  Publie : WaveStarted, WaveEnded, AllWavesCleared, EnemyKilled, BossSpawned, BossDefeated
//
//  Lit les cercles de l'arène courante dans GameData, fait apparaître les ennemis
//  sur les points d'apparition de la carte (Sinwave_SpawnPoint) en appliquant les
//  règles de l'arène et celles choisies par le joueur (service Rules : vie,
//  vitesse, rythme, cercle de départ), et reconnaît leur mort. Un cercle sans
//  durée se termine à la mort de son boss.

class Sinwave_WaveSystem : Sinwave_System
{
	const MIN_SPAWN_DISTANCE = 384.0;		// pas d'apparition collée au joueur
	const FALLBACK_SPAWN_RADIUS = 640.0;	// carte sans points d'apparition
	const SPAWN_ATTEMPTS = 6;

	private Sinwave_GameData mData;
	private Sinwave_RunRules mRules;
	private bool mRunning;
	private bool mSuspended;
	private int mWave;
	private int mWaveTics;
	private int mSpawnTimer;
	private int mBreakTics;
	private Actor mBoss;
	private Array<Actor> mAlive;
	private Array<Sinwave_EnemyDef> mAliveDefs;
	private Array<Actor> mSpawnPoints;

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mRules = Sinwave_RunRules.From(mServices);
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunSuspendedEvent');
		mBus.Subscribe(self, 'Sinwave_RunResumedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_ActorDiedEvent');
		mBus.Subscribe(self, 'Sinwave_SpawnRequestedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent') StartRun();
		else if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;
		else if (e is 'Sinwave_RunEndedEvent') StopRun();
		else if (e is 'Sinwave_ActorDiedEvent') OnActorDied(Sinwave_ActorDiedEvent(e).mThing);
		else if (e is 'Sinwave_SpawnRequestedEvent' && mRunning)
		{
			let request = Sinwave_SpawnRequestedEvent(e);
			let def = mData.FindEnemy(request.mEnemyId);
			for (int i = 0; def != null && i < request.mCount; i++) SpawnEnemy(def);
		}
	}

	override void Tick()
	{
		if (!mRunning || mSuspended) return;

		if (mBreakTics > 0)
		{
			mBreakTics--;
			if (mBreakTics == 0) StartWave(mWave + 1);
			return;
		}

		let wave = mData.mWaves[mWave];
		mWaveTics++;
		bool timeUp = wave.mDurationTics > 0 && mWaveTics >= wave.mDurationTics;
		bool bossGone = wave.HasBoss() && mBoss == null;	// supprimé sans mourir
		if (timeUp || bossGone)
		{
			EndWave();
			return;
		}

		mSpawnTimer--;
		if (mSpawnTimer <= 0)
		{
			mSpawnTimer = max(1, int(wave.mIntervalTics / (mData.mArena.mSpawnRate * mRules.mSpawnRate)));
			PruneAlive();
			if (mAlive.Size() < wave.mMaxAlive && wave.mTotalWeight > 0)
			{
				SpawnEnemy(mData.FindEnemy(wave.PickEnemy(Random[SinwaveWaves](0, wave.mTotalWeight - 1))));
			}
		}
	}

	private void StartRun()
	{
		mRunning = true;
		mSuspended = false;
		mBreakTics = 0;
		mBoss = null;
		CollectSpawnPoints();
		if (mData.mWaves.Size() == 0)
		{
			mRunning = false;
			mBus.Publish(new('Sinwave_AllWavesClearedEvent'));
			return;
		}
		// Cercle de départ choisi dans les règles de la descente.
		StartWave(clamp(mRules.mStartCircle - 1, 0, mData.mWaves.Size() - 1));
	}

	private void StopRun()
	{
		mRunning = false;
		// Les ennemis restants disparaissent sans mourir : ni XP ni score après la fin.
		for (int i = 0; i < mAlive.Size(); i++)
		{
			let mo = mAlive[i];
			if (mo != null && mo.health > 0)
			{
				Actor.Spawn('TeleportFog', mo.pos, ALLOW_REPLACE);
				mo.Destroy();
			}
		}
		mAlive.Clear();
		mAliveDefs.Clear();
		mBoss = null;
	}

	private void StartWave(int index)
	{
		mWave = index;
		mWaveTics = 0;
		mSpawnTimer = 0;
		let wave = mData.mWaves[index];
		mBus.Publish(Sinwave_WaveStartedEvent.Create(index, mData.mWaves.Size(), wave.mName, wave.mDurationTics));

		if (wave.HasBoss())
		{
			let def = mData.FindEnemy(wave.mBossId);
			mBoss = SpawnEnemy(def);
			if (mBoss != null) mBus.Publish(Sinwave_BossSpawnedEvent.Create(mBoss, def));
			else EndWave();	// impossible de placer le boss : on ne bloque pas la run
		}
	}

	private void EndWave()
	{
		mBus.Publish(Sinwave_WaveEndedEvent.Create(mWave));
		if (mWave + 1 >= mData.mWaves.Size())
		{
			mRunning = false;
			mBus.Publish(new('Sinwave_AllWavesClearedEvent'));
			return;
		}
		mBreakTics = max(1, mData.mWaves[mWave].mBreakTics);
	}

	// Fait apparaître un ennemi en appliquant sa définition et les règles de l'arène.
	private Actor SpawnEnemy(Sinwave_EnemyDef def)
	{
		if (def == null) return null;

		bool found;
		Vector3 pos;
		[found, pos] = FindSpawnPosition();
		if (!found) return null;

		let mo = Actor.Spawn(def.mActor, pos, ALLOW_REPLACE);
		if (mo == null) return null;
		if (!mo.TestMobjLocation())
		{
			mo.Destroy();
			return null;
		}

		// Définition de l'ennemi x règles de l'arène x règles choisies par le joueur.
		let arena = mData.mArena;
		mo.health = max(1, int(mo.SpawnHealth() * def.mHealthFactor * arena.mEnemyHealth * mRules.mEnemyHealth));
		mo.Speed *= def.mSpeedFactor * arena.mEnemySpeed * mRules.mEnemySpeed;
		if (def.mScale != 1.0)
		{
			mo.Scale *= def.mScale;
			mo.A_SetSize(mo.radius * def.mScale, mo.height * def.mScale);
		}

		// L'ennemi connaît déjà le joueur : il fonce sur lui au lieu d'attendre de le voir.
		let pawn = Sinwave_World.Player();
		if (pawn != null && mo.SeeState != null)
		{
			mo.target = pawn;
			mo.SetState(mo.SeeState);
		}

		Actor.Spawn('TeleportFog', pos, ALLOW_REPLACE);
		mAlive.Push(mo);
		mAliveDefs.Push(def);
		return mo;
	}

	private bool, Vector3 FindSpawnPosition()
	{
		let pawn = Sinwave_World.Player();
		for (int attempt = 0; attempt < SPAWN_ATTEMPTS; attempt++)
		{
			Vector3 pos;
			if (mSpawnPoints.Size() > 0)
			{
				let spot = mSpawnPoints[Random[SinwaveWaves](0, mSpawnPoints.Size() - 1)];
				if (spot == null) continue;
				pos = spot.pos;
			}
			else if (pawn != null)
			{
				pos = pawn.Vec3Angle(FALLBACK_SPAWN_RADIUS, FRandom[SinwaveWaves](0, 360));
			}
			else
			{
				break;
			}

			if (pawn == null || (pawn.pos.xy - pos.xy).Length() >= MIN_SPAWN_DISTANCE) return true, pos;
		}
		return false, (0, 0, 0);
	}

	private void CollectSpawnPoints()
	{
		mSpawnPoints.Clear();
		let it = ThinkerIterator.Create('Sinwave_SpawnPoint');
		Actor spot;
		while (spot = Actor(it.Next()))
		{
			mSpawnPoints.Push(spot);
		}
	}

	private void OnActorDied(Actor thing)
	{
		for (int i = 0; i < mAlive.Size(); i++)
		{
			if (mAlive[i] != thing) continue;
			let def = mAliveDefs[i];
			mAlive.Delete(i);
			mAliveDefs.Delete(i);
			mBus.Publish(Sinwave_EnemyKilledEvent.Create(def, thing.pos));
			if (thing == mBoss && mRunning)
			{
				mBoss = null;
				mBus.Publish(new('Sinwave_BossDefeatedEvent'));
				EndWave();
			}
			return;
		}
	}

	// Retire les ennemis supprimés par le moteur sans être morts.
	private void PruneAlive()
	{
		for (int i = mAlive.Size() - 1; i >= 0; i--)
		{
			if (mAlive[i] == null)
			{
				mAlive.Delete(i);
				mAliveDefs.Delete(i);
			}
		}
	}
}
