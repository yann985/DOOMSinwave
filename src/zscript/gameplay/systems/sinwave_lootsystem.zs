// =============================================================================
//  Butin : soins et munitions lâchés par les ennemis tués.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, CorruptionChanged, EnemyKilled, ItemSpawned
//  Publie : rien
//
//  Les chances dépendent de la balance de l'âme (data/soul.txt) : plus elle
//  penche vers le péché, plus il tombe de munitions et moins de soins ; vers la
//  vertu, l'inverse. La munition lâchée est celle de l'arme en main.
//  Les objets que les monstres de Doom lâchent d'eux-mêmes (chargeurs...) sont
//  retirés selon monster_drops, pour que le butin ne dépende que de l'âme.

class Sinwave_LootSystem : Sinwave_System
{
	private Sinwave_SoulDef mSoul;
	private bool mRunning;
	private int mCorruption;
	// Objets apparus ce tic : on ne sait qu'au tic suivant s'ils ont été lâchés
	// par un monstre (le moteur les marque juste après les avoir créés).
	private Array<Inventory> mSpawned;

	override void Setup()
	{
		mSoul = Sinwave_GameData.From(mServices).mSoul;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_CorruptionChangedEvent');
		mBus.Subscribe(self, 'Sinwave_EnemyKilledEvent');
		mBus.Subscribe(self, 'Sinwave_ItemSpawnedEvent');
	}

	override void Tick()
	{
		for (int i = 0; i < mSpawned.Size(); i++)
		{
			let item = mSpawned[i];
			if (item != null && item.bDropped && item.Owner == null && !mSoul.KeepsMonsterDrop(item)) item.Destroy();
		}
		mSpawned.Clear();
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent')
		{
			mRunning = true;
			mCorruption = mSoul.mBalance;
		}
		else if (e is 'Sinwave_RunEndedEvent') mRunning = false;
		else if (e is 'Sinwave_CorruptionChangedEvent') mCorruption = Sinwave_CorruptionChangedEvent(e).mCorruption;
		else if (e is 'Sinwave_EnemyKilledEvent' && mRunning) DropLoot(Sinwave_EnemyKilledEvent(e).mPos);
		else if (e is 'Sinwave_ItemSpawnedEvent' && mRunning) mSpawned.Push(Sinwave_ItemSpawnedEvent(e).mItem);
	}

	private void DropLoot(Vector3 pos)
	{
		if (mSoul.mHealthItem != null && FRandom[SinwaveLoot](0, 100) < mSoul.DropChance(mCorruption, true))
		{
			Toss(mSoul.mHealthItem, pos);
		}
		if (FRandom[SinwaveLoot](0, 100) < mSoul.DropChance(mCorruption, false))
		{
			Toss(AmmoForWeaponInHand(), pos);
		}
	}

	// Munition de l'arme en main (des balles pour le poing ou la tronçonneuse).
	private static class<Inventory> AmmoForWeaponInHand()
	{
		let pawn = Sinwave_World.Player();
		if (pawn != null && pawn.player.ReadyWeapon != null && pawn.player.ReadyWeapon.AmmoType1 != null)
		{
			return pawn.player.ReadyWeapon.AmmoType1;
		}
		return 'Clip';
	}

	// L'objet saute un peu hors du corps, comme les armes lâchées par les monstres.
	private static void Toss(class<Inventory> type, Vector3 pos)
	{
		let item = Actor.Spawn(type, pos + (FRandom[SinwaveLoot](-12, 12), FRandom[SinwaveLoot](-12, 12), 16));
		if (item == null) return;
		item.bDropped = false;	// butin de la balance : à ne pas confondre avec ce que lâchent les monstres
		item.vel = (FRandom[SinwaveLoot](-2, 2), FRandom[SinwaveLoot](-2, 2), 4);
	}
}
