// =============================================================================
//  Menus de choix : pause et amélioration.
// =============================================================================
//
//  Un menu ouvert met le moteur en pause. L'interface n'a pas le droit de
//  modifier le jeu : elle envoie une commande réseau (SendNetworkEvent) que
//  Sinwave_Game traduit en événement du bus, côté jeu.

// Base commune : liste d'options, navigation clavier/manette, dessin.
class Sinwave_ChoiceMenu : GenericMenu abstract
{
	protected Sinwave_HudModel mModel;
	protected String mTitle;
	protected String mHint;
	protected Array<String> mLabels;
	protected Array<String> mDetails;
	protected int mSelected;
	private bool mConfirmed;
	private Sinwave_Canvas mCanvas;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		Animated = true;
		DontDim = true;
		mCanvas = new('Sinwave_Canvas');
	}

	// Appelé par Sinwave_UiController juste après l'ouverture.
	void Bind(Sinwave_HudModel model)
	{
		mModel = model;
		mLabels.Clear();
		mDetails.Clear();
		Build();
	}

	// Remplit le titre et les options (mLabels, mDetails).
	virtual void Build() {}
	// Envoie la commande correspondant à l'option choisie.
	virtual void Choose(int index) {}
	// Touche Retour : vrai si le menu doit se fermer.
	virtual bool OnBack() { return false; }
	// Faux dès que l'écran du jeu a changé : le menu se ferme alors de lui-même.
	virtual bool IsRelevant() { return true; }

	protected void AddOption(String label, String detail = "")
	{
		mLabels.Push(label);
		mDetails.Push(detail);
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		int count = mLabels.Size();
		switch (mkey)
		{
		case MKEY_Up:
			if (count > 0) mSelected = (mSelected + count - 1) % count;
			MenuSound("menu/cursor");
			return true;
		case MKEY_Down:
			if (count > 0) mSelected = (mSelected + 1) % count;
			MenuSound("menu/cursor");
			return true;
		case MKEY_Enter:
			Confirm(mSelected);
			return true;
		case MKEY_Back:
			if (OnBack()) Close();
			return true;
		}
		return false;
	}

	// Touches 1, 2, 3... : choix direct.
	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.type == UIEvent.Type_Char)
		{
			int index = ev.KeyChar - 0x31;
			if (index >= 0 && index < mLabels.Size())
			{
				mSelected = index;
				Confirm(index);
				return true;
			}
		}
		return Super.OnUIEvent(ev);
	}

	override void Ticker()
	{
		Super.Ticker();
		if (mModel != null && !IsRelevant()) Close();
	}

	private void Confirm(int index)
	{
		if (mConfirmed || index < 0 || index >= mLabels.Size()) return;
		mConfirmed = true;
		MenuSound("menu/choose");
		Choose(index);
		Close();
	}

	override void Drawer()
	{
		let c = mCanvas;
		c.Begin();
		double center = c.mWidth / 2;
		double rowHeight = 50;
		double panelWidth = 440;
		double panelHeight = 90 + mLabels.Size() * rowHeight;
		double left = center - panelWidth / 2;
		double top = (Sinwave_Canvas.HEIGHT - panelHeight) / 2;

		c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(0, 0, 0), 0.55);
		c.Box(left, top, panelWidth, panelHeight, Color(45, 5, 5), 0.9);
		c.Text(BigFont, Font.CR_GOLD, center, top + 16, mTitle, 1.6, Sinwave_Canvas.ALIGN_CENTER);

		for (int i = 0; i < mLabels.Size(); i++)
		{
			double y = top + 70 + i * rowHeight;
			bool selected = i == mSelected;
			if (selected) c.Box(left + 12, y - 6, panelWidth - 24, rowHeight - 6, Color(170, 30, 30), 0.55);
			c.Text(NewSmallFont, selected ? Font.CR_WHITE : Font.CR_GRAY, left + 28, y, String.Format("%d.  %s", i + 1, mLabels[i]), 1.5);
			if (mDetails[i].Length() > 0) c.Text(NewSmallFont, Font.CR_GOLD, left + 52, y + 22, mDetails[i], 1.1);
		}
		c.Text(NewSmallFont, Font.CR_DARKGRAY, center, top + panelHeight + 10, mHint, 1.0, Sinwave_Canvas.ALIGN_CENTER);
	}
}

class Sinwave_UpgradeMenu : Sinwave_ChoiceMenu
{
	override void Build()
	{
		mTitle = "UNE VERTU S'ÉVEILLE";
		mHint = "Flèches + Entrée, ou touches 1, 2, 3";
		for (int i = 0; i < mModel.mOfferNames.Size(); i++)
		{
			AddOption(mModel.mOfferNames[i], mModel.mOfferDescriptions[i]);
		}
	}

	override void Choose(int index)
	{
		EventHandler.SendNetworkEvent("sinwave_pick", index);
	}

	override bool IsRelevant()
	{
		return mModel.mScreen == Sinwave_HudModel.SCREEN_UPGRADE;
	}
}

class Sinwave_PauseMenu : Sinwave_ChoiceMenu
{
	override void Build()
	{
		mTitle = "PAUSE";
		mHint = "Échap : reprendre";
		AddOption("Reprendre la run");
		AddOption("Abandonner la run", "Les âmes déjà méritées sont conservées");
	}

	override void Choose(int index)
	{
		EventHandler.SendNetworkEvent(index == 0 ? "sinwave_resume" : "sinwave_abandon");
	}

	override bool OnBack()
	{
		EventHandler.SendNetworkEvent("sinwave_resume");
		return true;
	}

	override bool IsRelevant()
	{
		return mModel.mScreen == Sinwave_HudModel.SCREEN_PAUSE;
	}
}
