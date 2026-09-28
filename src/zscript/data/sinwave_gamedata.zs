// =============================================================================
//  Service « GameData » : toutes les données du jeu, chargées depuis data/*.txt.
// =============================================================================
//
//  Les fichiers sont lus une fois au chargement de la carte, puis vérifiés
//  (références croisées, doublons). Les systèmes lisent ces données sans jamais
//  les modifier. Un mod peut remplacer n'importe quel fichier en le plaçant au
//  même chemin dans une archive chargée après sinwave.pk3.

class Sinwave_GameData : Sinwave_Service
{
	Array<Sinwave_SystemDef> mSystems;
	Array<Sinwave_EnemyDef> mEnemies;
	Array<Sinwave_WaveDef> mWaves;
	Array<Sinwave_UpgradeDef> mUpgrades;
	Array<Sinwave_UnlockDef> mUnlocks;
	Sinwave_ProgressionDef mProgression;

	static Sinwave_GameData From(Sinwave_Services services)
	{
		return Sinwave_GameData(services.Get('GameData'));
	}

	void LoadAll()
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
			if (FindEnemy(blocks[i].mId) != null)
			{
				blocks[i].Warn("identifiant déjà utilisé, bloc ignoré.");
				continue;
			}
			let def = Sinwave_EnemyDef.FromBlock(blocks[i]);
			if (def != null) mEnemies.Push(def);
		}

		ReadBlocks("data/waves.txt", 'wave', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			let def = Sinwave_WaveDef.FromBlock(blocks[i]);
			if (ValidateWave(def, blocks[i])) mWaves.Push(def);
		}

		ReadBlocks("data/upgrades.txt", 'upgrade', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			mUpgrades.Push(Sinwave_UpgradeDef.FromBlock(blocks[i]));
		}

		ReadBlocks("data/unlocks.txt", 'unlock', blocks);
		for (int i = 0; i < blocks.Size(); i++)
		{
			mUnlocks.Push(Sinwave_UnlockDef.FromBlock(blocks[i]));
		}

		ReadBlocks("data/progression.txt", 'progression', blocks);
		mProgression = Sinwave_ProgressionDef.FromBlock(blocks.Size() > 0 ? blocks[0] : null);

		if (mWaves.Size() == 0) Console.Printf("\cg[Sinwave] Aucune vague valide : la run se terminera immédiatement.");
		Console.Printf("[Sinwave] Données chargées : %d systèmes, %d ennemis, %d vagues, %d améliorations, %d déblocages.",
			mSystems.Size(), mEnemies.Size(), mWaves.Size(), mUpgrades.Size(), mUnlocks.Size());
	}

	Sinwave_EnemyDef FindEnemy(Name id)
	{
		for (int i = 0; i < mEnemies.Size(); i++)
		{
			if (mEnemies[i].mId == id) return mEnemies[i];
		}
		return null;
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

	// Une vague ne doit référencer que des ennemis existants.
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
		if (wave.mEnemyIds.Size() == 0)
		{
			block.Warn("aucun ennemi valide, vague ignorée.");
			return false;
		}
		return true;
	}
}
