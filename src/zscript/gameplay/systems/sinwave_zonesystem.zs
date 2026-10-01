// =============================================================================
//  Zones de cercle : chaque cercle peut avoir sa propre zone dans la carte.
// =============================================================================
//
//  Écoute : CircleStarted
//  Publie : rien
//
//  Au début d'un cercle, transporte le joueur au départ de ce cercle
//  (Sinwave_CircleStart, premier argument = numéro du cercle) s'il y en a un dans
//  la carte. Les arènes d'une seule pièce n'en placent pas : rien ne change pour
//  elles. Les ennemis restés dans la zone précédente sont retirés par
//  Sinwave_WaveSystem, qui ne garde que ceux qui peuvent encore atteindre le joueur.

class Sinwave_ZoneSystem : Sinwave_System
{
	const NEAR = 64.0;		// déjà sur place : pas de transport

	override void Setup()
	{
		mBus.Subscribe(self, 'Sinwave_CircleStartedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		let started = Sinwave_CircleStartedEvent(e);
		if (started == null) return;
		let spot = FindStart(started.mIndex + 1);
		let pawn = Sinwave_World.Player();
		if (spot == null || pawn == null) return;
		if ((pawn.pos.xy - spot.pos.xy).Length() < NEAR) return;
		pawn.Teleport(spot.pos, spot.angle, TELF_SOURCEFOG | TELF_DESTFOG);
		pawn.vel = (0, 0, 0);
	}

	private static Actor FindStart(int circle)
	{
		let it = ThinkerIterator.Create('Sinwave_CircleStart');
		Actor spot;
		while (spot = Actor(it.Next()))
		{
			if (spot.args[0] == circle) return spot;
		}
		return null;
	}
}
