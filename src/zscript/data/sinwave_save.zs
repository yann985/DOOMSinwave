// =============================================================================
//  Méta-progression persistante : données et service de sauvegarde.
// =============================================================================

// Ce qui est conservé d'une run à l'autre.
class Sinwave_MetaData play
{
	int mSouls;			// âmes récoltées au total (monnaie de méta-progression)
	int mBestScore;
	int mRuns;
}

// Contrat de sauvegarde. Les systèmes ne dépendent que de cette classe abstraite :
// on peut changer la façon de sauvegarder sans toucher au gameplay.
class Sinwave_SaveService : Sinwave_Service abstract
{
	static Sinwave_SaveService From(Sinwave_Services services)
	{
		return Sinwave_SaveService(services.Get('Save'));
	}

	abstract Sinwave_MetaData Load();
	abstract void Save(Sinwave_MetaData metaData);
}

// Implémentation par CVars archivées (déclarées dans CVARINFO).
// Le moteur les écrit dans son fichier .ini : elles survivent à la fermeture du jeu
// et ne sont pas écrasées par le chargement d'une sauvegarde de partie.
class Sinwave_CVarSaveService : Sinwave_SaveService
{
	override Sinwave_MetaData Load()
	{
		let metaData = new('Sinwave_MetaData');
		metaData.mSouls = ReadInt('sinwave_meta_souls');
		metaData.mBestScore = ReadInt('sinwave_meta_best');
		metaData.mRuns = ReadInt('sinwave_meta_runs');
		return metaData;
	}

	override void Save(Sinwave_MetaData metaData)
	{
		WriteInt('sinwave_meta_souls', metaData.mSouls);
		WriteInt('sinwave_meta_best', metaData.mBestScore);
		WriteInt('sinwave_meta_runs', metaData.mRuns);
		// Écrit le fichier tout de suite : rien n'est perdu si le jeu plante ensuite.
		CVar.SaveConfig();
	}

	private static int ReadInt(Name cvarName)
	{
		let cv = CVar.FindCVar(cvarName);
		return cv != null ? cv.GetInt() : 0;
	}

	private static void WriteInt(Name cvarName, int value)
	{
		let cv = CVar.FindCVar(cvarName);
		if (cv != null) cv.SetInt(value);
		else Console.Printf("\cg[Sinwave] CVar de sauvegarde introuvable : %s", cvarName);
	}
}
