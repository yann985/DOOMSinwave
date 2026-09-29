// =============================================================================
//  États hors run : écran titre, choix de l'arène, boutique.
// =============================================================================

// Menu : le joueur est dans l'arène vide, l'écran titre affiche la méta-progression.
class Sinwave_MenuState : Sinwave_GameState
{
	override Name Id() { return 'Menu'; }

	override void Enter()
	{
		// Arrivée sur la carte après un choix d'arène : la run démarre tout de suite.
		if (Sinwave_World.ConsumeAutoStart()) BeginRun();
	}

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_ConfirmEvent')
		{
			let data = Sinwave_GameData.From(mServices);
			if (data.mArenas.Size() > 1) SwitchTo('Sinwave_ArenaSelectState');
			else BeginRun();
		}
		else if (e is 'Sinwave_ShopRequestedEvent')
		{
			SwitchTo('Sinwave_ShopState');
		}
	}
}

// Choix de l'arène. Si elle se joue sur une autre carte, on y voyage et la run
// démarre à l'arrivée.
class Sinwave_ArenaSelectState : Sinwave_GameState
{
	override Name Id() { return 'ArenaSelect'; }

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_BackRequestedEvent')
		{
			SwitchTo('Sinwave_MenuState');
			return;
		}
		let chosen = Sinwave_ArenaChosenEvent(e);
		if (chosen == null) return;

		let data = Sinwave_GameData.From(mServices);
		if (chosen.mIndex < 0 || chosen.mIndex >= data.mArenas.Size()) return;
		if (chosen.mIndex == data.mArenaIndex) BeginRun();
		else Sinwave_World.Travel(data.mArenas[chosen.mIndex].mMap, true);
	}
}

// Boutique des indulgences. Les achats eux-mêmes sont traités par Sinwave_MetaSystem.
class Sinwave_ShopState : Sinwave_GameState
{
	override Name Id() { return 'Shop'; }

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_BackRequestedEvent' || e is 'Sinwave_ShopRequestedEvent') SwitchTo('Sinwave_MenuState');
	}
}
