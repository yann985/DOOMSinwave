// =============================================================================
//  Journal du bus (débogage).
// =============================================================================
//
//  Écoute : tout.  Publie : rien.
//
//  Avec « sinwave_debug 1 » dans la console, affiche chaque événement publié.
//  Placé en premier dans data/systems.txt, il voit les événements dans l'ordre
//  exact de leur publication. C'est aussi une démonstration du découplage :
//  on peut observer tout le jeu sans modifier un seul système.

class Sinwave_EventLogger : Sinwave_System
{
	override void Setup()
	{
		mBus.Subscribe(self);
	}

	override void OnEvent(Sinwave_Event e)
	{
		let cv = CVar.FindCVar('sinwave_debug');
		if (cv == null || !cv.GetBool()) return;

		// Le temps de jeu (en tics, 35 par seconde) aide à relire l'enchaînement.
		String details = e.Describe();
		if (details.Length() > 0) Console.Printf("\cu[bus] %s : %s \cc(t=%d)", e.GetClassName(), details, level.maptime);
		else Console.Printf("\cu[bus] %s \cc(t=%d)", e.GetClassName(), level.maptime);
	}
}
