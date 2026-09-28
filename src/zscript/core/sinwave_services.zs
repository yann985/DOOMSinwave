// =============================================================================
//  Services et Service Locator.
// =============================================================================

// Base des services : objets partagés par plusieurs systèmes
// (bus d'événements, données du jeu, sauvegarde, modèle de l'interface).
class Sinwave_Service play
{
}

// Service Locator explicite.
//
// Il est créé par la racine de composition (Sinwave_Game) puis TRANSMIS aux états
// et aux systèmes au moment de leur création. Ce n'est pas un singleton statique :
// aucun code ne peut le retrouver « depuis n'importe où ».
//
// Chaque service est rangé sous une clé. Remplacer une implémentation (par exemple
// la sauvegarde) revient à enregistrer un autre objet sous la même clé, sans
// modifier les systèmes qui l'utilisent.
class Sinwave_Services play
{
	private Array<Name> mKeys;
	private Array<Sinwave_Service> mServices;

	// Enregistre un service. Une clé déjà utilisée est remplacée.
	void Register(Name key, Sinwave_Service service)
	{
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (mKeys[i] == key)
			{
				mServices[i] = service;
				return;
			}
		}
		mKeys.Push(key);
		mServices.Push(service);
	}

	bool Has(Name key)
	{
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (mKeys[i] == key) return true;
		}
		return false;
	}

	// Renvoie le service, ou null (avec un message) s'il n'est pas enregistré.
	// Chaque service fournit un raccourci typé, par ex. Sinwave_EventBus.From(services).
	Sinwave_Service Get(Name key)
	{
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (mKeys[i] == key) return mServices[i];
		}
		Console.Printf("\cg[Sinwave] Service introuvable : %s", key);
		return null;
	}
}
