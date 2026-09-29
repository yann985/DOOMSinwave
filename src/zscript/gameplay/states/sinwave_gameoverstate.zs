// Fin de run : l'interface affiche le bilan (score, âmes gagnées).
// Utiliser recharge la carte, ce qui ramène à l'état Menu.
class Sinwave_GameOverState : Sinwave_GameState
{
	// Évite de relancer par un appui accidentel juste après la fin.
	const RESTART_DELAY = TICRATE;

	private int mTics;

	override Name Id() { return 'GameOver'; }

	override void Enter()
	{
		mTics = 0;
	}

	override void Update()
	{
		mTics++;
	}

	override void HandleEvent(Sinwave_Event e)
	{
		if (!(e is 'Sinwave_ConfirmEvent') || mTics < RESTART_DELAY) return;

		// Joueur mort : le moteur recharge déjà le niveau quand on appuie sur Utiliser.
		let pawn = Sinwave_World.Player();
		if (pawn != null && pawn.health > 0) Sinwave_World.Travel(level.MapName, false);
	}
}
