// =============================================================================
//  Statistiques et équipement du joueur.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, RunSuspended, RunResumed, EffectGranted
//  Publie : rien
//
//  Remet le joueur à zéro en début de run, lui donne l'équipement de départ,
//  le ravitaille régulièrement et applique les effets qui le concernent :
//  maxhealth, heal, armor, damage, speed, regen, give.

class Sinwave_PlayerSystem : Sinwave_System
{
	private Sinwave_ProgressionDef mProgression;
	private bool mRunning;
	private bool mSuspended;
	private int mTics;
	private double mRegenPerSecond;
	private double mRegenCarry;

	override void Setup()
	{
		mProgression = Sinwave_GameData.From(mServices).mProgression;
		mBus.Subscribe(self, 'Sinwave_RunStartedEvent');
		mBus.Subscribe(self, 'Sinwave_RunEndedEvent');
		mBus.Subscribe(self, 'Sinwave_RunSuspendedEvent');
		mBus.Subscribe(self, 'Sinwave_RunResumedEvent');
		mBus.Subscribe(self, 'Sinwave_EffectGrantedEvent');
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_RunStartedEvent') StartRun();
		else if (e is 'Sinwave_RunEndedEvent') mRunning = false;
		else if (e is 'Sinwave_RunSuspendedEvent') mSuspended = true;
		else if (e is 'Sinwave_RunResumedEvent') mSuspended = false;
		else if (e is 'Sinwave_EffectGrantedEvent') Apply(Sinwave_EffectGrantedEvent(e).mEffect);
	}

	override void Tick()
	{
		if (!mRunning || mSuspended) return;
		let pawn = Sinwave_World.Player();
		if (pawn == null || pawn.health <= 0) return;

		mTics++;
		if (mRegenPerSecond > 0 && mTics % TICRATE == 0)
		{
			mRegenCarry += mRegenPerSecond;
			int heal = int(mRegenCarry);
			mRegenCarry -= heal;
			if (heal > 0) pawn.GiveBody(heal);
		}
		if (mProgression.mSupplyTics > 0 && mTics % mProgression.mSupplyTics == 0)
		{
			GiveItems(pawn, mProgression.mSupplyItems);
		}
	}

	private void StartRun()
	{
		mRunning = true;
		mSuspended = false;
		mTics = 0;
		mRegenPerSecond = 0;
		mRegenCarry = 0;

		let pawn = Sinwave_World.Player();
		if (pawn == null) return;
		// Ces valeurs survivent au rechargement de la carte : on les remet à zéro.
		pawn.stamina = 0;
		pawn.DamageMultiply = 1;
		pawn.Speed = 1;
		pawn.A_SetHealth(pawn.GetMaxHealth(true));
		GiveItems(pawn, mProgression.mStartItems);
	}

	private void Apply(Sinwave_Effect effect)
	{
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;

		switch (effect.mType)
		{
		case 'maxhealth':
			pawn.stamina += int(effect.mValue);
			pawn.GiveBody(int(effect.mValue));
			break;
		case 'heal':
			pawn.GiveBody(int(effect.mValue));
			break;
		case 'armor':
			pawn.GiveInventory('ArmorBonus', int(effect.mValue));
			break;
		case 'damage':
			pawn.DamageMultiply += effect.mValue;
			break;
		case 'speed':
			pawn.Speed += effect.mValue;
			break;
		case 'regen':
			mRegenPerSecond += effect.mValue;
			break;
		case 'give':
			if (effect.mItem != null) GiveItem(pawn, effect.mItem, effect.mAmount);
			break;
		}
	}

	private void GiveItems(Actor pawn, Array<Sinwave_ItemStack> items)
	{
		for (int i = 0; i < items.Size(); i++)
		{
			GiveItem(pawn, items[i].mType, items[i].mAmount);
		}
	}

	// Donne un objet ; une arme reçue est aussitôt prise en main.
	private void GiveItem(Actor pawn, class<Inventory> type, int amount)
	{
		pawn.GiveInventory(type, amount);
		let weaponType = (class<Weapon>)(type);
		if (weaponType != null) pawn.A_SelectWeapon(weaponType);
	}
}
