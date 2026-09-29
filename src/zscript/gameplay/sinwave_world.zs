// Accès au monde du moteur partagé par le gameplay.
class Sinwave_World play
{
	// Le joueur (Sinwave est un jeu solo : le premier joueur présent).
	static PlayerPawn Player()
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playeringame[i] && players[i].mo != null) return players[i].mo;
		}
		return null;
	}

	// Tous les monstres vivants de la carte.
	static void CollectMonsters(out Array<Actor> result)
	{
		result.Clear();
		let it = ThinkerIterator.Create('Actor');
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bIsMonster && mo.health > 0) result.Push(mo);
		}
	}

	// Ce que fait le menu à l'arrivée sur la carte après un voyage.
	enum EArrival
	{
		ARRIVAL_NONE,	// rester sur l'écran titre
		ARRIVAL_RUN,	// lancer la run (arène choisie)
		ARRIVAL_SHOP	// ouvrir la boutique (depuis l'écran de fin)
	}

	// Change de carte (ou recharge la carte courante).
	static void Travel(String mapName, int arrival)
	{
		let cv = CVar.FindCVar('sinwave_onarrival');
		if (cv != null) cv.SetInt(arrival);
		level.ChangeLevel(mapName, 0, CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH | CHANGELEVEL_NOINTERMISSION);
	}

	// Lit et efface l'action demandée pour l'arrivée.
	static int ConsumeArrival()
	{
		let cv = CVar.FindCVar('sinwave_onarrival');
		if (cv == null) return ARRIVAL_NONE;
		int arrival = cv.GetInt();
		cv.SetInt(ARRIVAL_NONE);
		return arrival;
	}
}
