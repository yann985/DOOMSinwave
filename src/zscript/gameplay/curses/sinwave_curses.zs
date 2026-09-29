// =============================================================================
//  Les sept malédictions (pattern Stratégie).
// =============================================================================
//
//  Chaque classe change une règle du jeu pendant un cercle. Leurs réglages
//  viennent de data/curses.txt (mDef.mParams). Pour en créer une nouvelle :
//  une classe qui hérite de Sinwave_Curse, puis un bloc dans data/curses.txt.
//  Une malédiction qui touche le joueur passe par EffectGranted, comme les
//  vertus : c'est Sinwave_PlayerSystem qui applique l'effet.

class Sinwave_Curse play abstract
{
	protected Sinwave_CurseDef mDef;
	protected Sinwave_Services mServices;
	protected Sinwave_EventBus mBus;
	protected int mTics;

	void Init(Sinwave_CurseDef def, Sinwave_Services services)
	{
		mDef = def;
		mServices = services;
		mBus = Sinwave_EventBus.From(services);
	}

	virtual void Begin() {}
	virtual void End() {}
	virtual void Tick() { mTics++; }
	virtual void OnEvent(Sinwave_Event e) {}

	protected double Param(String key, double fallback)
	{
		return mDef.mParams.GetDouble(key, fallback);
	}

	// Effet temporaire sur le joueur (annulé dans End() par la valeur opposée).
	protected void Grant(Name type, double value)
	{
		mBus.Publish(Sinwave_EffectGrantedEvent.Create(Sinwave_Effect.Create(type, value), mDef.mName));
	}
}

// Paresse : le joueur est ralenti, mais se soigne quand il reste immobile.
class Sinwave_SlothCurse : Sinwave_Curse
{
	private int mStillTics;

	override void Begin() { Grant('speed', Param("speed", -0.25)); }
	override void End() { Grant('speed', -Param("speed", -0.25)); }

	override void Tick()
	{
		Super.Tick();
		let pawn = Sinwave_World.Player();
		if (pawn == null || pawn.health <= 0) return;
		mStillTics = pawn.vel.xy.Length() < 1 ? mStillTics + 1 : 0;
		if (mStillTics >= TICRATE && mStillTics % TICRATE == 0) pawn.GiveBody(int(Param("heal", 3)));
	}
}

// Gourmandise : les ennemis dévorent les orbes d'XP proches et grossissent.
class Sinwave_GluttonyCurse : Sinwave_Curse
{
	override void Tick()
	{
		Super.Tick();
		if (mTics % 5 != 0) return;

		double radius = Param("radius", 96);
		Array<Actor> monsters;
		Sinwave_World.CollectMonsters(monsters);
		let it = ThinkerIterator.Create('Sinwave_XpOrb');
		Actor orb;
		while (orb = Actor(it.Next()))
		{
			for (int i = 0; i < monsters.Size(); i++)
			{
				let mo = monsters[i];
				if (mo.Distance2D(orb) > radius + mo.radius) continue;
				mo.health += int(Param("health", 25));
				if (mo.Scale.X < 2.0) mo.Scale *= 1.1;
				mo.A_StartSound("misc/i_pkup", CHAN_BODY);
				orb.Destroy();
				break;
			}
		}
	}
}

// Luxure : charme trompeur, les ennemis éloignés sont presque invisibles.
class Sinwave_LustCurse : Sinwave_Curse
{
	override void Tick()
	{
		Super.Tick();
		if (mTics % 4 != 0) return;
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;

		double distance = Param("distance", 450);
		double hidden = Param("alpha", 0.12);
		Array<Actor> monsters;
		Sinwave_World.CollectMonsters(monsters);
		for (int i = 0; i < monsters.Size(); i++)
		{
			let mo = monsters[i];
			mo.A_SetRenderStyle(mo.Distance2D(pawn) > distance ? hidden : 1.0, STYLE_Translucent);
		}
	}

	override void End()
	{
		Array<Actor> monsters;
		Sinwave_World.CollectMonsters(monsters);
		for (int i = 0; i < monsters.Size(); i++) monsters[i].A_SetRenderStyle(1.0, STYLE_Normal);
	}
}

// Envie : quand un ennemi meurt, ses voisins se soignent et accélèrent.
class Sinwave_EnvyCurse : Sinwave_Curse
{
	override void OnEvent(Sinwave_Event e)
	{
		let killed = Sinwave_EnemyKilledEvent(e);
		if (killed == null) return;

		double radius = Param("radius", 256);
		Array<Actor> monsters;
		Sinwave_World.CollectMonsters(monsters);
		for (int i = 0; i < monsters.Size(); i++)
		{
			let mo = monsters[i];
			if ((mo.pos.xy - killed.mPos.xy).Length() > radius) continue;
			mo.health = min(mo.health + int(Param("health", 20)), mo.SpawnHealth() * 2);
			mo.Speed = min(mo.Speed * Param("speed", 1.1), mo.Default.Speed * 2);
		}
	}
}

// Avarice : les orbes d'XP disparaissent si on ne les ramasse pas vite.
class Sinwave_GreedCurse : Sinwave_Curse
{
	override void Begin()
	{
		let it = ThinkerIterator.Create('Sinwave_XpOrb');
		Sinwave_XpOrb orb;
		while (orb = Sinwave_XpOrb(it.Next())) orb.SetLifetime(Lifetime());
	}

	override void OnEvent(Sinwave_Event e)
	{
		let dropped = Sinwave_XpOrbDroppedEvent(e);
		if (dropped != null && dropped.mOrb != null) dropped.mOrb.SetLifetime(Lifetime());
	}

	private int Lifetime()
	{
		return int(Param("lifetime", 3) * TICRATE);
	}
}

// Colère : un ennemi blessé entre en rage quelques secondes. Il devient rouge et
// accélère, puis retrouve sa couleur et sa vitesse pour de bon : chaque ennemi
// n'enrage qu'une fois (sinon, sous un tir continu, il resterait rouge jusqu'à sa mort).
class Sinwave_WrathCurse : Sinwave_Curse
{
	private Array<Actor> mEnraged;
	private Array<int> mTicsLeft;
	private Array<double> mOriginalSpeed;
	private Array<TranslationID> mOriginalTranslation;
	private Array<Actor> mCalmed;

	override void OnEvent(Sinwave_Event e)
	{
		let damaged = Sinwave_ActorDamagedEvent(e);
		if (damaged == null) return;
		let mo = damaged.mThing;
		if (mo == null || !mo.bIsMonster || mo.health <= 0) return;
		if (mEnraged.Find(mo) < mEnraged.Size() || mCalmed.Find(mo) < mCalmed.Size()) return;

		mEnraged.Push(mo);
		mTicsLeft.Push(int(Param("duration", 3) * TICRATE));
		mOriginalSpeed.Push(mo.Speed);
		mOriginalTranslation.Push(mo.Translation);
		mo.Speed *= Param("speed", 1.5);
		mo.A_SetTranslation('SinwaveRage');
	}

	override void Tick()
	{
		Super.Tick();
		for (int i = mEnraged.Size() - 1; i >= 0; i--)
		{
			mTicsLeft[i]--;
			if (mEnraged[i] == null || mTicsLeft[i] <= 0) Calm(i);
		}
	}

	override void End()
	{
		for (int i = mEnraged.Size() - 1; i >= 0; i--) Calm(i);
	}

	private void Calm(int index)
	{
		let mo = mEnraged[index];
		if (mo != null)
		{
			mo.Speed = mOriginalSpeed[index];
			mo.Translation = mOriginalTranslation[index];
			mCalmed.Push(mo);
		}
		mEnraged.Delete(index);
		mTicsLeft.Delete(index);
		mOriginalSpeed.Delete(index);
		mOriginalTranslation.Delete(index);
	}
}

// Orgueil : tant que le joueur a plus de la moitié de ses PV, il subit plus de dégâts.
class Sinwave_PrideCurse : Sinwave_Curse
{
	private bool mApplied;

	override void Tick()
	{
		Super.Tick();
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;
		bool proud = pawn.health > pawn.GetMaxHealth(true) * Param("threshold", 0.5);
		if (proud != mApplied) Toggle(proud);
	}

	override void End()
	{
		if (mApplied) Toggle(false);
	}

	private void Toggle(bool on)
	{
		mApplied = on;
		double value = Param("vulnerability", 0.5);
		Grant('vulnerability', on ? value : -value);
	}
}
