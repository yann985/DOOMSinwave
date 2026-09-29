// Ouvre le bon menu quand le modèle le demande (portée « ui »).
// Chaque ouverture d'écran porte un numéro dans le modèle : un menu n'est ouvert
// qu'une fois par numéro, même si le jeu met un tic à réagir au choix.
class Sinwave_UiController ui
{
	private int mOpenedOffer;
	private int mOpenedPause;
	private int mOpenedShop;
	private int mOpenedArenaSelect;
	private int mOpenedRules;

	void Update(Sinwave_HudModel model)
	{
		// Menu ouvert sur une carte précédente : il affiche une partie qui n'existe
		// plus et bloquerait le jeu en pause. On le ferme.
		let current = Sinwave_ChoiceMenu(Menu.GetCurrentMenu());
		if (current != null && !current.IsBoundTo(model)) current.Close();

		switch (model.mScreen)
		{
		case Sinwave_HudModel.SCREEN_UPGRADE:
			if (model.mOfferSerial != mOpenedOffer && Open('Sinwave_UpgradeMenu', model)) mOpenedOffer = model.mOfferSerial;
			break;
		case Sinwave_HudModel.SCREEN_PAUSE:
			if (model.mPauseSerial != mOpenedPause && Open('Sinwave_PauseMenu', model)) mOpenedPause = model.mPauseSerial;
			break;
		case Sinwave_HudModel.SCREEN_SHOP:
			if (model.mShopSerial != mOpenedShop && Open('Sinwave_ShopMenu', model)) mOpenedShop = model.mShopSerial;
			break;
		case Sinwave_HudModel.SCREEN_ARENA_SELECT:
			if (model.mArenaSelectSerial != mOpenedArenaSelect && Open('Sinwave_ArenaMenu', model)) mOpenedArenaSelect = model.mArenaSelectSerial;
			break;
		case Sinwave_HudModel.SCREEN_RULES:
			if (model.mRulesSerial != mOpenedRules && Open('Sinwave_RulesMenu', model)) mOpenedRules = model.mRulesSerial;
			break;
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
