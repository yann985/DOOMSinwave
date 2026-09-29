// =============================================================================
//  Menaces : les attaques qui se préparent contre le joueur.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, RunSuspended, RunResumed
//  Publie : ThreatStarted, ThreatEnded
//
//  Un ennemi de Doom prévient toujours avant de frapper : il se tourne vers sa
//  cible pendant 0,3 à 0,5 s (début de ses états Missile et Melee), puis tire,
//  mord ou charge. Ce système repère ce moment, ainsi que les projectiles ennemis
//  qui arrivent sur le joueur, et l'annonce AVANT l'impact. L'interface en tire
//  un indicateur de direction pour les attaques venues de l'angle mort ; ce
//  système ne sait pas ce qui est affiché, ni ce que voit le joueur.

class Sinwave_ThreatSystem : Sinwave_System
{
	const SCAN_TICS = 2;			// une recherche tous les 2 tics suffit
	const HEADING_COS = 0.8;		// un projectile vise le joueur à 37° près

	private Sinwave_GameData mData;
	private bool mRunning;
	private bool mSuspended;
	private int mTics;
	private Array<Actor> mThreats;	// menaces annoncées, pas encore terminées

	override void Setup()
	{
		mData = Sinwave_GameData.From(mServices);
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_RunSuspendedEvent');
		mBus.Subscribe(self, 'Sinwave_RunResumedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mSuspended = false;
		}
		else if (e is 'Sinwave_RunEndedEvent')
		{
			mRunning = false;
			EndAll();
		}
		else if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;
	}

	override void Tick()
	{
		if (!mRunning || mSuspended || ++mTics % SCAN_TICS != 0) return;
		let pawn = Sinwave_World.Player();
		if (pawn == null || pawn.health <= 0)
		{
			EndAll();
			return;
		}

		Array<Actor> current;
		int warningTics = mData.mProgression.mThreatWarningTics;
		let it = ThinkerIterator.Create('Actor');
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (IsPreparingAttack(mo, pawn) || IsIncomingProjectile(mo, pawn, warningTics)) current.Push(mo);
		}

		// Menaces passées : attaque lancée, ennemi mort, projectile arrivé ou détruit.
		for (int i = mThreats.Size() - 1; i >= 0; i--)
		{
			let threat = mThreats[i];
			if (threat != null && current.Find(threat) < current.Size()) continue;
			if (threat != null) mBus.Publish(Sinwave_ThreatEndedEvent.Create(threat));
			mThreats.Delete(i);
		}
		// Nouvelles menaces.
		for (int i = 0; i < current.Size(); i++)
		{
			if (mThreats.Find(current[i]) < mThreats.Size()) continue;
			mThreats.Push(current[i]);
			mBus.Publish(Sinwave_ThreatStartedEvent.Create(current[i]));
		}
	}

	// Un ennemi qui vise le joueur et se prépare à tirer ou à frapper (ou charge).
	static bool IsPreparingAttack(Actor mo, Actor pawn)
	{
		if (!mo.bIsMonster || mo.health <= 0 || mo.target != pawn) return false;
		if (mo.bSkullFly) return true;
		return (mo.MissileState != null && Actor.InStateSequence(mo.CurState, mo.MissileState))
			|| (mo.MeleeState != null && Actor.InStateSequence(mo.CurState, mo.MeleeState));
	}

	// Un projectile tiré par un ennemi, qui fonce sur le joueur et l'atteindra dans
	// moins de `warningTics`.
	static bool IsIncomingProjectile(Actor mo, Actor pawn, int warningTics)
	{
		if (!mo.bMissile || mo.target == null || !mo.target.bIsMonster) return false;
		double speed = mo.vel.Length();
		if (speed <= 0) return false;
		Vector3 toPlayer = pawn.pos + (0, 0, pawn.height / 2) - mo.pos;
		double distance = toPlayer.Length();
		if (distance <= 0 || distance / speed > warningTics) return false;
		return (mo.vel dot toPlayer) / (speed * distance) > HEADING_COS;
	}

	private void EndAll()
	{
		for (int i = 0; i < mThreats.Size(); i++)
		{
			if (mThreats[i] != null) mBus.Publish(Sinwave_ThreatEndedEvent.Create(mThreats[i]));
		}
		mThreats.Clear();
	}
}
