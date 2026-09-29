// =============================================================================
//  Méta-progression persistante : données et service de sauvegarde.
// =============================================================================

// Ce qui est conservé d'une run à l'autre.
class Sinwave_MetaData play
{
	int mIndulgences;		// monnaie de méta-progression, dépensée à la boutique
	int mBestScore;
	int mRuns;
	private Array<Name> mItemIds;	// articles achetés à la boutique...
	private Array<int> mItemLevels;	// ...et leur niveau

	int GetLevel(Name itemId)
	{
		for (int i = 0; i < mItemIds.Size(); i++)
		{
			if (mItemIds[i] == itemId) return mItemLevels[i];
		}
		return 0;
	}

	void SetLevel(Name itemId, int level)
	{
		for (int i = 0; i < mItemIds.Size(); i++)
		{
			if (mItemIds[i] == itemId)
			{
				mItemLevels[i] = level;
				return;
			}
		}
		mItemIds.Push(itemId);
		mItemLevels.Push(level);
	}

	// Achats sous forme de texte : « shotgun=1;vigor=3 ».
	String EncodePurchases()
	{
		String text = "";
		for (int i = 0; i < mItemIds.Size(); i++)
		{
			if (mItemLevels[i] <= 0) continue;
			text = text .. String.Format("%s=%d;", mItemIds[i], mItemLevels[i]);
		}
		return text;
	}

	void DecodePurchases(String text)
	{
		mItemIds.Clear();
		mItemLevels.Clear();
		Array<String> entries;
		text.Split(entries, ";", TOK_SKIPEMPTY);
		for (int i = 0; i < entries.Size(); i++)
		{
			Array<String> parts;
			entries[i].Split(parts, "=");
			if (parts.Size() != 2) continue;
			SetLevel(parts[0].MakeLower(), max(0, parts[1].ToInt(10)));
		}
	}
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

	// Règles de la descente choisies par le joueur (retrouvées d'une partie à l'autre).
	abstract void LoadRules(Sinwave_RunRules rules);
	abstract void SaveRules(Sinwave_RunRules rules);
}

// Implémentation par CVars archivées (déclarées dans CVARINFO).
// Le moteur les écrit dans son fichier .ini : elles survivent à la fermeture du jeu
// et ne sont pas écrasées par le chargement d'une sauvegarde de partie.
class Sinwave_CVarSaveService : Sinwave_SaveService
{
	override Sinwave_MetaData Load()
	{
		let metaData = new('Sinwave_MetaData');
		metaData.mIndulgences = ReadInt('sinwave_meta_indulgences');
		metaData.mBestScore = ReadInt('sinwave_meta_best');
		metaData.mRuns = ReadInt('sinwave_meta_runs');
		let purchases = CVar.FindCVar('sinwave_meta_purchases');
		if (purchases != null) metaData.DecodePurchases(purchases.GetString());
		return metaData;
	}

	override void Save(Sinwave_MetaData metaData)
	{
		WriteInt('sinwave_meta_indulgences', metaData.mIndulgences);
		WriteInt('sinwave_meta_best', metaData.mBestScore);
		WriteInt('sinwave_meta_runs', metaData.mRuns);
		let purchases = CVar.FindCVar('sinwave_meta_purchases');
		if (purchases != null) purchases.SetString(metaData.EncodePurchases());
		// Écrit le fichier tout de suite : rien n'est perdu si le jeu plante ensuite.
		CVar.SaveConfig();
	}

	override void LoadRules(Sinwave_RunRules rules)
	{
		let cv = CVar.FindCVar('sinwave_rules');
		if (cv != null) rules.Decode(cv.GetString());
	}

	override void SaveRules(Sinwave_RunRules rules)
	{
		let cv = CVar.FindCVar('sinwave_rules');
		if (cv != null) cv.SetString(rules.Encode());
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
