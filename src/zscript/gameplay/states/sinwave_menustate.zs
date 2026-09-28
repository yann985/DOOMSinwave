// Menu : le joueur est dans l'arène vide, l'écran titre affiche la méta-progression.
// Utiliser lance la run.
class Sinwave_MenuState : Sinwave_GameState
{
	override Name Id() { return 'Menu'; }

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_ConfirmEvent')
		{
			SwitchTo('Sinwave_InGameState');
			mBus.Publish(new('Sinwave_RunStartedEvent'));
		}
	}
}
