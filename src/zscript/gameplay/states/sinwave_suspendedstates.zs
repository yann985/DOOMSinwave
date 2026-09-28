// =============================================================================
//  États où la run est suspendue : Pause et choix d'amélioration.
// =============================================================================

// Base commune : la suspension et la reprise ne sont écrites qu'une fois, ici.
// Pendant ces états, l'interface ouvre un menu, et un menu ouvert met le moteur
// en pause : les monstres et le joueur ne bougent plus.
class Sinwave_SuspendedState : Sinwave_GameState abstract
{
	private bool mRunEnding;

	override void Enter()
	{
		mRunEnding = false;
		mBus.Publish(new('Sinwave_RunSuspendedEvent'));
	}

	override void Exit()
	{
		if (!mRunEnding) mBus.Publish(new('Sinwave_RunResumedEvent'));
	}

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_PlayerDiedEvent') Finish(Sinwave_RunEndedEvent.REASON_DEATH);
	}

	protected void Resume()
	{
		SwitchTo('Sinwave_InGameState');
	}

	protected void Finish(int reason)
	{
		mRunEnding = true;
		EndRun(reason);
	}
}

// Pause demandée par le joueur (touche P par défaut, voir KEYCONF).
class Sinwave_PauseState : Sinwave_SuspendedState
{
	override Name Id() { return 'Pause'; }

	override void HandleEvent(Sinwave_Event e)
	{
		Super.HandleEvent(e);
		if (e is 'Sinwave_ResumeRequestedEvent' || e is 'Sinwave_PauseRequestedEvent') Resume();
		else if (e is 'Sinwave_AbandonRequestedEvent') Finish(Sinwave_RunEndedEvent.REASON_ABANDON);
	}
}

// Choix d'une amélioration après une montée de niveau.
class Sinwave_UpgradeState : Sinwave_SuspendedState
{
	// Délai avant le choix automatique quand aucun menu n'a mis le jeu en pause.
	const FALLBACK_TICS = 2 * TICRATE;

	private int mTics;

	override Name Id() { return 'Upgrade'; }

	override void Enter()
	{
		Super.Enter();
		mTics = 0;
	}

	override void HandleEvent(Sinwave_Event e)
	{
		Super.HandleEvent(e);
		if (e is 'Sinwave_UpgradeChosenEvent') Resume();
	}

	// Normalement, le menu d'amélioration met le moteur en pause et Update() n'est
	// plus appelé. Si le jeu continue de tourner, c'est qu'aucune interface n'est
	// là pour choisir (système « hud » désactivé) : on prend la première proposition
	// pour que la run ne reste pas bloquée.
	override void Update()
	{
		mTics++;
		if (mTics == FALLBACK_TICS)
		{
			Console.Printf("[Sinwave] Aucune interface de choix : première amélioration choisie automatiquement.");
			mBus.Publish(Sinwave_UpgradePickedEvent.Create(0));
		}
	}
}
