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
			"# commentaire\n[enemy Imp]\nname = Diablotin   # fin de ligne ignorée\nhealth = 1.5\n\n[wave 1]\nenemies = a:2, b:3\n",
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
		Sinwave_DataParser.ParseText("test", "[wave 1]\nenemies = a:2, b:3\n", blocks);
		let wave = Sinwave_WaveDef.FromBlock(blocks[0]);

		Check(wave.mTotalWeight == 5, "vagues : somme des poids");
		Check(wave.PickEnemy(0) == 'a' && wave.PickEnemy(1) == 'a', "vagues : tirage selon le poids (a)");
		Check(wave.PickEnemy(2) == 'b' && wave.PickEnemy(4) == 'b', "vagues : tirage selon le poids (b)");
	}
}
