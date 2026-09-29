// =============================================================================
//  États hors run : écran titre, choix de l'arène, règles, boutique.
// =============================================================================

// Menu : le joueur est dans l'arène vide, l'écran titre affiche la méta-progression.
class Sinwave_MenuState : Sinwave_GameState
{
	override Name Id() { return 'Menu'; }

	override void Enter()
	{
		// Arrivée après un voyage : run lancée (choix d'arène) ou boutique (écran de fin).
		switch (Sinwave_World.ConsumeArrival())
		{
		case Sinwave_World.ARRIVAL_RUN:		BeginRun(); break;
		case Sinwave_World.ARRIVAL_SHOP:	SwitchTo('Sinwave_ShopState'); break;
		}
	}

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_ConfirmEvent')
		{
			let data = Sinwave_GameData.From(mServices);
			if (data.mArenas.Size() > 1) SwitchTo('Sinwave_ArenaSelectState');
			else SwitchTo('Sinwave_RulesState');
		}
		else if (e is 'Sinwave_ShopRequestedEvent')
		{
			SwitchTo('Sinwave_ShopState');
		}
	}
}

// Choix de l'arène, puis réglage des règles.
class Sinwave_ArenaSelectState : Sinwave_GameState
{
	override Name Id() { return 'ArenaSelect'; }

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_BackRequestedEvent') SwitchTo('Sinwave_MenuState');
		else if (e is 'Sinwave_ArenaChosenEvent') SwitchTo('Sinwave_RulesState');
	}
}

// Règles de la descente : difficulté, défi personnalisé et cercle de départ.
// Les réglages eux-mêmes sont traités par Sinwave_RulesSystem. Si l'arène choisie
// se joue sur une autre carte, on y voyage et la run démarre à l'arrivée.
class Sinwave_RulesState : Sinwave_GameState
{
	override Name Id() { return 'Rules'; }

	override void HandleEvent(Sinwave_Event e)
	{
		let data = Sinwave_GameData.From(mServices);
		if (e is 'Sinwave_BackRequestedEvent')
		{
			if (data.mArenas.Size() > 1) SwitchTo('Sinwave_ArenaSelectState');
			else SwitchTo('Sinwave_MenuState');
		}
		else if (e is 'Sinwave_DescendRequestedEvent')
		{
			let rules = Sinwave_RunRules.From(mServices);
			if (rules.mArenaIndex == data.mArenaIndex || rules.mArenaIndex >= data.mArenas.Size()) BeginRun();
			else Sinwave_World.Travel(data.mArenas[rules.mArenaIndex].mMap, Sinwave_World.ARRIVAL_RUN);
		}
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
