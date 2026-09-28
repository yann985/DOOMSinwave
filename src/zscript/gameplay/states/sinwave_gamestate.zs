// =============================================================================
//  États globaux du jeu.
// =============================================================================
//
//                 Utiliser                      Pause (P)
//      [Menu] -------------> [InGame] <-------------------> [Pause]
//                              |   ^                           |
//               niveau gagné   |   | amélioration choisie      | Abandonner
//                              v   |                           |
//                           [Upgrade]                          |
//                                                              |
//      [InGame] -- mort / toutes les vagues finies --> [GameOver] <---+
//      [GameOver] -- Utiliser --> la carte recharge --> [Menu]
//
//  Les états ne font qu'une chose : décider des transitions en réagissant aux
//  événements. Le travail (faire apparaître des ennemis, compter l'XP...) est
//  fait par les systèmes, qui réagissent à leur tour aux événements publiés ici.

// Base commune : accès aux services et aux transitions partagées.
class Sinwave_GameState : Sinwave_State abstract
{
	protected Sinwave_Services mServices;
	protected Sinwave_EventBus mBus;

	void Init(Sinwave_Services services)
	{
		mServices = services;
		mBus = Sinwave_EventBus.From(services);
	}

	protected void SwitchTo(class<Sinwave_State> type)
	{
		mMachine.ChangeState(type);
	}

	// Fin de run, identique quelle que soit la raison : on passe à l'écran de fin
	// puis on l'annonce (le score et la méta-progression réagissent).
	protected void EndRun(int reason)
	{
		SwitchTo('Sinwave_GameOverState');
		mBus.Publish(Sinwave_RunEndedEvent.Create(reason));
	}
}
