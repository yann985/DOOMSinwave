// =============================================================================
//  Base des systèmes de jeu.
// =============================================================================

// Un système (vagues, XP, score...) reçoit seulement le Service Locator : il y
// récupère les services dont il a besoin, s'abonne au bus, et ne référence jamais
// un autre système. On peut donc le retirer de data/systems.txt sans casser les autres.
//
// Cycle de vie, piloté par la racine de composition :
//   Init()  -> Setup()   récupérer les services et s'abonner au bus
//   Start()              quand TOUS les systèmes sont prêts : premières publications
//   Tick()               à chaque tic de jeu (35 par seconde), sauf jeu en pause
class Sinwave_System : Sinwave_Listener
{
	protected Name mId;
	protected Sinwave_Services mServices;
	protected Sinwave_EventBus mBus;

	void Init(Name id, Sinwave_Services services)
	{
		mId = id;
		mServices = services;
		mBus = Sinwave_EventBus.From(services);
		Setup();
	}

	Name GetId()
	{
		return mId;
	}

	virtual void Setup() {}
	virtual void Start() {}
	virtual void Tick() {}
}
