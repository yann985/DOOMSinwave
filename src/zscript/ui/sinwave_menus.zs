// =============================================================================
//  Menus : pause, vertus et péchés, boutique, choix de l'arène.
// =============================================================================
//
//  Un menu ouvert met le moteur en pause. L'interface n'a pas le droit de
//  modifier le jeu : elle envoie une commande réseau (SendNetworkEvent) que
//  Sinwave_Game traduit en événement du bus, côté jeu. Les menus lisent le
//  modèle (Sinwave_HudModel) et se reconstruisent quand il change.

// Base commune : liste d'options, navigation au clavier, à la souris et à la
// manette, dessin.
//   Clavier : flèches, Entrée, Échap, touches 1 à 9.
//   Souris  : survol pour sélectionner, clic pour choisir, molette pour défiler,
//             clic droit ou bouton « Retour » pour revenir, clic sur < > pour régler.
//   Manette : croix ou stick gauche, A pour choisir, B pour revenir (le moteur
//             traduit ces boutons en actions de menu, comme les flèches).
class Sinwave_ChoiceMenu : GenericMenu abstract
{
	const BACK_WIDTH = 110.0;
	const BACK_HEIGHT = 20.0;
	const MAX_PANEL_HEIGHT = 306.0;	// cadre + message + aide tiennent au-dessus de la barre d'état
	const TAB_HEIGHT = 18.0;

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

	// Zones cliquables, mémorisées au dernier dessin (coordonnées du canvas).
	private double mRowLeft, mRowWidth, mRowTop, mRowHeight;
	private Array<double> mValueLeft;
	private Array<double> mValueWidth;
	private double mBackLeft, mBackTop;
	private bool mBackHover;
	// Clic en cours : il n'agit qu'au relâchement, sur la zone où il a commencé.
	// Un bouton déjà enfoncé à l'ouverture (tir en cours) ne choisit donc rien.
	private int mPressedRow;
	private bool mPressedBack;
	private bool mRightPressed;
	// Onglets (boutique) : zones cliquables, et onglet sous le clic en cours.
	private Array<double> mTabLeft;
	private double mTabWidth;
	private double mTabTop;
	private int mPressedTab;

	override void Init(Menu parent)
	{
		Super.Init(parent);
		Animated = true;
		DontDim = true;
		mCanvas = new('Sinwave_Canvas');
		mPressedRow = -1;
		mPressedTab = -1;
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
	// Vrai : l'option se règle aussi en cliquant sur le < ou le > de sa valeur.
	virtual bool IsAdjustable(int index) { return false; }
	// Vrai : un bouton « Retour » cliquable est affiché (le menu gère OnBack).
	virtual bool HasBackButton() { return false; }
	// Onglets sous le titre (aucun par défaut) : nom, couleur, onglet affiché, changement.
	virtual int TabCount() { return 0; }
	virtual String TabLabel(int index) { return ""; }
	virtual int TabColor(int index) { return Font.CR_GRAY; }
	virtual int CurrentTab() { return 0; }
	virtual void SelectTab(int index) {}
	// Bloc propre au menu sous le titre (jauge du Jugement de la boutique) : hauteur, dessin.
	virtual double HeaderExtraHeight() { return 0; }
	virtual void DrawHeaderExtra(Sinwave_Canvas c, double left, double top, double width) {}

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
		switch (mkey)
		{
		case MKEY_Up:
			Move(-1);
			return true;
		case MKEY_Down:
			Move(1);
			return true;
		case MKEY_Left:
		case MKEY_Right:
			AdjustSelected(mkey == MKEY_Right ? 1 : -1);
			return true;
		case MKEY_Enter:
			Confirm(mSelected);
			return true;
		case MKEY_Back:
			GoBack();
			return true;
		}
		return false;
	}

	private void Move(int delta)
	{
		int count = mLabels.Size();
		if (count > 0) mSelected = (mSelected + delta + count) % count;
		MenuSound("menu/cursor");
	}

	private void AdjustSelected(int delta)
	{
		if (Adjust(mSelected, delta)) MenuSound("menu/change");
	}

	protected void GoBack()
	{
		if (OnBack()) Close();
	}

	// Souris. Les coordonnées de l'événement sont en pixels de l'écran.
	private bool OnMouseEvent(UIEvent ev)
	{
		Vector2 p = Sinwave_Canvas.FromScreen(ev.MouseX, ev.MouseY);
		int row = RowAt(p);
		int tab = TabAt(p);
		bool onBack = HasBackButton() && Sinwave_Canvas.Inside(p, mBackLeft, mBackTop, BACK_WIDTH, BACK_HEIGHT);

		switch (ev.type)
		{
		case UIEvent.Type_MouseMove:
			mBackHover = onBack;
			if (row >= 0) mSelected = row;
			return true;
		case UIEvent.Type_LButtonDown:
			mPressedRow = row;
			mPressedBack = onBack;
			mPressedTab = tab;
			if (row >= 0) mSelected = row;
			return true;
		case UIEvent.Type_LButtonUp:
			if (mPressedBack && onBack) GoBack();
			else if (mPressedTab >= 0 && tab == mPressedTab) ChangeTab(tab);
			else if (mPressedRow >= 0 && row == mPressedRow) Click(row, p.x);
			mPressedRow = -1;
			mPressedBack = false;
			mPressedTab = -1;
			return true;
		case UIEvent.Type_RButtonDown:
			mRightPressed = true;
			return true;
		case UIEvent.Type_RButtonUp:
			if (mRightPressed) GoBack();
			mRightPressed = false;
			return true;
		case UIEvent.Type_WheelUp:
			Move(-1);
			return true;
		case UIEvent.Type_WheelDown:
			Move(1);
			return true;
		}
		return false;
	}

	// Clic sur une option : sur la moitié gauche de sa valeur (« < »), la baisse ;
	// sur la moitié droite (« > »), l'augmente ; ailleurs, la choisit.
	private void Click(int row, double x)
	{
		if (IsAdjustable(row) && mValueWidth[row] > 0 && x >= mValueLeft[row] - 6)
		{
			AdjustSelected(x < mValueLeft[row] + mValueWidth[row] / 2 ? -1 : 1);
			return;
		}
		Confirm(row);
	}

	// Onglet sous le point p (-1 : aucun).
	private int TabAt(Vector2 p)
	{
		for (int i = 0; i < mTabLeft.Size(); i++)
		{
			if (Sinwave_Canvas.Inside(p, mTabLeft[i], mTabTop, mTabWidth, TAB_HEIGHT)) return i;
		}
		return -1;
	}

	protected void ChangeTab(int index)
	{
		int count = TabCount();
		if (count <= 0) return;
		index = (index + count) % count;
		if (index == CurrentTab()) return;
		SelectTab(index);
		mSelected = 0;
		Rebuild();
		MenuSound("menu/change");
	}

	// Option sous le point p (-1 : aucune).
	private int RowAt(Vector2 p)
	{
		int count = mLabels.Size();
		if (mRowHeight <= 0 || !Sinwave_Canvas.Inside(p, mRowLeft, mRowTop, mRowWidth, count * mRowHeight)) return -1;
		return clamp(int((p.y - mRowTop) / mRowHeight), 0, count - 1);
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

	// Touches 1 à 9 : choix direct. Souris : voir OnMouseEvent.
	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.type == UIEvent.Type_KeyDown || ev.type == UIEvent.Type_KeyUp) NoteKey(ev.type == UIEvent.Type_KeyDown);
		// La souris est gérée ici en entier : la version du moteur réagit aussi à
		// un bouton Retour invisible dans le coin de l'écran.
		if (ev.type >= UIEvent.Type_FirstMouseEvent && ev.type < UIEvent.Type_LastMouseEvent) return OnMouseEvent(ev);

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

	// Taille du texte, réduite s'il le faut pour tenir dans `width` : les descriptions
	// viennent des données (une arène créée par un joueur peut en avoir une longue).
	private static double FitSize(String text, double size, double width)
	{
		Array<String> lines;
		text.Split(lines, "\n");
		int widest = 0;
		for (int i = 0; i < lines.Size(); i++) widest = max(widest, NewSmallFont.StringWidth(lines[i]));
		double natural = widest * size;
		return natural > width ? size * width / natural : size;
	}

	// Lignes de la plus longue description : le cadre garde la même taille d'une option à l'autre.
	private int DetailLines()
	{
		int most = 1;
		for (int i = 0; i < mDetails.Size(); i++)
		{
			int lines = 1;
			for (int at = mDetails[i].IndexOf("\n"); at >= 0; at = mDetails[i].IndexOf("\n", at + 1)) lines++;
			most = max(most, lines);
		}
		return most;
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
		// Bloc propre au menu, sous le titre (ou le sous-titre).
		double extraHeight = HeaderExtraHeight();
		double extraTop = header - 14;
		if (extraHeight > 0) header = extraTop + extraHeight + 6;
		int tabs = TabCount();
		if (tabs > 0) header += TAB_HEIGHT + 6;
		double rowHeight = detailsInline ? clamp((260 - header) / max(1, count), 30.0, 50.0) : 20;
		double labelSize = detailsInline ? (rowHeight >= 40 ? 1.5 : 1.25) : 1.15;
		double detailSize = detailsInline ? 1.1 : 1.0;
		double footer = detailsInline ? 8 : 18 + 11 * DetailLines();	// zone de description de l'option choisie
		if (HasBackButton()) footer += BACK_HEIGHT + 10;
		double panelWidth = min(540.0, c.mWidth - 20);
		double panelHeight = header + count * rowHeight + footer;
		if (!detailsInline && panelHeight > MAX_PANEL_HEIGHT && count > 0)
		{
			// Longue liste : lignes resserrées, pour rester au-dessus de la barre d'état.
			rowHeight = max(16.0, rowHeight - (panelHeight - MAX_PANEL_HEIGHT) / count);
			panelHeight = header + count * rowHeight + footer;
		}
		double left = center - panelWidth / 2;
		double top = max(4.0, (330 - panelHeight - 24) / 2);	// au-dessus de la barre d'état

		c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(0, 0, 0), 0.55);
		c.Box(left, top, panelWidth, panelHeight, Color(45, 5, 5), 0.9);
		c.Text(BigFont, Font.CR_GOLD, center, top + 10, mTitle, 1.5, Sinwave_Canvas.ALIGN_CENTER);
		if (mSubtitle.Length() > 0) c.Text(NewSmallFont, Font.CR_ORANGE, center, top + 44, mSubtitle, 1.2, Sinwave_Canvas.ALIGN_CENTER);
		if (extraHeight > 0) DrawHeaderExtra(c, left, top + extraTop, panelWidth);

		// Onglets, sur toute la largeur du cadre, juste au-dessus des options.
		mTabLeft.Clear();
		if (tabs > 0)
		{
			mTabTop = top + header - TAB_HEIGHT - 6;
			mTabWidth = (panelWidth - 16) / tabs;
			for (int i = 0; i < tabs; i++)
			{
				double x = left + 8 + i * mTabWidth;
				mTabLeft.Push(x);
				bool current = i == CurrentTab();
				c.Box(x + 1, mTabTop, mTabWidth - 2, TAB_HEIGHT, current ? Color(170, 30, 30) : Color(70, 12, 12), current ? 0.9 : 0.7);
				c.Text(NewSmallFont, current ? Font.CR_WHITE : TabColor(i), x + mTabWidth / 2, mTabTop + 4, TabLabel(i), 1.05, Sinwave_Canvas.ALIGN_CENTER);
			}
		}

		// Le cadre d'une ligne entoure son texte, même quand les lignes sont resserrées.
		double rowPad = clamp((rowHeight - 14) / 2, 1.0, 3.0);
		mRowLeft = left + 8;
		mRowWidth = panelWidth - 16;
		mRowTop = top + header - rowPad;
		mRowHeight = rowHeight;
		mValueLeft.Resize(count);
		mValueWidth.Resize(count);
		for (int i = 0; i < count; i++)
		{
			double y = top + header + i * rowHeight;
			bool selected = i == mSelected;
			if (selected) c.Box(mRowLeft, y - rowPad, mRowWidth, rowHeight - 1, Color(170, 30, 30), 0.55);
			int labelColor = selected ? Font.CR_WHITE : mColors[i];
			String number = i < 9 ? String.Format("%d.  ", i + 1) : "     ";
			c.Text(NewSmallFont, labelColor, left + 20, y, number .. mLabels[i], labelSize);
			mValueWidth[i] = NewSmallFont.StringWidth(mValues[i]) * labelSize;
			mValueLeft[i] = left + panelWidth - 20 - mValueWidth[i];
			if (mValues[i].Length() > 0) c.Text(NewSmallFont, labelColor, left + panelWidth - 20, y, mValues[i], labelSize, Sinwave_Canvas.ALIGN_RIGHT);
			if (detailsInline && mDetails[i].Length() > 0)
			{
				c.Text(NewSmallFont, Font.CR_GOLD, left + 44, y + labelSize * 11, mDetails[i], FitSize(mDetails[i], detailSize, panelWidth - 60));
			}
		}
		if (!detailsInline && mSelected < count && mDetails[mSelected].Length() > 0)
		{
			String detail = mDetails[mSelected];
			c.Text(NewSmallFont, Font.CR_GOLD, center, top + header + count * rowHeight + 8, detail, FitSize(detail, detailSize, panelWidth - 24), Sinwave_Canvas.ALIGN_CENTER);
		}

		if (HasBackButton())
		{
			mBackLeft = center - BACK_WIDTH / 2;
			mBackTop = top + panelHeight - BACK_HEIGHT - 8;
			c.Box(mBackLeft, mBackTop, BACK_WIDTH, BACK_HEIGHT, mBackHover ? Color(170, 30, 30) : Color(90, 15, 15), 0.9);
			c.Text(NewSmallFont, mBackHover ? Font.CR_WHITE : Font.CR_GRAY, center, mBackTop + 4, "Retour", 1.1, Sinwave_Canvas.ALIGN_CENTER);
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

// Montée de niveau : des vertus, des neutres et des péchés, dans l'ordre de la balance.
class Sinwave_UpgradeMenu : Sinwave_ChoiceMenu
{
	override void Build()
	{
		mTitle = "VERTU OU PÉCHÉ ?";
		mSubtitle = String.Format("Corruption : %d/%d  (%s)   équilibre : %d", mModel.mCorruption, mModel.mSoulMax, mModel.mSoulTierName, mModel.mSoulBalance);
		mHint = "Clic, Entrée, A ou touches 1, 2, 3 : choisir";
		for (int i = 0; i < mModel.mOfferNames.Size(); i++)
		{
			String title = mModel.mOfferNames[i];
			String description = mModel.mOfferDescriptions[i];
			int corruption = mModel.mOfferCorruption[i];
			switch (mModel.mOfferKinds[i])
			{
			case Sinwave_UpgradeDef.KIND_SIN:
				AddOption("Péché : " .. title, description, Font.CR_RED, String.Format("+%d corruption", corruption));
				break;
			case Sinwave_UpgradeDef.KIND_NEUTRAL:
				AddOption("Neutre : " .. title, description, Font.CR_GRAY, "âme intacte");
				break;
			default:
				AddOption("Vertu : " .. title, description, Font.CR_GOLD, corruption < 0 ? String.Format("%d corruption", corruption) : "");
				break;
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
		mHint = "Échap, P, B ou Start : reprendre";
		AddOption("Reprendre la run", "", Font.CR_GRAY);
		AddOption("Abandonner la run", "Les indulgences déjà méritées sont conservées", Font.CR_GRAY);
	}

	// La touche qui a mis en pause la retire aussi : P au clavier, Start à la manette.
	override bool OnUIEvent(UIEvent ev)
	{
		bool handled = Super.OnUIEvent(ev);
		if (ev.type == UIEvent.Type_KeyDown && (ev.KeyChar == 0x50 || ev.KeyChar == 0x70))	// P, p
		{
			GoBack();
			return true;
		}
		return handled;
	}

	override bool OnInputEvent(InputEvent ev)
	{
		bool handled = Super.OnInputEvent(ev);
		if (ev.Type == InputEvent.Type_KeyDown && ev.KeyScan == InputEvent.Key_Pad_Start)
		{
			GoBack();
			return true;	// sinon Start ouvrirait aussi le menu du moteur
		}
		return handled;
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
// Quatre rayons en onglets : l'armurerie, toujours ouverte, et trois rayons que
// le Jugement de l'âme ouvre ou ferme (Grâce, Équilibre, Corruption). Sous le
// titre, la jauge du Jugement montre ses paliers et le chemin de la dernière run.
class Sinwave_ShopMenu : Sinwave_ChoiceMenu
{
	const JUDGEMENT_BLOCK_HEIGHT = 37.0;	// ligne des indulgences, jauge, noms des paliers
	const GAUGE_HEIGHT = 8.0;

	private int mRevision;
	private int mTab;				// rayon affiché : Sinwave_ShopItemDef.SIDE_...
	private bool mTabChosen;
	private Array<int> mRowItems;	// article (index dans la boutique) de chaque ligne

	override void Build()
	{
		mRevision = mModel.mShopRevision;
		// À l'ouverture : le rayon vers lequel penche le Jugement.
		if (!mTabChosen)
		{
			mTabChosen = true;
			int tier = mModel.mJudgementTier;
			mTab = tier == 0 ? Sinwave_ShopItemDef.SIDE_NEUTRAL : (tier < 0 ? Sinwave_ShopItemDef.SIDE_GRACE : Sinwave_ShopItemDef.SIDE_CORRUPTION);
		}
		mTitle = "BOUTIQUE DES INDULGENCES";
		mHint = "Gauche / Droite : rayon     Entrée, A ou clic : acheter     Échap, B : retour";
		mMessage = mModel.mShopMessage;
		mMessageColor = mModel.mShopMessageOk ? Font.CR_GREEN : Font.CR_RED;

		mRowItems.Clear();
		for (int i = 0; i < mModel.mShopNames.Size(); i++)
		{
			if (mModel.mShopSides[i] != mTab) continue;
			mRowItems.Push(i);
			int level = mModel.mShopLevels[i];
			int maxLevel = mModel.mShopMaxLevels[i];
			int price = mModel.mShopPrices[i];
			String kind = mModel.mShopIsWeapon[i] ? "Arme" : "Permanent";
			String label = maxLevel > 1 ? String.Format("%s  (%d/%d)", mModel.mShopNames[i], level, maxLevel) : mModel.mShopNames[i];
			String detail = String.Format("%s : %s", kind, mModel.mShopDescriptions[i]);

			if (level >= maxLevel) AddOption(label, detail, Font.CR_GREEN, "acquis");
			else if (mModel.mShopLocked[i]) AddOption(label, detail .. "\nVerrouillé. " .. mModel.mShopRequirements[i], Font.CR_BRICK, "verrouillé");
			else if (price > mModel.mIndulgences) AddOption(label, detail, Font.CR_DARKGRAY, String.Format("%d", price));
			else AddOption(label, detail, Font.CR_GRAY, String.Format("%d", price));
		}
	}

	override bool StaysOpen() { return true; }
	override bool ShowDetailsInline() { return false; }
	override bool HasBackButton() { return true; }

	override int TabCount() { return Sinwave_ShopItemDef.NUM_SIDES; }

	override String TabLabel(int index)
	{
		static const String NAMES[] = { "Armurerie", "Grâce", "Équilibre", "Corruption" };
		return NAMES[clamp(index, 0, 3)];
	}

	override int TabColor(int index)
	{
		static const int COLORS[] = { Font.CR_GRAY, Font.CR_GOLD, Font.CR_WHITE, Font.CR_PURPLE };
		return COLORS[clamp(index, 0, 3)];
	}

	override int CurrentTab() { return mTab; }
	override void SelectTab(int index) { mTab = index; }

	override double HeaderExtraHeight() { return JUDGEMENT_BLOCK_HEIGHT; }

	// Les indulgences à gauche, le Jugement à droite (« 30 -> 20 » : la dernière run
	// l'a fait bouger), puis sa jauge.
	override void DrawHeaderExtra(Sinwave_Canvas c, double left, double top, double width)
	{
		let m = mModel;
		double x = left + 14;
		double w = width - 28;
		c.Text(NewSmallFont, Font.CR_ORANGE, x, top, String.Format("Indulgences : %d", m.mIndulgences), 1.1);
		String value = String.Format("%d", m.mJudgement);
		if (m.mJudgementBefore != m.mJudgement) value = String.Format("%d -> %d", m.mJudgementBefore, m.mJudgement);
		String judgement = String.Format("Jugement : %s (%s)", value, m.mJudgementTierName);
		c.Text(NewSmallFont, SideColor(m.mJudgementTier), x + w, top, judgement, 1.1, Sinwave_Canvas.ALIGN_RIGHT);
		DrawJudgementGauge(c, x, top + 16, w);
	}

	// Comme la balance de l'âme pendant la run : la Grâce en or à gauche, la
	// Corruption en violet à droite, remplie depuis le neutre. Chaque palier a sa
	// zone, de plus en plus marquée vers les extrêmes, et son nom en dessous.
	private void DrawJudgementGauge(Sinwave_Canvas c, double x, double y, double w)
	{
		static const String NUMERALS[] = { "I", "II", "III" };
		let m = mModel;
		double h = GAUGE_HEIGHT;
		Color gold = Color(255, 205, 70);
		Color purple = Color(200, 40, 200);
		Color white = Color(255, 255, 255);
		int graces = m.mJudgementGraceTiers.Size();
		int corruptions = m.mJudgementCorruptionTiers.Size();
		double xNeutral = GaugeX(x, w, m.mJudgementNeutral);
		double xNow = GaugeX(x, w, m.mJudgement);
		double labelY = y + h + 4;

		c.Box(x, y, w, h, Color(25, 10, 25), 0.85);
		for (int i = 0; i < graces; i++)
		{
			int high = m.mJudgementGraceTiers[i];
			int low = i + 1 < graces ? m.mJudgementGraceTiers[i + 1] : m.mJudgementMin;
			ZoneBox(c, x, y, w, low, high, gold, 0.08 + 0.07 * i);
			int labelColor = m.mJudgement <= high ? Font.CR_GOLD : Font.CR_DARKGRAY;
			c.Text(NewSmallFont, labelColor, GaugeX(x, w, (low + high) / 2.0), labelY, NUMERALS[min(i, 2)], 0.8, Sinwave_Canvas.ALIGN_CENTER);
		}
		for (int i = 0; i < corruptions; i++)
		{
			int low = m.mJudgementCorruptionTiers[i];
			int high = i + 1 < corruptions ? m.mJudgementCorruptionTiers[i + 1] : m.mJudgementMax;
			ZoneBox(c, x, y, w, low, high, purple, 0.08 + 0.07 * i);
			int labelColor = m.mJudgement >= low ? Font.CR_PURPLE : Font.CR_DARKGRAY;
			c.Text(NewSmallFont, labelColor, GaugeX(x, w, (low + high) / 2.0), labelY, NUMERALS[min(i, 2)], 0.8, Sinwave_Canvas.ALIGN_CENTER);
		}
		int zone = m.mJudgementNeutralZone;
		ZoneBox(c, x, y, w, m.mJudgementNeutral - zone, m.mJudgementNeutral + zone, white, 0.1);
		bool neutral = abs(m.mJudgement - m.mJudgementNeutral) <= zone;
		c.Text(NewSmallFont, neutral ? Font.CR_WHITE : Font.CR_DARKGRAY, xNeutral, labelY, "Équilibre", 0.8, Sinwave_Canvas.ALIGN_CENTER);

		if (xNow > xNeutral) c.Box(xNeutral, y, xNow - xNeutral, h, purple, 0.9);
		else if (xNow < xNeutral) c.Box(xNow, y, xNeutral - xNow, h, gold, 0.9);
		for (int i = 0; i < graces; i++) c.Box(GaugeX(x, w, m.mJudgementGraceTiers[i]) - 0.5, y, 1, h, white, 0.5);
		for (int i = 0; i < corruptions; i++) c.Box(GaugeX(x, w, m.mJudgementCorruptionTiers[i]) - 0.5, y, 1, h, white, 0.5);
		c.Box(xNeutral - 1, y - 1, 2, h + 2, white, 0.9);

		// La dernière run : d'où le Jugement est parti, et le chemin parcouru, sous la barre.
		if (m.mJudgementBefore != m.mJudgement)
		{
			double xBefore = GaugeX(x, w, m.mJudgementBefore);
			c.Box(xBefore - 1, y, 2, h, Color(150, 150, 150), 0.9);
			c.Box(min(xBefore, xNow), y + h + 1, abs(xNow - xBefore), 2, white, 0.7);
		}
		c.Box(xNow - 1.5, y - 3, 3, h + 6, white, 1.0);

		// Article verrouillé choisi : la zone du Jugement qui l'ouvrirait clignote.
		int item = SelectedItem();
		if (item >= 0 && m.mShopLocked[item] && m.mShopRangeMin[item] <= m.mShopRangeMax[item])
		{
			double x0 = GaugeX(x, w, m.mShopRangeMin[item]);
			double x1 = GaugeX(x, w, m.mShopRangeMax[item]);
			double alpha = 0.55 + 0.35 * sin(Menu.MenuTime() * 12.0);
			c.Box(x0, y - 2, x1 - x0, 1, white, alpha);
			c.Box(x0, y + h + 1, x1 - x0, 1, white, alpha);
			c.Box(x0, y - 2, 1, h + 4, white, alpha);
			c.Box(x1 - 1, y - 2, 1, h + 4, white, alpha);
		}
	}

	private double GaugeX(double x, double w, double judgement)
	{
		double span = max(1, mModel.mJudgementMax - mModel.mJudgementMin);
		return x + w * clamp((judgement - mModel.mJudgementMin) / span, 0.0, 1.0);
	}

	private void ZoneBox(Sinwave_Canvas c, double x, double y, double w, double low, double high, Color fill, double alpha)
	{
		double x0 = GaugeX(x, w, low);
		c.Box(x0, y, GaugeX(x, w, high) - x0, GAUGE_HEIGHT, fill, alpha);
	}

	// Article de la ligne choisie (index dans la boutique), ou -1.
	private int SelectedItem()
	{
		return mSelected >= 0 && mSelected < mRowItems.Size() ? mRowItems[mSelected] : -1;
	}

	private static int SideColor(int tier)
	{
		return tier < 0 ? Font.CR_GOLD : (tier > 0 ? Font.CR_PURPLE : Font.CR_WHITE);
	}

	// Gauche / Droite changent de rayon.
	override bool Adjust(int index, int delta)
	{
		ChangeTab(mTab + delta);
		return false;
	}

	override bool NeedsRebuild()
	{
		return mModel.mShopRevision != mRevision;
	}

	override void Choose(int index)
	{
		if (index >= 0 && index < mRowItems.Size()) EventHandler.SendNetworkEvent("sinwave_buy", mRowItems[index]);
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
		mHint = "Gauche / Droite ou clic sur < > : régler     Échap, B ou clic droit : retour";

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
	override bool HasBackButton() { return true; }
	override bool IsAdjustable(int index) { return index < OPTION_DESCEND; }

	override bool NeedsRebuild()
	{
		return mModel.mRulesRevision != mRevision;
	}

	override bool Adjust(int index, int delta)
	{
		if (!IsAdjustable(index)) return false;
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
		mHint = "Clic, Entrée ou A : choisir     Échap, B ou clic droit : retour";
		for (int i = 0; i < mModel.mArenaNames.Size(); i++)
		{
			String value = i == mModel.mCurrentArena ? "ici" : "";
			AddOption(mModel.mArenaNames[i], mModel.mArenaDescriptions[i], Font.CR_GRAY, value);
		}
		mSelected = mModel.mCurrentArena;
	}

	override bool HasBackButton() { return true; }

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
