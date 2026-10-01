// Option « Tir : appuyer pour basculer » (sinwave_fire_toggle).
//
// Le moteur tire tant qu'une touche liée à +attack est enfoncée. Pendant la run, le
// premier appui passe au moteur (le tir commence) mais son relâchement est avalé :
// pour le moteur, la touche reste enfoncée. L'appui suivant est avalé et son
// relâchement passe : le tir s'arrête.
// Le moteur peut lâcher le tir de lui-même (menu, console, changement de carte) :
// on le voit au bouton de tir de la commande du joueur, et l'option repart de zéro.
// Le jeu ne peut pas tirer à la place du joueur : le moteur fait agir le joueur avant
// d'appeler le code du jeu à chaque tic.
//
// Logique seule, sans le moteur (testée par les tests unitaires) : Sinwave_Game lui
// passe les touches et l'état du tir.
class Sinwave_FireToggle
{
	private bool mLatched;		// tir allumé : la touche mLatchKey est tenue pour le moteur
	private int mLatchKey;
	private bool mSwallowUp;	// relâchement de la touche qui a allumé le tir, à avaler
	private bool mSeen;			// le moteur a bien pris le tir en compte

	// Une touche est enfoncée. isFire : elle est liée à +attack ; enabled : l'option
	// est active et la run en cours. Vrai si la touche est avalée (le moteur ne la voit pas).
	bool KeyDown(int key, bool isFire, bool enabled)
	{
		if (!isFire || !enabled) return false;
		if (!mLatched)
		{
			mLatched = true;
			mLatchKey = key;
			mSwallowUp = true;
			mSeen = false;
			return false;	// le moteur commence à tirer
		}
		mLatched = false;
		mSwallowUp = false;
		return true;		// déjà en train de tirer : le relâchement qui suit arrêtera le tir
	}

	// Une touche est relâchée. Vrai si elle est avalée.
	bool KeyUp(int key)
	{
		if (!mSwallowUp || key != mLatchKey) return false;
		mSwallowUp = false;
		return true;
	}

	// À chaque tic. firing : le bouton de tir est pressé dans la commande du joueur.
	void Update(bool firing)
	{
		if (!mLatched) return;
		if (firing) mSeen = true;
		else if (mSeen)
		{
			// Le moteur a lâché le tir de lui-même.
			mLatched = false;
			mSwallowUp = false;
		}
	}

	bool IsFiring()
	{
		return mLatched;
	}
}
