// =============================================================================
//  Menus : pause, vertus et péchés, boutique, choix de l'arène.
// =============================================================================
//
//  Un menu ouvert met le moteur en pause. L'interface n'a pas le droit de
//  modifier le jeu : elle envoie une commande réseau (SendNetworkEvent) que
//  Sinwave_Game traduit en événement du bus, côté jeu. Les menus lisent le
//  modèle (Sinwave_HudModel) et se reconstruisent quand il change.

// Base commune : liste d'options, navigation clavier/manette, dessin.
class Sinwave_ChoiceMenu : GenericMenu abstract
{
	protected Sinwave_HudModel mModel;
	protected String mTitle;
	protected String mSubtitle;
	protected String mHint;
	protected String mMessage;
	protected int mMessageColor;
	protected Array<String> mLabels;
	protected Array<String> mDetails;
	protected Array<String> mValues;
	protected Array<int> mColors;
	protected int mSelected;
	protected bool mCloseRequested;		// un menu qui reste ouvert peut demander sa fermeture
	private bool mConfirmed;
	private bool mSawKeyDown;
	private bool mIgnoreNextAction;
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
		Rebuild();
	}

	// Les menus du moteur survivent aux changements de carte, pas le modèle :
	// Sinwave_UiController ferme un menu resté lié au modèle d'une ancienne carte.
	bool IsBoundTo(Sinwave_HudModel model)
	{
		return mModel == model;
	}

	// Remplit le titre et les options à partir du modèle.
	virtual void Build() {}
	// Envoie la commande correspondant à l'option choisie.
	virtual void Choose(int index) {}
	// Vrai : le menu reste ouvert après un choix (boutique).
	virtual bool StaysOpen() { return false; }
	// Touche Retour : vrai si le menu doit se fermer.
	virtual bool OnBack() { return false; }
	// Faux dès que l'écran du jeu a changé : le menu se ferme alors de lui-même.
	virtual bool IsRelevant() { return true; }
	// Vrai quand le modèle a changé et que les options doivent être refaites.
	virtual bool NeedsRebuild() { return false; }
	// Faux : une ligne par option, et seule la description de l'option choisie
	// est affichée en bas du cadre (listes longues comme la boutique).
	virtual bool ShowDetailsInline() { return true; }
	// Flèches gauche/droite sur une option réglable : vrai si l'option a été réglée.
	virtual bool Adjust(int index, int delta) { return false; }

	protected void AddOption(String label, String detail, int textColor, String value = "")
	{
		mLabels.Push(label);
		mDetails.Push(detail);
		mColors.Push(textColor);
		mValues.Push(value);
	}

	protected void Rebuild()
	{
		mLabels.Clear();
		mDetails.Clear();
		mColors.Clear();
		mValues.Clear();
		mSubtitle = "";
		Build();
		mSelected = clamp(mSelected, 0, max(0, mLabels.Size() - 1));
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		// Action produite par le relâchement de la touche qui a ouvert ce menu
		// (Utiliser pour les arènes...) : on l'ignore.
		if (mIgnoreNextAction)
		{
			mIgnoreNextAction = false;
			return true;
		}
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
		case MKEY_Left:
		case MKEY_Right:
			if (Adjust(mSelected, mkey == MKEY_Right ? 1 : -1)) MenuSound("menu/change");
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

	// Une touche relâchée sans avoir été enfoncée dans ce menu est celle qui l'a
	// ouvert. Le moteur peut en tirer une action (Retour, Entrée) dans la foulée :
	// elle est ignorée, jusqu'au tic suivant seulement, pour ne jamais avaler une
	// vraie touche du joueur (un Échap juste après avoir ouvert la boutique...).
	private void NoteKey(bool down)
	{
		if (down)
		{
			mSawKeyDown = true;
			mIgnoreNextAction = false;	// une vraie touche du joueur : rien à ignorer
		}
		else if (!mSawKeyDown)
		{
			mIgnoreNextAction = true;
		}
	}

	// Touches brutes : le relâchement arrive ici quand le menu vient de s'ouvrir.
	override bool OnInputEvent(InputEvent ev)
	{
		if (ev.Type == InputEvent.Type_KeyDown || ev.Type == InputEvent.Type_KeyUp) NoteKey(ev.Type == InputEvent.Type_KeyDown);
		return Super.OnInputEvent(ev);
	}

	// Touches 1 à 9 : choix direct.
	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.type == UIEvent.Type_KeyDown || ev.type == UIEvent.Type_KeyUp) NoteKey(ev.type == UIEvent.Type_KeyDown);

		if (ev.type == UIEvent.Type_Char)
		{
			int index = ev.KeyChar - 0x31;
			if (index >= 0 && index < min(9, mLabels.Size()))
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
		mIgnoreNextAction = false;	// l'action due au relâchement arrive dans le même tic
		if (mModel == null) return;
		if (!IsRelevant()) Close();
		else if (NeedsRebuild()) Rebuild();
	}

	private void Confirm(int index)
	{
		if (index < 0 || index >= mLabels.Size()) return;
		if (!StaysOpen())
		{
			if (mConfirmed) return;
			mConfirmed = true;
		}
		MenuSound("menu/choose");
		Choose(index);
		if (!StaysOpen() || mCloseRequested) Close();
	}

	override void Drawer()
	{
		// Le modèle peut avoir changé depuis le dernier tic : on affiche toujours l'état à jour.
		if (mModel != null && NeedsRebuild()) Rebuild();

		let c = mCanvas;
		c.Begin();
		int count = mLabels.Size();
		bool detailsInline = ShowDetailsInline();
		double center = c.mWidth / 2;
		double header = mSubtitle.Length() > 0 ? 72 : 56;
		double rowHeight = detailsInline ? clamp((260 - header) / max(1, count), 30.0, 50.0) : 20;
		double labelSize = detailsInline ? (rowHeight >= 40 ? 1.5 : 1.25) : 1.15;
		double detailSize = detailsInline ? 1.1 : 1.0;
		double footer = detailsInline ? 8 : 34;	// zone de description de l'option choisie
		double panelWidth = min(540.0, c.mWidth - 20);
		double panelHeight = header + count * rowHeight + footer;
		double left = center - panelWidth / 2;
		double top = max(4.0, (330 - panelHeight - 24) / 2);	// au-dessus de la barre d'état

		c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(0, 0, 0), 0.55);
		c.Box(left, top, panelWidth, panelHeight, Color(45, 5, 5), 0.9);
		c.Text(BigFont, Font.CR_GOLD, center, top + 10, mTitle, 1.5, Sinwave_Canvas.ALIGN_CENTER);
		if (mSubtitle.Length() > 0) c.Text(NewSmallFont, Font.CR_ORANGE, center, top + 44, mSubtitle, 1.2, Sinwave_Canvas.ALIGN_CENTER);

		for (int i = 0; i < count; i++)
		{
			double y = top + header + i * rowHeight;
			bool selected = i == mSelected;
			if (selected) c.Box(left + 8, y - 3, panelWidth - 16, rowHeight - 2, Color(170, 30, 30), 0.55);
			int labelColor = selected ? Font.CR_WHITE : mColors[i];
			String number = i < 9 ? String.Format("%d.  ", i + 1) : "     ";
			c.Text(NewSmallFont, labelColor, left + 20, y, number .. mLabels[i], labelSize);
			if (mValues[i].Length() > 0) c.Text(NewSmallFont, labelColor, left + panelWidth - 20, y, mValues[i], labelSize, Sinwave_Canvas.ALIGN_RIGHT);
			if (detailsInline && mDetails[i].Length() > 0) c.Text(NewSmallFont, Font.CR_GOLD, left + 44, y + labelSize * 11, mDetails[i], detailSize);
		}
		if (!detailsInline && mSelected < count && mDetails[mSelected].Length() > 0)
		{
			c.Text(NewSmallFont, Font.CR_GOLD, center, top + header + count * rowHeight + 10, mDetails[mSelected], detailSize, Sinwave_Canvas.ALIGN_CENTER);
		}

		double bottom = top + panelHeight + 8;
		if (mMessage.Length() > 0)
		{
			c.Text(NewSmallFont, mMessageColor, center, bottom, mMessage, 1.2, Sinwave_Canvas.ALIGN_CENTER);
			bottom += 18;
		}
		c.Text(NewSmallFont, Font.CR_DARKGRAY, center, bottom, mHint, 1.0, Sinwave_Canvas.ALIGN_CENTER);
	}
}

// Montée de niveau : deux vertus et un péché.
class Sinwave_UpgradeMenu : Sinwave_ChoiceMenu
{
	override void Build()
	{
		mTitle = "VERTU OU PÉCHÉ ?";
		mSubtitle = String.Format("Corruption : %d/%d  (au seuil : Damnation)", mModel.mCorruption, mModel.mCorruptionThreshold);
		mHint = "Flèches + Entrée, ou touches 1, 2, 3";
		for (int i = 0; i < mModel.mOfferNames.Size(); i++)
		{
			if (mModel.mOfferIsSin[i])
			{
				AddOption("Péché : " .. mModel.mOfferNames[i], mModel.mOfferDescriptions[i], Font.CR_RED,
					String.Format("+%d corruption", mModel.mOfferCorruption[i]));
			}
			else
			{
				String value = mModel.mOfferCorruption[i] < 0 ? String.Format("%d corruption", mModel.mOfferCorruption[i]) : "";
				AddOption(mModel.mOfferNames[i], mModel.mOfferDescriptions[i], Font.CR_GRAY, value);
			}
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
		AddOption("Reprendre la run", "", Font.CR_GRAY);
		AddOption("Abandonner la run", "Les indulgences déjà méritées sont conservées", Font.CR_GRAY);
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

// Boutique des indulgences : armes et améliorations permanentes.
class Sinwave_ShopMenu : Sinwave_ChoiceMenu
{
	private int mRevision;

	override void Build()
	{
		mRevision = mModel.mShopRevision;
		mTitle = "BOUTIQUE DES INDULGENCES";
		mSubtitle = String.Format("Indulgences : %d", mModel.mIndulgences);
		mHint = "Entrée : acheter     Échap : retour";
		mMessage = mModel.mShopMessage;
		mMessageColor = mModel.mShopMessageOk ? Font.CR_GREEN : Font.CR_RED;

		for (int i = 0; i < mModel.mShopNames.Size(); i++)
		{
			int level = mModel.mShopLevels[i];
			int maxLevel = mModel.mShopMaxLevels[i];
			int price = mModel.mShopPrices[i];
			String kind = mModel.mShopIsWeapon[i] ? "Arme" : "Permanent";
			String label = maxLevel > 1 ? String.Format("%s  (%d/%d)", mModel.mShopNames[i], level, maxLevel) : mModel.mShopNames[i];
			String detail = String.Format("%s : %s", kind, mModel.mShopDescriptions[i]);

			if (level >= maxLevel) AddOption(label, detail, Font.CR_GREEN, "acquis");
			else if (price > mModel.mIndulgences) AddOption(label, detail, Font.CR_DARKGRAY, String.Format("%d", price));
			else AddOption(label, detail, Font.CR_GRAY, String.Format("%d", price));
		}
	}

	override bool StaysOpen() { return true; }

	override bool ShowDetailsInline() { return false; }

	override bool NeedsRebuild()
	{
		return mModel.mShopRevision != mRevision;
	}

	override void Choose(int index)
	{
		EventHandler.SendNetworkEvent("sinwave_buy", index);
	}

	override bool OnBack()
	{
		EventHandler.SendNetworkEvent("sinwave_back");
		return true;
	}

	override bool IsRelevant()
	{
		return mModel.mScreen == Sinwave_HudModel.SCREEN_SHOP;
	}
}

// Règles de la descente : difficulté prédéfinie, défi personnalisé, cercle de départ.
// Chaque réglage envoie une commande ; Sinwave_RulesSystem l'applique côté jeu et
// le modèle revient avec les nouvelles valeurs.
class Sinwave_RulesMenu : Sinwave_ChoiceMenu
{
	const OPTION_DESCEND = 6;

	private int mRevision;

	override void Build()
	{
		mRevision = mModel.mRulesRevision;
		mTitle = "RÈGLES DE LA DESCENTE";
		mSubtitle = String.Format("%s   —   récompense x%.2f", mModel.mRulesArenaName, mModel.mRulesReward);
		mHint = "Gauche / Droite : régler     Entrée : descendre     Échap : retour";

		String difficulty = mModel.mRulesPresetName.Length() > 0 ? mModel.mRulesPresetName : "Défi personnalisé";
		AddOption("Difficulté", mModel.mRulesPresetDescription, Font.CR_GRAY, "< " .. difficulty .. " >");
		AddOption("Vie des ennemis", "Points de vie des ennemis et du boss", Font.CR_GRAY, Percent(mModel.mRulesEnemyHealth));
		AddOption("Vitesse des ennemis", "Vitesse de déplacement des ennemis", Font.CR_GRAY, Percent(mModel.mRulesEnemySpeed));
		AddOption("Apparitions", "Rythme d'apparition des ennemis", Font.CR_GRAY, Percent(mModel.mRulesSpawnRate));
		AddOption("Dégâts subis", "Dégâts que tu reçois", Font.CR_GRAY, Percent(mModel.mRulesDamageTaken));
		AddOption("Cercle de départ", "Les cercles passés ne rapportent pas d'indulgences", Font.CR_GRAY,
			String.Format("< %d/%d : %s >", mModel.mRulesStartCircle, mModel.mRulesCircleCount, mModel.mRulesCircleName));
		AddOption("DESCENDRE", "Lancer la run avec ces règles", Font.CR_GOLD);
	}

	override bool StaysOpen() { return true; }
	override bool ShowDetailsInline() { return false; }

	override bool NeedsRebuild()
	{
		return mModel.mRulesRevision != mRevision;
	}

	override bool Adjust(int index, int delta)
	{
		if (index >= OPTION_DESCEND) return false;
		EventHandler.SendNetworkEvent("sinwave_rule", index, delta);
		return true;
	}

	// Entrée sur un réglage le fait avancer ; sur DESCENDRE, lance la run et ferme
	// le menu tout de suite (la run peut commencer sur une autre carte).
	override void Choose(int index)
	{
		if (index == OPTION_DESCEND)
		{
			EventHandler.SendNetworkEvent("sinwave_descend");
			mCloseRequested = true;
		}
		else
		{
			Adjust(index, 1);
		}
	}

	override bool OnBack()
	{
		EventHandler.SendNetworkEvent("sinwave_back");
		return true;
	}

	override bool IsRelevant()
	{
		return mModel.mScreen == Sinwave_HudModel.SCREEN_RULES;
	}

	private static String Percent(double value)
	{
		return String.Format("< %d %% >", int(value * 100 + 0.5));
	}
}

// Choix de l'arène.
class Sinwave_ArenaMenu : Sinwave_ChoiceMenu
{
	override void Build()
	{
		mTitle = "CHOISIS TON ARÈNE";
		mHint = "Entrée : descendre     Échap : retour";
		for (int i = 0; i < mModel.mArenaNames.Size(); i++)
		{
			String value = i == mModel.mCurrentArena ? "ici" : "";
			AddOption(mModel.mArenaNames[i], mModel.mArenaDescriptions[i], Font.CR_GRAY, value);
		}
		mSelected = mModel.mCurrentArena;
	}

	override void Choose(int index)
	{
		EventHandler.SendNetworkEvent("sinwave_arena", index);
	}

	override bool OnBack()
	{
		EventHandler.SendNetworkEvent("sinwave_back");
		return true;
	}

	override bool IsRelevant()
	{
		return mModel.mScreen == Sinwave_HudModel.SCREEN_ARENA_SELECT;
	}
}
