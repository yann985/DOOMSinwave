// Point d'entrée du mod. Pour l'instant il confirme seulement que la chaîne
// build -> moteur fonctionne ; c'est ici que les services seront créés.
class Sinwave_Bootstrap : StaticEventHandler
{
	override void OnRegister()
	{
		Console.Printf("Sinwave : mod chargé.");
	}
}
