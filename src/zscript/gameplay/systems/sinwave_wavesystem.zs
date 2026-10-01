// =============================================================================
//  Cercles, vagues d'ennemis et apparition du boss.
// =============================================================================
//
//  Écoute : RunStarted, RunSuspended, RunResumed, RunEnded, ActorDied, SpawnRequested,
//           CorruptionChanged
//  Publie : CircleStarted, CircleEnded, WaveStarted, WaveEnded, AllCirclesCleared,
//           EnemyKilled, BossSpawned, BossDefeated
//
//  Lit les cercles de l'arène courante dans GameData. Chaque cercle enchaîne
//  plusieurs vagues, séparées par un court répit ; chaque vague est plus serrée
//  que la précédente (data/progression.txt), et les ennemis gagnent en vie d'une
//  vague à l'autre. Avec un boss, la dernière vague du cercle est la sienne et
//  dure jusqu'à sa mort.
//
//  Les ennemis apparaissent autour du joueur ou sur les points d'apparition de la
//  carte (Sinwave_SpawnPoint) selon l'arène, avec les règles de l'arène et celles
//  choisies par le joueur (service Rules : vie, vitesse, rythme, cercle de
//  départ). Toute la horde vise le joueur.
//
//  Le boss suit la balance de l'âme (data/soul.txt) : plus elle est pure, plus
//  il est fort mais seul ; plus elle est corrompue, plus il est faible mais
//  entouré (ennemis de sa vague et renforts).

class Sinwave_WaveSystem : Sinwave_System
{
	const MIN_SPAWN_DISTANCE = 384.0;		// points de la carte : pas d'apparition collée au joueur
	const RING_MIN_DISTANCE = 550.0;		// apparition autour du joueur : juste hors de portée
	const RING_MAX_DISTANCE = 850.0;
	const SPAWN_ATTEMPTS = 6;
	const MAX_STEP = 24.0;					// marche la plus haute qu'un monstre sait monter
	const RETARGET_TICS = TICRATE;			// fréquence du rappel de cible

	private Sinwave_GameData mData;
	private Sinwave_RunRules mRules;
	private bool mRunning;
	private bool mSuspended;
	private int mCircle;
	private int mWave;				// vague en cours dans le cercle
	private int mWaveTics;
	private int mSpawnTimer;
	private int mBreakTics;			// répit avant la prochaine vague...
	private bool mCircleDone;		// ... ou avant le prochain cercle
	// Vague en cours, montée en difficulté comprise.
	private int mIntervalTics;
	private int mMaxAlive;
	private double mHealthFactor;
	private int mSoul;				// balance de l'âme, pour le boss
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
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
		mSoul = mData.mSoul.mBalance;
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent') StartRun();
		else if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;
		else if (e is 'Sinwave_RunEndedEvent') StopRun();
		else if (e is 'Sinwave_ActorDiedEvent') OnActorDied(Sinwave_ActorDiedEvent(e).mThing);
		else if (e is 'Sinwave_CorruptionChangedEvent') mSoul = Sinwave_CorruptionChangedEvent(e).mCorruption;
		else if (e is 'Sinwave_SpawnRequestedEvent' && mRunning)
		{
			let request = Sinwave_SpawnRequestedEvent(e);
			let def = mData.FindEnemy(request.mEnemyId);
			int count = request.mCount;
			if (request.mEscort) count = int(count * mData.mSoul.BossEscortFactor(mSoul) + 0.5);
			for (int i = 0; def != null && i < count; i++) SpawnEnemy(def);
		}
	}

	override void Tick()
	{
		if (!mRunning || mSuspended) return;

		// Pendant un répit, les ennemis restants attaquent encore, mais aucun n'apparaît.
		if (mBreakTics > 0)
		{
			mBreakTics--;
			if (mBreakTics == 0)
			{
				if (mCircleDone) StartCircle(mCircle + 1);
				else StartWave(mWave + 1);
			}
			return;
		}

		let circle = mData.mCircles[mCircle];
		mWaveTics++;
		if (mWaveTics % RETARGET_TICS == 0) Retarget();
		int duration = circle.WaveTics(mWave);
		bool timeUp = duration > 0 && mWaveTics >= duration;
		bool bossGone = circle.IsBossWave(mWave) && mBoss == null;	// supprimé sans mourir
		if (timeUp || bossGone)
		{
			EndWave();
			return;
		}

		// Autour du boss, le nombre d'ennemis suit la balance de l'âme.
		double escort = circle.IsBossWave(mWave) ? mData.mSoul.BossEscortFactor(mSoul) : 1.0;
		mSpawnTimer--;
		if (mSpawnTimer <= 0)
		{
			mSpawnTimer = max(1, int(mIntervalTics / (mData.mArena.mSpawnRate * mRules.mSpawnRate * escort)));
			PruneAlive();
			if (mAlive.Size() < int(mMaxAlive * escort + 0.5) && circle.mTotalWeight > 0)
			{
				SpawnEnemy(mData.FindEnemy(circle.PickEnemy(Random[SinwaveWaves](0, circle.mTotalWeight - 1))));
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
		if (mData.mCircles.Size() == 0)
		{
			mRunning = false;
			mBus.Publish(new('Sinwave_AllCirclesClearedEvent'));
			return;
		}
		// Cercle de départ choisi dans les règles de la descente.
		StartCircle(clamp(mRules.mStartCircle - 1, 0, mData.mCircles.Size() - 1));
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

	private void StartCircle(int index)
	{
		mCircle = index;
		let circle = mData.mCircles[index];
		mBus.Publish(Sinwave_CircleStartedEvent.Create(index, mData.mCircles.Size(), circle.mName));
		StartWave(0);
	}

	private void StartWave(int wave)
	{
		mWave = wave;
		mWaveTics = 0;
		mSpawnTimer = 0;
		let circle = mData.mCircles[mCircle];
		let progression = mData.mProgression;
		mIntervalTics = circle.IntervalTicsForWave(wave, progression.mWaveSpawnGrowth);
		mMaxAlive = circle.MaxAliveForWave(wave, progression.mWaveMaxGrowth);
		mHealthFactor = 1.0 + progression.mWaveHealthGrowth * mData.WaveRank(mCircle, wave);
		mBus.Publish(Sinwave_WaveStartedEvent.Create(mCircle, wave, circle.mWaveCount, circle.WaveTics(wave)));

		if (circle.IsBossWave(wave))
		{
			let def = mData.FindEnemy(circle.mBossId);
			mBoss = SpawnEnemy(def);
			if (mBoss != null) mBus.Publish(Sinwave_BossSpawnedEvent.Create(mBoss, def));
			else EndWave();	// impossible de placer le boss : on ne bloque pas la run
		}
	}

	// Fin de vague : répit avant la vague suivante, ou fin du cercle.
	private void EndWave()
	{
		let circle = mData.mCircles[mCircle];
		mBus.Publish(Sinwave_WaveEndedEvent.Create(mCircle, mWave));
		if (mWave + 1 < circle.mWaveCount)
		{
			mCircleDone = false;
			mBreakTics = circle.mPauseTics;
			return;
		}

		mBus.Publish(Sinwave_CircleEndedEvent.Create(mCircle));
		if (mCircle + 1 >= mData.mCircles.Size())
		{
			mRunning = false;
			mBus.Publish(new('Sinwave_AllCirclesClearedEvent'));
			return;
		}
		mCircleDone = true;
		mBreakTics = max(1, circle.mBreakTics);
	}

	// Fait apparaître un ennemi en appliquant sa définition et les règles de l'arène.
	private Actor SpawnEnemy(Sinwave_EnemyDef def)
	{
		if (def == null) return null;

		// Plusieurs essais : une position peut tomber dans un pilier ou hors de la carte.
		Actor mo = null;
		Vector3 pos;
		for (int attempt = 0; attempt < SPAWN_ATTEMPTS && mo == null; attempt++)
		{
			bool found;
			[found, pos] = FindSpawnPosition();
			if (!found) continue;
			mo = Actor.Spawn(def.mActor, pos, ALLOW_REPLACE);
			if (mo != null && !mo.TestMobjLocation())
			{
				mo.Destroy();
				mo = null;
			}
		}
		if (mo == null) return null;

		// Définition de l'ennemi x règles de l'arène x règles choisies par le joueur,
		// x montée en difficulté de la vague ; un boss suit plutôt la balance de l'âme.
		let arena = mData.mArena;
		double waveHealth = def.mIsBoss ? mData.mSoul.BossHealthFactor(mSoul) : mHealthFactor;
		mo.health = max(1, int(mo.SpawnHealth() * def.mHealthFactor * arena.mEnemyHealth * mRules.mEnemyHealth * waveHealth));
		mo.Speed *= def.mSpeedFactor * arena.mEnemySpeed * mRules.mEnemySpeed;
		if (def.mScale != 1.0)
		{
			mo.Scale *= def.mScale;
			mo.A_SetSize(mo.radius * def.mScale, mo.height * def.mScale);
		}
		if (def.mTranslation != 'None' && def.mTranslation != '') mo.A_SetTranslation(def.mTranslation);

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

	// Une position candidate. Selon l'arène (clé « spawn » de data/arenas.txt) :
	//   player : autour du joueur, juste hors de portée, comme dans un survivors-like ;
	//   points : sur les points d'apparition placés dans la carte.
	private bool, Vector3 FindSpawnPosition()
	{
		let pawn = Sinwave_World.Player();
		bool aroundPlayer = mData.mArena.mSpawnAroundPlayer || mSpawnPoints.Size() == 0;

		if (aroundPlayer && pawn != null)
		{
			double distance = FRandom[SinwaveWaves](RING_MIN_DISTANCE, RING_MAX_DISTANCE);
			Vector2 xy = pawn.pos.xy + Actor.AngleToVector(FRandom[SinwaveWaves](0, 360), distance);
			let sec = level.PointInSector(xy);
			Vector3 pos = (xy, sec.floorplane.ZatPoint(xy));
			if (level.IsPointInLevel(pos) && CanWalkOff(sec)) return true, pos;
			// Hors de la carte (joueur près d'un mur) : on se rabat sur un point de la carte.
		}

		if (mSpawnPoints.Size() > 0)
		{
			let spot = mSpawnPoints[Random[SinwaveWaves](0, mSpawnPoints.Size() - 1)];
			if (spot != null && (pawn == null || (pawn.pos.xy - spot.pos.xy).Length() >= MIN_SPAWN_DISTANCE))
			{
				return true, spot.pos;
			}
		}
		return false, (0, 0, 0);
	}

	// Faux pour un plateau plus haut que tous ses voisins de plus d'une marche (un
	// tombeau, un autel) : un monstre ne sait pas en descendre, il y resterait coincé.
	private static bool CanWalkOff(Sector sec)
	{
		double floor = sec.CenterFloor();
		bool hasNeighbour = false;
		for (int i = 0; i < sec.lines.Size(); i++)
		{
			let line = sec.lines[i];
			let other = line.frontsector == sec ? line.backsector : line.frontsector;
			if (other == null || other == sec) continue;
			hasNeighbour = true;
			if (floor - other.CenterFloor() <= MAX_STEP) return true;
		}
		return !hasNeighbour;
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

	// Un ennemi qui a perdu le joueur (autre cible, ou retour à l'errance) est
	// relancé sur lui : dans un survivors-like, toute la horde vise le joueur.
	private void Retarget()
	{
		let pawn = Sinwave_World.Player();
		if (pawn == null || pawn.health <= 0) return;
		for (int i = 0; i < mAlive.Size(); i++)
		{
			let mo = mAlive[i];
			if (mo == null || mo.health <= 0) continue;
			bool idle = mo.InStateSequence(mo.CurState, mo.SpawnState);
			if (mo.target == pawn && !idle) continue;
			mo.target = pawn;
			if (idle && mo.SeeState != null) mo.SetState(mo.SeeState);
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
