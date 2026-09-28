// Ouvre le bon menu quand le modèle le demande (portée « ui »).
// Chaque proposition d'amélioration et chaque pause portent un numéro : un menu
// n'est ouvert qu'une fois par numéro, même si le jeu met un tic à réagir au choix.
class Sinwave_UiController ui
{
	private int mOpenedOffer;
	private int mOpenedPause;

	void Update(Sinwave_HudModel model)
	{
		if (model.mScreen == Sinwave_HudModel.SCREEN_UPGRADE && model.mOfferSerial != mOpenedOffer)
		{
			if (Open('Sinwave_UpgradeMenu', model)) mOpenedOffer = model.mOfferSerial;
		}
		else if (model.mScreen == Sinwave_HudModel.SCREEN_PAUSE && model.mPauseSerial != mOpenedPause)
		{
			if (Open('Sinwave_PauseMenu', model)) mOpenedPause = model.mPauseSerial;
		}
	}

	private bool Open(Name menuClass, Sinwave_HudModel model)
	{
		// Un autre menu est ouvert (menu principal du moteur...) : on réessaiera au tic suivant.
		if (menuactive != Menu.Off) return false;

		Menu.SetMenu(menuClass);
		let menu = Sinwave_ChoiceMenu(Menu.GetCurrentMenu());
		if (menu == null) return false;
		menu.Bind(model);
		return true;
	}
}
