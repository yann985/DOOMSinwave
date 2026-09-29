// =============================================================================
//  Service « GameData » : toutes les données du jeu, chargées depuis data/.
// =============================================================================
//
//  Les fichiers sont lus au chargement de la carte, puis vérifiés (références
//  croisées, doublons). L'arène courante est celle dont la carte est chargée ;
//  ses vagues viennent de son propre fichier (data/waves/...). Les systèmes lisent
//  ces données sans jamais les modifier. Un mod peut remplacer n'importe quel
//  fichier, ou ajouter des arènes, dans une archive chargée après sinwave.pk3.

class Sinwave_GameData : Sinwave_Service
{
	Array<Sinwave_SystemDef> mSystems;
	Array<Sinwave_EnemyDef> mEnemies;
	Array<Sinwave_CurseDef> mCurses;
	Array<Sinwave_UpgradeDef> mUpgrades;
	Array<Sinwave_ShopItemDef> mShopItems;
	Array<Sinwave_ArenaDef> mArenas;
	Sinwave_ProgressionDef mProgression;

	// Arène de la carte courante et ses vagues.
	Sinwave_ArenaDef mArena;
	int mArenaIndex;
	Array<Sinwave_WaveDef> mWaves;

	static Sinwave_GameData From(Sinwave_Services services)
	{
		return Sinwave_GameData(services.Get('GameData'));
	}

	void LoadAll(String mapName)
	{
		Array<Sinwave_DataBlock> blocks;

		ReadBlocks("data/systems.txt", 'system', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_SystemDef.FromBlock(blocks[i]);
			if (def != null) mSystems.Push(def);
		}

		ReadBlocks("data/enemies.txt", 'enemy', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			if (FindEnemy(blocks[i].mId) != null) { blocks[i].Warn("identifiant déjà utilisé."); continue; }
			let def = Sinwave_EnemyDef.FromBlock(blocks[i]);
			if (def != null) mEnemies.Push(def);
		}

		ReadBlocks("data/curses.txt", 'curse', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_CurseDef.FromBlock(blocks[i]);
			if (def != null) mCurses.Push(def);
		}

		ReadBlocks("data/upgrades.txt", 'upgrade', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			mUpgrades.Push(Sinwave_UpgradeDef.FromBlock(blocks[i]));
		}

		ReadBlocks("data/shop.txt", 'item', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			if (FindShopItem(blocks[i].mId) != null) { blocks[i].Warn("identifiant déjà utilisé."); continue; }
			mShopItems.Push(Sinwave_ShopItemDef.FromBlock(blocks[i]));
		}

		ReadBlocks("data/progression.txt", 'progression', blocks);
		mProgression = Sinwave_ProgressionDef.FromBlock(blocks.Size() > 0 ? blocks[0] : null);

		ReadBlocks("data/arenas.txt", 'arena', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_ArenaDef.FromBlock(blocks[i]);
			if (def != null) mArenas.Push(def);
		}

		SelectArena(mapName);

		Console.Printf("[Sinwave] Données chargées : %d systèmes, %d ennemis, %d malédictions, %d améliorations, %d articles, %d arènes.",
			mSystems.Size(), mEnemies.Size(), mCurses.Size(), mUpgrades.Size(), mShopItems.Size(), mArenas.Size());
		if (mArena != null) Console.Printf("[Sinwave] Arène : %s (%d cercles).", mArena.mName, mWaves.Size());
	}

	Sinwave_EnemyDef FindEnemy(Name id)
	{
		for (int i = 0; i < mEnemies.Size(); i++)
		{
			if (mEnemies[i].mId == id) return mEnemies[i];
		}
		return null;
	}

	Sinwave_CurseDef FindCurse(Name id)
	{
		for (int i = 0; i < mCurses.Size(); i++)
		{
			if (mCurses[i].mId == id) return mCurses[i];
		}
		return null;
	}

	Sinwave_ShopItemDef FindShopItem(Name id)
	{
		for (int i = 0; i < mShopItems.Size(); i++)
		{
			if (mShopItems[i].mId == id) return mShopItems[i];
		}
		return null;
	}

	// L'arène est celle de la carte chargée ; à défaut, la première de la liste.
	private void SelectArena(String mapName)
	{
		mArena = null;
		mArenaIndex = -1;
		for (int i = 0; i < mArenas.Size(); i++)
		{
			if (mArenas[i].mMap ~== mapName)
			{
				mArena = mArenas[i];
				mArenaIndex = i;
				break;
			}
		}
		if (mArena == null && mArenas.Size() > 0)
		{
			mArena = mArenas[0];
			mArenaIndex = 0;
		}
		if (mArena == null)
		{
			Console.Printf("\cg[Sinwave] Aucune arène définie dans data/arenas.txt.");
			mArena = Sinwave_ArenaDef.Neutral();
			return;
		}

		Array<Sinwave_DataBlock> blocks;
		ReadBlocks(mArena.mWavesFile, 'wave', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_WaveDef.FromBlock(blocks[i]);
			if (ValidateWave(def, blocks[i])) mWaves.Push(def);
		}
		if (mWaves.Size() == 0) Console.Printf("\cg[Sinwave] Aucune vague valide : la run se terminera immédiatement.");
	}

	// Lit un fichier et ne garde que les blocs du type attendu.
	private void ReadBlocks(String path, Name expectedType, out Array<Sinwave_DataBlock> result)
	{
		result.Clear();
		Array<Sinwave_DataBlock> all;
		if (!Sinwave_DataParser.ParseLump(path, all)) return;
		for (int i = 0; i < all.Size(); i++)
		{
			if (all[i].mType == expectedType) result.Push(all[i]);
			else all[i].Warn(String.Format("type de bloc inattendu, [%s ...] attendu.", expectedType));
		}
	}

	// Une vague ne doit référencer que des ennemis, une malédiction et un boss existants.
	private bool ValidateWave(Sinwave_WaveDef wave, Sinwave_DataBlock block)
	{
		for (int i = wave.mEnemyIds.Size() - 1; i >= 0; i--)
		{
			if (FindEnemy(wave.mEnemyIds[i]) == null)
			{
				block.Warn(String.Format("ennemi inconnu : \"%s\".", wave.mEnemyIds[i]));
				wave.RemoveEnemyAt(i);
			}
		}
		if (wave.mCurseId != 'None' && FindCurse(wave.mCurseId) == null)
		{
			block.Warn(String.Format("malédiction inconnue : \"%s\".", wave.mCurseId));
			wave.mCurseId = 'None';
		}
		if (wave.HasBoss() && FindEnemy(wave.mBossId) == null)
		{
			block.Warn(String.Format("boss inconnu : \"%s\".", wave.mBossId));
			return false;
		}
		if (wave.mEnemyIds.Size() == 0 && !wave.HasBoss())
		{
			block.Warn("aucun ennemi valide, vague ignorée.");
			return false;
		}
		return true;
	}
}
