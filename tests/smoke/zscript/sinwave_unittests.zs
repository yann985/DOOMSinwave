// =============================================================================
//  Tests unitaires du noyau (bus, Service Locator, machine à états, données).
// =============================================================================
//
//  Exécutés une fois au premier chargement de carte par tools\test.ps1.
//  Chaque vérification affiche « [test] ECHEC : ... » si elle échoue, puis un
//  bilan « [test] N réussis, M échoués ». Ces classes ne sont pas livrées dans le jeu.

class Sinwave_TestEventA : Sinwave_Event {}
class Sinwave_TestEventB : Sinwave_TestEventA {}	// sous-classe de A
class Sinwave_TestEventC : Sinwave_Event {}

class Sinwave_TestListener : Sinwave_Listener
{
	Array<Name> mReceived;
	Sinwave_EventBus mBusToLeave;	// si défini : se désabonne dès le premier événement

	override void OnEvent(Sinwave_Event e)
	{
		mReceived.Push(e.GetClassName());
		if (mBusToLeave != null) mBusToLeave.Unsubscribe(self);
	}

	int Count(Name type)
	{
		int n = 0;
		for (int i = 0; i < mReceived.Size(); i++)
		{
			if (mReceived[i] == type) n++;
		}
		return n;
	}
}

class Sinwave_TestLog play
{
	String mText;

	void Add(String entry)
	{
		mText = mText .. entry .. ";";
	}
}

class Sinwave_TestStateA : Sinwave_State
{
	Sinwave_TestLog mLog;
	override Name Id() { return 'A'; }
	override void Enter() { mLog.Add("enterA"); }
	override void Exit() { mLog.Add("exitA"); }
	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_TestEventC') mMachine.ChangeState('Sinwave_TestStateB');
	}
}

class Sinwave_TestStateB : Sinwave_State
{
	Sinwave_TestLog mLog;
	override Name Id() { return 'B'; }
	override void Enter() { mLog.Add("enterB"); }
	override void Exit() { mLog.Add("exitB"); }
}

class Sinwave_TestService : Sinwave_Service
{
	int mValue;
}

class Sinwave_UnitTests : StaticEventHandler
{
	private int mPassed;
	private int mFailed;
	private bool mDone;

	override void WorldLoaded(WorldEvent e)
	{
		if (mDone) return;
		mDone = true;

		TestBusTypedSubscription();
		TestBusGlobalSubscription();
		TestBusUnsubscribeDuringPublish();
		TestServices();
		TestStateMachine();
		TestDataParser();
		TestWaveWeights();
		TestCircleWaves();
		TestEffects();
		TestUpgradeKinds();
		TestSoul();
		TestJudgement();
		TestShopPrices();
		TestPurchasesEncoding();
		TestRules();
		TestThreats();

		Console.Printf("[test] %d réussis, %d échoués", mPassed, mFailed);
	}

	private void Check(bool condition, String description)
	{
		if (condition)
		{
			mPassed++;
		}
		else
		{
			mFailed++;
			Console.Printf("[test] ECHEC : %s", description);
		}
	}

	private void TestBusTypedSubscription()
	{
		let bus = new('Sinwave_EventBus');
		let listener = new('Sinwave_TestListener');
		bus.Subscribe(listener, 'Sinwave_TestEventA');

		bus.Publish(new('Sinwave_TestEventA'));
		bus.Publish(new('Sinwave_TestEventB'));
		bus.Publish(new('Sinwave_TestEventC'));

		Check(listener.Count('Sinwave_TestEventA') == 1, "bus : l'abonné reçoit son type");
		Check(listener.Count('Sinwave_TestEventB') == 1, "bus : l'abonné reçoit les sous-classes de son type");
		Check(listener.Count('Sinwave_TestEventC') == 0, "bus : l'abonné ne reçoit pas les autres types");
	}

	private void TestBusGlobalSubscription()
	{
		let bus = new('Sinwave_EventBus');
		let listener = new('Sinwave_TestListener');
		bus.Subscribe(listener);

		bus.Publish(new('Sinwave_TestEventA'));
		bus.Publish(new('Sinwave_TestEventC'));

		Check(listener.mReceived.Size() == 2, "bus : un abonnement sans type reçoit tout");
	}

	private void TestBusUnsubscribeDuringPublish()
	{
		let bus = new('Sinwave_EventBus');
		let leaving = new('Sinwave_TestListener');
		leaving.mBusToLeave = bus;
		let staying = new('Sinwave_TestListener');
		bus.Subscribe(leaving);
		bus.Subscribe(staying);

		bus.Publish(new('Sinwave_TestEventA'));
		bus.Publish(new('Sinwave_TestEventA'));

		Check(leaving.mReceived.Size() == 1, "bus : un abonné peut se désabonner pendant une diffusion");
		Check(staying.mReceived.Size() == 2, "bus : les autres abonnés ne sont pas affectés");
		Check(bus.SubscriptionCount() == 1, "bus : l'abonnement retiré est nettoyé");
	}

	private void TestServices()
	{
		let services = new('Sinwave_Services');
		let first = new('Sinwave_TestService');
		first.mValue = 1;
		let second = new('Sinwave_TestService');
		second.mValue = 2;

		services.Register('Test', first);
		Check(Sinwave_TestService(services.Get('Test')).mValue == 1, "services : Get renvoie le service enregistré");
		services.Register('Test', second);
		Check(Sinwave_TestService(services.Get('Test')).mValue == 2, "services : réenregistrer une clé remplace le service");
		Check(!services.Has('Absent'), "services : Has est faux pour une clé inconnue");
	}

	private void TestStateMachine()
	{
		let bus = new('Sinwave_EventBus');
		let watcher = new('Sinwave_TestListener');
		bus.Subscribe(watcher, 'Sinwave_StateChangedEvent');

		let log = new('Sinwave_TestLog');
		let stateA = new('Sinwave_TestStateA');
		stateA.mLog = log;
		let stateB = new('Sinwave_TestStateB');
		stateB.mLog = log;

		let machine = new('Sinwave_StateMachine');
		machine.Init(bus);
		machine.AddState(stateA);
		machine.AddState(stateB);

		machine.ChangeState('Sinwave_TestStateA');
		machine.ChangeState('Sinwave_TestStateA');		// déjà actif : rien ne doit se passer
		bus.Publish(new('Sinwave_TestEventC'));			// l'état A déclenche la transition vers B

		Check(log.mText == "enterA;exitA;enterB;", "états : ordre Enter/Exit correct (" .. log.mText .. ")");
		Check(machine.Current() == stateB, "états : une transition peut venir d'un événement");
		Check(watcher.Count('Sinwave_StateChangedEvent') == 2, "états : un StateChanged par transition");
	}

	private void TestDataParser()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test",
			"# commentaire\n[enemy Imp]\nname = Diablotin   # fin de ligne ignorée\nhealth = 1.5\n\n[circle 1]\nenemies = a:2, b:3\n",
			blocks);

		Check(blocks.Size() == 2, "données : deux blocs lus");
		if (blocks.Size() < 2) return;
		Check(blocks[0].mType == 'enemy' && blocks[0].mId == 'imp', "données : type et identifiant (en minuscules)");
		Check(blocks[0].GetString("name") == "Diablotin", "données : commentaire de fin de ligne retiré");
		Check(blocks[0].GetDouble("health") == 1.5, "données : nombre décimal");
		Check(blocks[0].GetInt("absent", 7) == 7, "données : valeur par défaut");

		Array<String> list;
		blocks[1].GetList("enemies", list);
		Check(list.Size() == 2 && list[1] == "b:3", "données : liste séparée par des virgules");
	}

	private void TestWaveWeights()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test", "[circle 1]\nenemies = a:2, b:3\n", blocks);
		let circle = Sinwave_CircleDef.FromBlock(blocks[0]);

		Check(circle.mTotalWeight == 5, "vagues : somme des poids");
		Check(circle.PickEnemy(0) == 'a' && circle.PickEnemy(1) == 'a', "vagues : tirage selon le poids (a)");
		Check(circle.PickEnemy(2) == 'b' && circle.PickEnemy(4) == 'b', "vagues : tirage selon le poids (b)");
	}

	// Un cercle enchaîne plusieurs vagues de plus en plus serrées ; la dernière
	// est celle du boss ; le rang d'une vague compte depuis le début de l'arène.
	private void TestCircleWaves()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test",
			"[circle 1]\nwaves = 3\nduration = 5\ninterval = 1\nmax = 10\nenemies = a\n"
			.. "[circle 2]\nwaves = 2\nduration = 5\nboss = lucifer\nenemies = a\n", blocks);
		let first = Sinwave_CircleDef.FromBlock(blocks[0]);
		let second = Sinwave_CircleDef.FromBlock(blocks[1]);

		Check(first.IntervalTicsForWave(0, 0.5) == 35 && first.IntervalTicsForWave(2, 0.5) == 18, "vagues : les apparitions accélèrent d'une vague à l'autre");
		Check(first.MaxAliveForWave(0, 3) == 10 && first.MaxAliveForWave(2, 3) == 16, "vagues : plus d'ennemis vivants d'une vague à l'autre");
		Check(!first.IsBossWave(2) && first.WaveTics(2) == 5 * TICRATE, "vagues : sans boss, toutes les vagues sont minutées");
		Check(!second.IsBossWave(0) && second.IsBossWave(1) && second.WaveTics(1) == 0, "vagues : la dernière vague est celle du boss, sans durée");

		let data = new('Sinwave_GameData');
		data.mCircles.Push(first);
		data.mCircles.Push(second);
		Check(data.WaveRank(0, 0) == 0 && data.WaveRank(1, 1) == 4, "vagues : rang compté depuis le début de l'arène");
	}

	// Jugement de l'âme : paliers, rayons de la boutique, déplacement après une run.
	private void TestJudgement()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test",
			"[judgement j]\nneutral = 50\nneutral_zone = 15\ngrace_tiers = 40, 25, 10\ncorruption_tiers = 60, 75, 90\nrun_shift = 6, 10, 15\nbalance_pull = 4\n"
			.. "[item holy]\nside = grace\ntier = 2\n[item evil]\nside = corruption\ntier = 1\n[item mid]\nside = neutral\n[item gun]\n", blocks);
		let judgement = Sinwave_JudgementDef.FromBlock(blocks[0]);
		let holy = Sinwave_ShopItemDef.FromBlock(blocks[1]);
		let evil = Sinwave_ShopItemDef.FromBlock(blocks[2]);
		let mid = Sinwave_ShopItemDef.FromBlock(blocks[3]);
		let gun = Sinwave_ShopItemDef.FromBlock(blocks[4]);

		Check(judgement.Tier(50) == 0 && judgement.Tier(40) == -1 && judgement.Tier(10) == -3 && judgement.Tier(60) == 1 && judgement.Tier(95) == 3,
			"jugement : paliers de Grâce et de Corruption");
		Check(!judgement.IsUnlocked(holy, 30) && judgement.IsUnlocked(holy, 25), "jugement : un rayon de Grâce s'ouvre sous son seuil");
		Check(judgement.IsUnlocked(evil, 60) && !judgement.IsUnlocked(evil, 59), "jugement : un rayon de Corruption s'ouvre au-dessus du sien");
		Check(judgement.IsUnlocked(mid, 65) && !judgement.IsUnlocked(mid, 66), "jugement : l'Équilibre n'est ouvert que près de la neutralité");
		Check(judgement.IsUnlocked(gun, 0) && judgement.IsUnlocked(gun, 100), "jugement : l'armurerie est toujours ouverte");
		Check(!judgement.CanBuy(holy, 50, 0) && judgement.CanBuy(holy, 50, 1), "jugement : un article acheté reste débloqué pour toujours");
		Check(judgement.AfterRun(50, 1, 3) == 65 && judgement.AfterRun(50, -1, 1) == 44, "jugement : plus l'âme a penché, plus il bouge");
		Check(judgement.AfterRun(60, 0, 0) == 56 && judgement.AfterRun(48, 0, 0) == 50, "jugement : une run à l'équilibre le ramène vers la neutralité");
		Check(judgement.AfterRun(98, 1, 3) == 100, "jugement : borné");
	}

	// Menaces : un ennemi qui prend son élan contre le joueur, un projectile qui arrive.
	private void TestThreats()
	{
		let pawn = players[consoleplayer].mo;
		if (pawn == null)
		{
			Check(false, "menaces : pas de joueur");
			return;
		}
		let imp = Actor.Spawn('DoomImp', pawn.pos + (300, 0, 0));
		imp.target = pawn;
		Check(!Sinwave_ThreatSystem.IsPreparingAttack(imp, pawn), "menaces : un ennemi qui marche n'en est pas une");
		imp.SetState(imp.MissileState);
		Check(Sinwave_ThreatSystem.IsPreparingAttack(imp, pawn), "menaces : un ennemi qui prend son élan en est une");

		let ball = Actor.Spawn('DoomImpBall', pawn.pos + (200, 0, pawn.height / 2));
		ball.target = imp;
		ball.vel = (-10, 0, 0);
		Check(Sinwave_ThreatSystem.IsIncomingProjectile(ball, pawn, TICRATE), "menaces : un projectile qui arrive en est une");
		ball.vel = (10, 0, 0);
		Check(!Sinwave_ThreatSystem.IsIncomingProjectile(ball, pawn, TICRATE), "menaces : un projectile qui s'éloigne n'en est pas une");
		ball.vel = (-1, 0, 0);
		Check(!Sinwave_ThreatSystem.IsIncomingProjectile(ball, pawn, TICRATE), "menaces : un projectile encore loin n'en est pas une");

		ball.Destroy();
		imp.Destroy();
	}

	private void TestEffects()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test", "[upgrade x]\neffects = damage:0.4, give:Shell:20, give:Shotgun\n", blocks);
		Array<Sinwave_Effect> effects;
		Sinwave_Effect.ParseList(blocks[0], "effects", effects);

		Check(effects.Size() == 3, "effets : trois effets lus");
		if (effects.Size() < 3) return;
		Check(effects[0].mType == 'damage' && effects[0].mValue == 0.4, "effets : type et valeur");
		Check(effects[1].mType == 'give' && effects[1].mItem == 'Shell' && effects[1].mAmount == 20, "effets : objet et quantité");
		Check(effects[2].mAmount == 1, "effets : quantité 1 par défaut");
	}

	private void TestUpgradeKinds()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test",
			"[upgrade v]\nkind = virtue\neffects = speed:0.1\n[upgrade s]\nkind = sin\ncorruption = 2\neffects = damage:0.4, vulnerability:0.25\n",
			blocks);
		let virtue = Sinwave_UpgradeDef.FromBlock(blocks[0]);
		let sin = Sinwave_UpgradeDef.FromBlock(blocks[1]);

		Check(!virtue.mIsSin && virtue.mCorruption == 0, "améliorations : sans clé corruption, aucune corruption");
		Check(sin.mIsSin && sin.mCorruption == 2 && sin.mEffects.Size() == 2, "améliorations : un péché a un défaut et de la corruption");
	}

	// Balance de l'âme : paliers des deux côtés, butin, verdict, puis le système
	// qui applique et retire les effets des paliers.
	private void TestSoul()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test",
			"[soul s]\nmin = 0\nmax = 30\nbalance = 15\nhealth_drop = 10\nammo_drop = 10\n"
			.. "sin_ammo_drop = 2\nsin_health_drop = -1\nvirtue_health_drop = 2\nvirtue_ammo_drop = -1\n"
			.. "[tier b]\nside = sin\nat = 30\nhealth_drop = -100\n"
			.. "[tier a]\nside = sin\nat = 20\nammo_drop = 5\neffects = damage:0.1\ntemptation = 1\nboss_health = -0.1\nboss_escort = 0.2\n"
			.. "[tier c]\nside = virtue\nat = 10\nboss_health = 0.15\nboss_escort = -0.15\n", blocks);
		let soul = Sinwave_SoulDef.FromBlocks(blocks);

		Check(soul.mTiers.Size() == 3 && soul.mTiers[2].mAt == 30, "âme : paliers rangés du plus proche au plus extrême");
		Array<Sinwave_SoulTierDef> reached;
		soul.ReachedTiers(15, reached);
		Check(soul.Side(15) == 0 && reached.Size() == 0, "âme : aucun palier à l'équilibre");
		Check(soul.DropChance(15, true) == 10 && soul.DropChance(15, false) == 10, "âme : butin de base à l'équilibre");
		soul.ReachedTiers(25, reached);
		Check(reached.Size() == 1 && reached[0].mAt == 20, "âme : paliers atteints côté péché");
		Check(soul.DropChance(25, false) == 35 && soul.DropChance(25, true) == 0, "âme : plus de munitions, moins de soins côté péché");
		soul.ReachedTiers(30, reached);
		Check(reached.Size() == 2, "âme : les paliers d'un même côté s'additionnent");
		Check(soul.DropChance(5, true) == 30 && soul.DropChance(5, false) == 0, "âme : l'inverse côté vertu");
		Check(soul.Temptation(15) == 0 && soul.Temptation(25) == 1, "âme : la pente glissante tire les choix vers le camp atteint");
		Check(soul.BossHealthFactor(25) ~== 0.9 && soul.BossEscortFactor(25) ~== 1.2, "âme : corrompue, boss plus faible mais mieux entouré");
		Check(soul.BossHealthFactor(5) ~== 1.15 && soul.BossEscortFactor(5) ~== 0.85, "âme : pure, boss plus fort mais seul");

		Check(Sinwave_CorruptionChangedEvent.Create(19, soul).Verdict() == Sinwave_CorruptionChangedEvent.VERDICT_PURGATORY, "verdict : Purgatoire sans palier");
		Check(Sinwave_CorruptionChangedEvent.Create(20, soul).Verdict() == Sinwave_CorruptionChangedEvent.VERDICT_DAMNATION, "verdict : Damnation dès un palier du péché");
		Check(Sinwave_CorruptionChangedEvent.Create(10, soul).Verdict() == Sinwave_CorruptionChangedEvent.VERDICT_ABSOLUTION, "verdict : Absolution dès un palier de la vertu");

		// Le système, branché sur un bus de test.
		let services = new('Sinwave_Services');
		let bus = new('Sinwave_EventBus');
		services.Register('EventBus', bus);
		let data = new('Sinwave_GameData');
		data.mSoul = soul;
		services.Register('GameData', data);
		let system = new('Sinwave_CorruptionSystem');
		system.Init('corruption', services);
		let listener = new('Sinwave_TestListener');
		bus.Subscribe(listener);
		bus.Publish(new('Sinwave_RunStartedEvent'));
		system.Tick();

		let sin = new('Sinwave_UpgradeDef');
		sin.mCorruption = 6;								// 15 -> 21 : palier « a »
		bus.Publish(Sinwave_UpgradeChosenEvent.Create(sin));
		Check(listener.Count('Sinwave_SoulTierChangedEvent') == 1 && listener.Count('Sinwave_EffectGrantedEvent') == 1, "âme : un palier atteint applique ses effets");
		let virtue = new('Sinwave_UpgradeDef');
		virtue.mCorruption = -3;							// 21 -> 18 : palier perdu
		bus.Publish(Sinwave_UpgradeChosenEvent.Create(virtue));
		Check(listener.Count('Sinwave_SoulTierChangedEvent') == 2 && listener.Count('Sinwave_EffectGrantedEvent') == 2, "âme : un palier perdu retire ses effets");

		// Le présentateur de l'interface, abonné après ce système comme dans le jeu :
		// CorruptionChanged, publié pendant RunStarted, lui arrive avant RunStarted.
		let uiServices = new('Sinwave_Services');
		let uiBus = new('Sinwave_EventBus');
		uiServices.Register('EventBus', uiBus);
		uiServices.Register('GameData', data);
		let model = new('Sinwave_HudModel');
		uiServices.Register('HudModel', model);
		let soulSystem = new('Sinwave_CorruptionSystem');
		soulSystem.Init('corruption', uiServices);
		let presenter = new('Sinwave_HudPresenter');
		presenter.Init('hud', uiServices);
		uiBus.Publish(new('Sinwave_RunStartedEvent'));
		Check(model.mCorruption == 15 && model.mSoulTierName == "équilibre", "interface : la run s'affiche à l'équilibre, quel que soit l'ordre de diffusion");
	}

	private void TestShopPrices()
	{
		Array<Sinwave_DataBlock> blocks;
		Sinwave_DataParser.ParseText("test", "[item vigor]\nprice = 10\nprice_growth = 1.5\nmax = 3\neffects = maxhealth:15\n", blocks);
		let item = Sinwave_ShopItemDef.FromBlock(blocks[0]);

		Check(item.PriceForLevel(0) == 10, "boutique : prix du premier niveau");
		Check(item.PriceForLevel(1) == 15 && item.PriceForLevel(2) == 23, "boutique : prix croissant par niveau");
	}

	private void TestPurchasesEncoding()
	{
		let original = new('Sinwave_MetaData');
		original.SetLevel('shotgun', 1);
		original.SetLevel('vigor', 3);
		let copy = new('Sinwave_MetaData');
		copy.DecodePurchases(original.EncodePurchases());

		Check(copy.GetLevel('shotgun') == 1 && copy.GetLevel('vigor') == 3, "sauvegarde : achats relus à l'identique");
		Check(copy.GetLevel('absent') == 0, "sauvegarde : article jamais acheté au niveau 0");
	}

	private void TestRules()
	{
		let normal = Sinwave_RunRules.Create();
		Check(normal.RewardFactor() == 1.0, "règles : récompense x1 en difficulté normale");

		let hard = Sinwave_RunRules.Create();
		hard.mEnemyHealth = 2;
		hard.mSpawnRate = 2;
		Check(hard.RewardFactor() > 1.0, "règles : un défi plus dur rapporte plus");

		let copy = Sinwave_RunRules.Create();
		hard.mStartCircle = 3;
		hard.mPreset = 'None';
		copy.Decode(hard.Encode());
		Check(copy.mEnemyHealth == 2 && copy.mSpawnRate == 2 && copy.mStartCircle == 3, "règles : relues à l'identique");

		copy.Decode("health=99;circle=0");
		Check(copy.mEnemyHealth == Sinwave_RunRules.HEALTH_MAX && copy.mStartCircle == 1, "règles : valeurs hors bornes corrigées");
	}
}
