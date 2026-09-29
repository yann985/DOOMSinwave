// Fin de run : l'interface affiche le bilan (score, verdict, indulgences).
// Utiliser recharge la carte (retour à l'écran titre) ; B la recharge et ouvre la boutique.
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
		if (mTics < RESTART_DELAY) return;

		if (e is 'Sinwave_ShopRequestedEvent')
		{
			Sinwave_World.Travel(level.MapName, Sinwave_World.ARRIVAL_SHOP);
		}
		else if (e is 'Sinwave_ConfirmEvent')
		{
			// Joueur mort : le moteur recharge déjà le niveau quand on appuie sur Utiliser.
			let pawn = Sinwave_World.Player();
			if (pawn != null && pawn.health > 0) Sinwave_World.Travel(level.MapName, Sinwave_World.ARRIVAL_NONE);
		}
	}
}
