// =============================================================================
//  Service « GameData » : toutes les données du jeu, chargées depuis data/.
// =============================================================================
//
//  Les fichiers sont lus au chargement de la carte, puis vérifiés (références
//  croisées, doublons). L'arène courante est celle dont la carte est chargée ;
//  ses cercles viennent de son propre fichier (data/waves/...). Les systèmes lisent
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
	Array<Sinwave_DifficultyDef> mDifficulties;
	Sinwave_ProgressionDef mProgression;
	Sinwave_SoulDef mSoul;

	// Arène de la carte courante et ses cercles.
	Sinwave_ArenaDef mArena;
	int mArenaIndex;
	Array<Sinwave_CircleDef> mCircles;

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

		// Balance de l'âme : un bloc [soul] et des blocs [tier] dans le même fichier.
		Array<Sinwave_DataBlock> soulBlocks;
		Sinwave_DataParser.ParseLump("data/soul.txt", soulBlocks);
		mSoul = Sinwave_SoulDef.FromBlocks(soulBlocks);

		ReadBlocks("data/difficulties.txt", 'difficulty', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			mDifficulties.Push(Sinwave_DifficultyDef.FromBlock(blocks[i]));
		}

		ReadBlocks("data/arenas.txt", 'arena', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_ArenaDef.FromBlock(blocks[i]);
			if (def == null) continue;
			// Noms des cercles de chaque arène, pour choisir le cercle de départ avant d'y aller.
			Array<Sinwave_DataBlock> circleBlocks;
			ReadBlocks(def.mWavesFile, 'circle', circleBlocks);
			for (int k = 0; k < circleBlocks.Size(); k++) def.mCircleNames.Push(circleBlocks[k].GetString("name", circleBlocks[k].mId));
			mArenas.Push(def);
		}

		SelectArena(mapName);

		Console.Printf("[Sinwave] Données chargées : %d systèmes, %d ennemis, %d malédictions, %d améliorations, %d articles, %d arènes.",
			mSystems.Size(), mEnemies.Size(), mCurses.Size(), mUpgrades.Size(), mShopItems.Size(), mArenas.Size());
		if (mArena != null) Console.Printf("[Sinwave] Arène : %s (%d cercles, %d vagues).", mArena.mName, mCircles.Size(), WaveRank(mCircles.Size(), 0));
	}

	// Rang d'une vague depuis le début de l'arène (0 : première vague du premier
	// cercle), quel que soit le cercle de départ choisi : la difficulté d'une vague
	// ne dépend que de sa place dans l'arène.
	int WaveRank(int circle, int wave)
	{
		int rank = wave;
		for (int i = 0; i < circle && i < mCircles.Size(); i++) rank += mCircles[i].mWaveCount;
		return rank;
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

	Sinwave_DifficultyDef FindDifficulty(Name id)
	{
		for (int i = 0; i < mDifficulties.Size(); i++)
		{
			if (mDifficulties[i].mId == id) return mDifficulties[i];
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
		ReadBlocks(mArena.mWavesFile, 'circle', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_CircleDef.FromBlock(blocks[i]);
			if (ValidateCircle(def, blocks[i])) mCircles.Push(def);
		}
		if (mCircles.Size() == 0) Console.Printf("\cg[Sinwave] Aucun cercle valide : la run se terminera immédiatement.");
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

	// Un cercle ne doit référencer que des ennemis, une malédiction et un boss existants.
	private bool ValidateCircle(Sinwave_CircleDef circle, Sinwave_DataBlock block)
	{
		for (int i = circle.mEnemyIds.Size() - 1; i >= 0; i--)
		{
			if (FindEnemy(circle.mEnemyIds[i]) == null)
			{
				block.Warn(String.Format("ennemi inconnu : \"%s\".", circle.mEnemyIds[i]));
				circle.RemoveEnemyAt(i);
			}
		}
		if (circle.mCurseId != 'None' && FindCurse(circle.mCurseId) == null)
		{
			block.Warn(String.Format("malédiction inconnue : \"%s\".", circle.mCurseId));
			circle.mCurseId = 'None';
		}
		if (circle.HasBoss() && FindEnemy(circle.mBossId) == null)
		{
			block.Warn(String.Format("boss inconnu : \"%s\".", circle.mBossId));
			return false;
		}
		if (circle.mEnemyIds.Size() == 0 && !circle.HasBoss())
		{
			block.Warn("aucun ennemi valide, cercle ignoré.");
			return false;
		}
		return true;
	}
}
