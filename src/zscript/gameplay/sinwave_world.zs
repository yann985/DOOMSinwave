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

	// Change de carte. Avec autoStart, la run démarre dès l'arrivée (choix d'arène).
	static void Travel(String mapName, bool autoStart)
	{
		let cv = CVar.FindCVar('sinwave_autostart');
		if (cv != null) cv.SetBool(autoStart);
		level.ChangeLevel(mapName, 0, CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH | CHANGELEVEL_NOINTERMISSION);
	}

	// Lit et efface la demande de démarrage automatique.
	static bool ConsumeAutoStart()
	{
		let cv = CVar.FindCVar('sinwave_autostart');
		if (cv == null || !cv.GetBool()) return false;
		cv.SetBool(false);
		return true;
	}
}
