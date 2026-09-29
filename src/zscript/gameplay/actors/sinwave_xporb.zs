// Orbe d'expérience lâchée par un ennemi. Elle est attirée par le joueur quand il
// passe à proximité, puis publie XpCollected. Le bus lui est donné à la création
// (injection de dépendance) : l'orbe ne cherche aucun objet global.
class Sinwave_XpOrb : Actor
{
	const PICKUP_DISTANCE = 40.0;
	const BASE_SPEED = 6.0;

	private Sinwave_EventBus mBus;
	private int mValue;
	private double mMagnetRadius;
	private int mLifetime;	// en tics ; 0 = illimitée

	Default
	{
		Radius 8;
		Height 16;
		Scale 0.75;
		RenderStyle "Add";
		+NOGRAVITY
		+NOBLOCKMAP
		+NOTELEPORT
		+DONTSPLASH
		+FLOATBOB
	}

	States
	{
	Spawn:
		BON1 ABCDCB 6 Bright;
		Loop;
	}

	void Setup(Sinwave_EventBus bus, int value, double magnetRadius)
	{
		mBus = bus;
		mValue = value;
		mMagnetRadius = magnetRadius;
	}

	// Utilisé par la malédiction de l'Avarice : l'orbe s'efface au bout du délai.
	void SetLifetime(int tics)
	{
		if (mLifetime == 0 || tics < mLifetime) mLifetime = max(1, tics);
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || mBus == null) return;

		if (mLifetime > 0)
		{
			mLifetime--;
			if (mLifetime < TICRATE) Alpha = mLifetime / double(TICRATE);
			if (mLifetime == 0)
			{
				Destroy();
				return;
			}
		}

		let pawn = Sinwave_World.Player();
		if (pawn == null || pawn.health <= 0) return;

		Vector3 target = pawn.pos + (0, 0, pawn.height / 2);
		Vector3 delta = target - pos;
		double distance = delta.Length();
		if (distance < PICKUP_DISTANCE)
		{
			Collect();
		}
		else if (distance < mMagnetRadius)
		{
			// Plus l'orbe est proche, plus elle accélère.
			double speed = BASE_SPEED + (mMagnetRadius - distance) / 16;
			SetOrigin(pos + delta.Unit() * min(speed, distance), true);
		}
	}

	private void Collect()
	{
		mBus.Publish(Sinwave_XpCollectedEvent.Create(mValue));
		A_StartSound("misc/i_pkup", CHAN_ITEM);
		Destroy();
	}
}
