// =============================================================================
//  Événements et abonnés : les deux briques du bus d'événements.
// =============================================================================

// Base de tous les événements. Un événement est un objet de données qui décrit
// « ce qui s'est passé » ; il ne sait pas qui va réagir.
class Sinwave_Event play
{
	// Détails lisibles, affichés par le journal de débogage (sinwave_debug 1).
	virtual String Describe() { return ""; }
}

// Tout objet qui veut recevoir des événements hérite de Sinwave_Listener.
// ZScript n'a pas d'interfaces : une classe de base joue ce rôle.
class Sinwave_Listener play
{
	virtual void OnEvent(Sinwave_Event e) {}
}
