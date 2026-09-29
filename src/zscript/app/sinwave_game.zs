// =============================================================================
//  Sinwave_Game : racine de composition et pont avec le moteur.
// =============================================================================
//
//  C'est la SEULE classe déclarée au moteur (MAPINFO, AddEventHandlers) et la
//  seule qui connaît les classes concrètes. À chaque chargement de carte, elle :
//    1. crée les services (bus, données, sauvegarde, modèle d'interface) ;
//    2. crée les systèmes listés dans data/systems.txt ;
//    3. crée la machine à états et entre dans l'état Menu.
//
//  Ensuite, elle ne fait que traduire les appels du moteur en événements du bus
//  (mort d'un acteur, touche Utiliser, commandes de l'interface) et faire
//  avancer les états et les systèmes à chaque tic. Aucune règle de jeu ici.

class Sinwave_Game : EventHandler
{
	private Sinwave_Services mServices;
	private Sinwave_EventBus mBus;
	private Sinwave_StateMachine mMachine;
	private Array<Sinwave_System> mSystems;
	private Sinwave_HudModel mHudModel;
	private int mPreviousButtons;
	private bool mReady;

	// Objets d'interface : recréés à la demande, jamais écrits dans les sauvegardes.
	private transient ui Sinwave_UiController mUiController;
	private transient ui Sinwave_Hud mHud;

	// -------------------------------------------------------------------------
	//  Composition
	// -------------------------------------------------------------------------

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame)
		{
			// Les objets ont été restaurés avec la sauvegarde : on prévient seulement les systèmes.
			if (mReady) mBus.Publish(new('Sinwave_GameLoadedEvent'));
			return;
		}
		Compose();
	}

	private void Compose()
	{
		// 1. Services partagés, accessibles uniquement via ce Service Locator.
		mServices = new('Sinwave_Services');

		mBus = new('Sinwave_EventBus');
		mServices.Register('EventBus', mBus);

		let data = new('Sinwave_GameData');
		data.LoadAll(level.MapName);
		mServices.Register('GameData', data);

		mServices.Register('Save', new('Sinwave_CVarSaveService'));

		mHudModel = new('Sinwave_HudModel');
		mServices.Register('HudModel', mHudModel);

		// 2. Systèmes de jeu, dans l'ordre de data/systems.txt.
		for (int i = 0; i < data.mSystems.Size(); i++)
		{
			let def = data.mSystems[i];
			if (!def.mEnabled)
			{
				Console.Printf("[Sinwave] Système désactivé : %s", def.mId);
				continue;
			}
			let system = Sinwave_System(new(def.mClass));
			system.Init(def.mId, mServices);
			mSystems.Push(system);
		}

		// 3. Machine à états globale.
		mMachine = new('Sinwave_StateMachine');
		mMachine.Init(mBus);
		AddState('Sinwave_MenuState');
		AddState('Sinwave_ArenaSelectState');
		AddState('Sinwave_ShopState');
		AddState('Sinwave_InGameState');
		AddState('Sinwave_PauseState');
		AddState('Sinwave_UpgradeState');
		AddState('Sinwave_GameOverState');

		// 4. Démarrage.
		for (int i = 0; i < mSystems.Size(); i++)
		{
			mSystems[i].Start();
		}
		mMachine.ChangeState('Sinwave_MenuState');
		mReady = true;
	}

	private void AddState(class<Sinwave_GameState> type)
	{
		let gameState = Sinwave_GameState(new(type));
		gameState.Init(mServices);
		mMachine.AddState(gameState);
	}

	// -------------------------------------------------------------------------
	//  Moteur -> jeu
	// -------------------------------------------------------------------------

	override void WorldTick()
	{
		if (!mReady) return;
		PollInput();
		mMachine.Update();
		for (int i = 0; i < mSystems.Size(); i++)
		{
			mSystems[i].Tick();
		}
	}

	// Transforme l'appui sur Utiliser en événement (front montant uniquement).
	private void PollInput()
	{
		let pawn = Sinwave_World.Player();
		if (pawn == null) return;
		int buttons = pawn.player.cmd.buttons;
		if ((buttons & BT_USE) && !(mPreviousButtons & BT_USE))
		{
			mBus.Publish(Sinwave_ConfirmEvent.Create(false));
		}
		mPreviousButtons = buttons;
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (!mReady || e.Thing == null) return;
		if (e.Thing.player != null) mBus.Publish(new('Sinwave_PlayerDiedEvent'));
		else mBus.Publish(Sinwave_ActorDiedEvent.Create(e.Thing));
	}

	// Seuls les dégâts infligés par le joueur sont publiés (malédiction de la Colère...).
	override void WorldThingDamaged(WorldEvent e)
	{
		if (!mReady || e.Thing == null || e.DamageSource == null || e.DamageSource.player == null) return;
		if (e.Thing.player != null) return;
		mBus.Publish(Sinwave_ActorDamagedEvent.Create(e.Thing, e.Damage));
	}

	// Commandes envoyées par l'interface (SendNetworkEvent) ou tapées dans la
	// console (« netevent sinwave_pause »...). C'est le seul chemin ui -> jeu.
	override void NetworkProcess(ConsoleEvent e)
	{
		if (!mReady) return;
		if (e.Name ~== "sinwave_confirm") mBus.Publish(Sinwave_ConfirmEvent.Create(true));
		else if (e.Name ~== "sinwave_pause") mBus.Publish(new('Sinwave_PauseRequestedEvent'));
		else if (e.Name ~== "sinwave_resume") mBus.Publish(new('Sinwave_ResumeRequestedEvent'));
		else if (e.Name ~== "sinwave_abandon") mBus.Publish(new('Sinwave_AbandonRequestedEvent'));
		else if (e.Name ~== "sinwave_shop") mBus.Publish(new('Sinwave_ShopRequestedEvent'));
		else if (e.Name ~== "sinwave_back") mBus.Publish(new('Sinwave_BackRequestedEvent'));
		else if (e.Name ~== "sinwave_pick") mBus.Publish(Sinwave_UpgradePickedEvent.Create(e.Args[0]));
		else if (e.Name ~== "sinwave_buy") mBus.Publish(Sinwave_ShopBuyRequestedEvent.Create(e.Args[0]));
		else if (e.Name ~== "sinwave_arena") mBus.Publish(Sinwave_ArenaChosenEvent.Create(e.Args[0]));
	}

	// -------------------------------------------------------------------------
	//  Interface (portée « ui » : lecture seule du modèle)
	// -------------------------------------------------------------------------

	override void UiTick()
	{
		if (!mReady) return;
		if (mUiController == null) mUiController = new('Sinwave_UiController');
		mUiController.Update(mHudModel);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (!mReady) return;
		if (mHud == null) mHud = new('Sinwave_Hud');
		mHud.Draw(mHudModel);
	}
}
