// =============================================================================
//  Statistiques et équipement du joueur.
// =============================================================================
//
//  Écoute : RunStarted, RunEnded, RunSuspended, RunResumed, EffectGranted
//  Publie : rien
//
//  Remet le joueur à zéro en début de run, lui donne l'équipement de départ,
//  le ravitaille régulièrement et applique les effets qui le concernent :
//  maxhealth, heal, armor, damage, vulnerability, speed, regen, give, aura,
//  infiniteammo.

class Sinwave_PlayerSystem : Sinwave_System
{
	const AURA_RADIUS = 200.0;			// portée de l'aura sainte

	private Sinwave_ProgressionDef mProgression;
	private Sinwave_RunRules mRules;
	private bool mRunning;
	private bool mSuspended;
	private int mTics;
	private double mRegenPerSecond;
	private double mRegenCarry;
	private double mDamageBonus;		// dégâts infligés : +0.2 = +20 %
	private double mSpeedBonus;			// vitesse de déplacement
	private double mVulnerability;		// dégâts subis : +0.25 = +25 %
	private double mAuraDamage;			// dégâts par seconde aux ennemis proches
	private int mInfiniteAmmo;			// > 0 : munitions infinies

	override void Setup()
	{
		mProgression = Sinwave_GameData.From(mServices).mProgression;
		mRules = Sinwave_RunRules.From(mServices);
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
		if (mAuraDamage > 0 && mTics % TICRATE == 0) BurnNearby(pawn);
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
		mDamageBonus = 0;
		mSpeedBonus = 0;
		mVulnerability = 0;
		mAuraDamage = 0;
		mInfiniteAmmo = 0;

		let pawn = Sinwave_World.Player();
		if (pawn == null) return;
		// Ces valeurs survivent au rechargement de la carte : on les remet à zéro.
		pawn.stamina = 0;
		pawn.TakeInventory('Sinwave_EternalAmmo', 1);
		ApplyStats(pawn);
		pawn.A_SetHealth(pawn.GetMaxHealth(true));
		GiveItems(pawn, mProgression.mStartItems);
	}

	private void Apply(Sinwave_Effect effect)
	{
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;

		int amount = int(effect.mValue);
		switch (effect.mType)
		{
		case 'maxhealth':
			pawn.stamina += amount;
			if (amount > 0) pawn.GiveBody(amount);
			else if (pawn.health > pawn.GetMaxHealth(true)) pawn.A_SetHealth(max(1, pawn.GetMaxHealth(true)));
			break;
		case 'heal':
			pawn.GiveBody(amount);
			break;
		case 'armor':
			if (amount > 0) pawn.GiveInventory('ArmorBonus', amount);
			break;
		case 'damage':
			mDamageBonus += effect.mValue;
			break;
		case 'vulnerability':
			mVulnerability += effect.mValue;
			break;
		case 'speed':
			mSpeedBonus += effect.mValue;
			break;
		case 'regen':
			mRegenPerSecond += effect.mValue;
			break;
		case 'give':
			if (effect.mItem != null) GiveItem(pawn, effect.mItem, effect.mAmount);
			break;
		case 'aura':
			mAuraDamage += effect.mValue;
			break;
		case 'infiniteammo':
			mInfiniteAmmo += amount;
			if (mInfiniteAmmo > 0 && pawn.FindInventory('Sinwave_EternalAmmo') == null) pawn.GiveInventory('Sinwave_EternalAmmo', 1);
			else if (mInfiniteAmmo <= 0) pawn.TakeInventory('Sinwave_EternalAmmo', 1);
			break;
		}
		ApplyStats(pawn);
	}

	// Aura sainte : brûle les ennemis proches, et une onde de lumière dorée part du
	// joueur jusqu'à la portée de l'aura.
	private void BurnNearby(Actor pawn)
	{
		let it = BlockThingsIterator.Create(pawn, AURA_RADIUS);
		while (it.Next())
		{
			let mo = it.thing;
			if (mo == null || !mo.bIsMonster || mo.health <= 0 || pawn.Distance2D(mo) > AURA_RADIUS) continue;
			mo.DamageMobj(pawn, pawn, max(1, int(mAuraDamage)), 'Fire');
		}
		// Décalage et vitesse en coordonnées du monde : chaque particule part dans sa
		// propre direction, et l'ensemble forme un cercle qui s'élargit.
		int lifetime = 20;
		double speed = (AURA_RADIUS - 24) / lifetime;
		for (int i = 0; i < 36; i++)
		{
			Vector2 dir = Actor.AngleToVector(i * 10);
			pawn.A_SpawnParticle(Color(255, 210, 80), SPF_FULLBRIGHT, lifetime, 12, 0,
				dir.x * 24, dir.y * 24, 24, dir.x * speed, dir.y * speed, 0);
		}
	}

	// Les bonus s'additionnent ; les valeurs appliquées ont un plancher pour
	// qu'aucun cumul de malus ne rende le joueur immobile ou invincible.
	private void ApplyStats(Actor pawn)
	{
		pawn.DamageMultiply = max(0.1, 1 + mDamageBonus);
		pawn.DamageFactor = max(0.1, (1 + mVulnerability) * mRules.mDamageTaken);	// règles de la descente
		pawn.Speed = max(0.3, 1 + mSpeedBonus);
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
