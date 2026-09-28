// =============================================================================
//  Machine à états finis générique.
// =============================================================================

// Un état. Les sous-classes redéfinissent seulement ce dont elles ont besoin.
class Sinwave_State play
{
	protected Sinwave_StateMachine mMachine;

	void Attach(Sinwave_StateMachine machine)
	{
		mMachine = machine;
	}

	// Identifiant court publié dans Sinwave_StateChangedEvent (lu par l'interface).
	virtual Name Id() { return GetClassName(); }

	virtual void Enter() {}
	virtual void Exit() {}
	// Appelé à chaque tic tant que l'état est actif.
	virtual void Update() {}
	// Reçoit tous les événements du bus tant que l'état est actif :
	// c'est ici qu'un état décide de ses transitions.
	virtual void HandleEvent(Sinwave_Event e) {}
}

// Publié à chaque changement d'état.
class Sinwave_StateChangedEvent : Sinwave_Event
{
	Name mFrom;
	Name mTo;

	static Sinwave_StateChangedEvent Create(Name from, Name to)
	{
		let e = new('Sinwave_StateChangedEvent');
		e.mFrom = from;
		e.mTo = to;
		return e;
	}

	override String Describe()
	{
		return String.Format("%s -> %s", mFrom, mTo);
	}
}

// Seule la machine change d'état, toujours dans le même ordre :
//   Exit() de l'ancien état, publication de StateChanged, Enter() du nouveau.
// Chaque transition passe donc par un seul endroit : pas de code dupliqué entre états.
// Les états sont créés une fois et réutilisés (ils conservent leurs données).
class Sinwave_StateMachine : Sinwave_Listener
{
	private Array<Sinwave_State> mStates;
	private Sinwave_State mCurrent;
	private Sinwave_EventBus mBus;

	void Init(Sinwave_EventBus bus)
	{
		mBus = bus;
		// La machine écoute tout et transmet à l'état courant.
		bus.Subscribe(self);
	}

	void AddState(Sinwave_State newState)
	{
		newState.Attach(self);
		mStates.Push(newState);
	}

	Sinwave_State Current()
	{
		return mCurrent;
	}

	void ChangeState(class<Sinwave_State> type)
	{
		Sinwave_State next = null;
		for (int i = 0; i < mStates.Size(); i++)
		{
			if (mStates[i].GetClass() == type)
			{
				next = mStates[i];
				break;
			}
		}
		if (next == null)
		{
			Console.Printf("\cg[Sinwave] Transition vers un état non enregistré.");
			return;
		}
		if (next == mCurrent) return;

		let previous = mCurrent;
		if (previous != null) previous.Exit();
		mCurrent = next;
		mBus.Publish(Sinwave_StateChangedEvent.Create(previous != null ? previous.Id() : 'None', next.Id()));
		next.Enter();
	}

	void Update()
	{
		if (mCurrent != null) mCurrent.Update();
	}

	override void OnEvent(Sinwave_Event e)
	{
		if (mCurrent != null) mCurrent.HandleEvent(e);
	}
}
