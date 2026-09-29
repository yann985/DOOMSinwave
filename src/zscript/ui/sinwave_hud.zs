// =============================================================================
//  HUD : dessin des écrans titre, de run et de fin, à partir du modèle.
// =============================================================================
//
//  Portée « ui » : ne fait que lire Sinwave_HudModel. Aucun calcul de jeu ici.
//  Les menus (pause, vertus, boutique, arènes) se dessinent eux-mêmes par-dessus.

class Sinwave_Hud ui
{
	const CORNER_WIDTH = 95.0;	// place prise par les colonnes des coins (temps, victimes)

	// Indicateur des attaques venues de l'angle mort (unités du canvas, degrés).
	const THREAT_RADIUS = 44.0;			// rayon de l'anneau autour du viseur
	const THREAT_THICKNESS = 5.0;
	const THREAT_SPREAD = 16.0;			// demi-largeur de l'arc
	const THREAT_VISIBLE_RATIO = 0.9;	// au-delà de 90 % du demi-champ de vision : hors de vue
	const THREAT_FADE_TICS = 8.0;		// comme Sinwave_HudPresenter.THREAT_FADE_TICS

	private Sinwave_Canvas mCanvas;
	// Une forme par marque : le moteur ne dessine qu'en fin d'image, une forme
	// réutilisée dans la même image mélangerait les marques.
	private Array<Shape2D> mShapes;

	// viewPos, viewAngle : la caméra à cette image (interpolée, fluide même entre deux tics).
	void Draw(Sinwave_HudModel m, Vector3 viewPos, double viewAngle)
	{
		if (mCanvas == null) mCanvas = new('Sinwave_Canvas');
		mCanvas.Begin();

		switch (m.mScreen)
		{
		case Sinwave_HudModel.SCREEN_MENU:
			DrawTitleScreen(m);
			break;
		case Sinwave_HudModel.SCREEN_RUN:
			DrawRun(m);
			DrawThreats(m, viewPos, viewAngle);
			DrawBanner(m);
			break;
		case Sinwave_HudModel.SCREEN_PAUSE:
		case Sinwave_HudModel.SCREEN_UPGRADE:
			DrawRun(m);
			break;
		case Sinwave_HudModel.SCREEN_GAMEOVER:
			DrawResult(m);
			break;
		}
	}

	private void DrawTitleScreen(Sinwave_HudModel m)
	{
		let c = mCanvas;
		double center = c.mWidth / 2;
		c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(10, 0, 0), 0.6);

		c.Text(BigFont, Font.CR_RED, center, 50, "SINWAVE", 3.0, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GOLD, center, 115, "Les sept cercles du péché", 1.5, Sinwave_Canvas.ALIGN_CENTER);

		c.Text(NewSmallFont, Font.CR_ORANGE, center, 160, String.Format("Indulgences : %d     Jugement : %d (%s)", m.mIndulgences, m.mJudgement, m.mJudgementTierName), 1.4, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 184, String.Format("Meilleur score : %d     Runs : %d", m.mBestScore, m.mRuns), 1.1, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_WHITE, center, 212, "Arène : " .. m.mArenaName, 1.2, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 234, "Difficulté : " .. DifficultyLabel(m), 1.1, Sinwave_Canvas.ALIGN_CENTER);

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			String prompt = m.mArenaNames.Size() > 1 ? "UTILISER (E / A) : choisir une arène et descendre" : "UTILISER (E / A) : descendre dans le Purgatoire";
			c.Text(NewSmallFont, Font.CR_WHITE, center, 270, prompt, 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}
		c.Text(NewSmallFont, Font.CR_GOLD, center, 300, "B : boutique des indulgences", 1.2, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_DARKGRAY, center, 335, "En run : P ou Start pause     Menus : clavier, souris ou manette", 1.0, Sinwave_Canvas.ALIGN_CENTER);
	}

	private void DrawRun(Sinwave_HudModel m)
	{
		let c = mCanvas;

		// L'âme teinte l'écran : de rouge vers le péché, d'une lueur dorée vers la vertu.
		double sinRatio = m.mSoulMax > m.mSoulBalance ? double(m.mCorruption - m.mSoulBalance) / (m.mSoulMax - m.mSoulBalance) : 0.0;
		double virtueRatio = m.mSoulBalance > m.mSoulMin ? double(m.mSoulBalance - m.mCorruption) / (m.mSoulBalance - m.mSoulMin) : 0.0;
		if (sinRatio > 0) c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(120, 0, 0), 0.14 * sinRatio);
		else if (virtueRatio > 0) c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(255, 215, 120), 0.06 * virtueRatio);

		// Barre d'expérience (bleue), puis balance de l'âme en haut de l'écran.
		double xpRatio = m.mXpNeeded > 0 ? clamp(double(m.mXp) / m.mXpNeeded, 0.0, 1.0) : 0.0;
		c.Box(0, 0, c.mWidth, 6, Color(20, 20, 40), 0.8);
		c.Box(0, 0, c.mWidth * xpRatio, 6, Color(80, 170, 255), 0.9);
		DrawSoulGauge(m, 6, 4);

		c.Text(NewSmallFont, Font.CR_LIGHTBLUE, 8, 14, String.Format("Niveau %d", m.mLevel), 1.4);
		c.Text(NewSmallFont, Font.CR_GRAY, 8, 34, Sinwave_Canvas.FormatTime(m.mRunTics), 1.1);
		int soulColor = m.mSoulSide > 0 ? (m.mSoulLevel >= 3 ? Font.CR_RED : Font.CR_PURPLE) : (m.mSoulSide < 0 ? Font.CR_GOLD : Font.CR_GRAY);
		c.Text(NewSmallFont, soulColor, 8, 50, String.Format("Corruption %d/%d : %s", m.mCorruption, m.mSoulMax, m.mSoulTierName), 1.1);
		c.Text(NewSmallFont, Font.CR_DARKGRAY, 8, 66, DifficultyLabel(m), 1.0);

		c.Text(NewSmallFont, Font.CR_GOLD, c.mWidth - 8, 14, String.Format("Score %d", m.mScore), 1.4, Sinwave_Canvas.ALIGN_RIGHT);
		c.Text(NewSmallFont, Font.CR_GRAY, c.mWidth - 8, 34, String.Format("Victimes %d", m.mKills), 1.1, Sinwave_Canvas.ALIGN_RIGHT);

		double center = c.mWidth / 2;
		if (m.mCircleCount > 0)
		{
			// Ex. : « Cercle 3/7 : Luxure   vague 2/3   0:05 ».
			String circleLine = String.Format("Cercle %d/%d : %s", m.mCircle + 1, m.mCircleCount, m.mCircleName);
			String waveLine;
			if (m.mBetweenCircles) waveLine = "Répit...";
			else if (m.mBetweenWaves) waveLine = circleLine .. "   répit";
			else if (m.mWaveTicsLeft > 0) waveLine = String.Format("%s   vague %d/%d   %s", circleLine, m.mWave + 1, m.mWaveCount, Sinwave_Canvas.FormatTime(m.mWaveTicsLeft));
			else waveLine = String.Format("%s   vague %d/%d", circleLine, m.mWave + 1, m.mWaveCount);
			c.Text(NewSmallFont, Font.CR_RED, center, 14, waveLine, 1.3, Sinwave_Canvas.ALIGN_CENTER);
			if (!m.mBetweenCircles && m.mCurseDescription.Length() > 0)
			{
				// Sous la ligne du cercle si elle tient entre les colonnes de gauche et de
				// droite (écran large), sinon sous ces colonnes (et sous la barre du boss).
				String curseLine = "Malédiction : " .. m.mCurseDescription;
				bool fits = NewSmallFont.StringWidth(curseLine) * 0.9 < c.mWidth - 2 * CORNER_WIDTH;
				double y = fits ? 36 : (m.mBossActive ? 88 : 80);
				c.Text(NewSmallFont, Font.CR_ORANGE, center, y, curseLine, 0.9, Sinwave_Canvas.ALIGN_CENTER);
			}
		}

		if (m.mBossActive) DrawBossBar(m);
	}

	// Balance de l'âme sur toute la largeur : l'équilibre au milieu, la vertu vers
	// la gauche (or), le péché vers la droite (violet) ; un trait par palier.
	private void DrawSoulGauge(Sinwave_HudModel m, double y, double height)
	{
		let c = mCanvas;
		double span = max(1, m.mSoulMax - m.mSoulMin);
		double xBalance = c.mWidth * (m.mSoulBalance - m.mSoulMin) / span;
		double xSoul = c.mWidth * (m.mCorruption - m.mSoulMin) / span;
		c.Box(0, y, c.mWidth, height, Color(25, 10, 25), 0.8);
		if (xSoul > xBalance) c.Box(xBalance, y, xSoul - xBalance, height, Color(200, 40, 200), 0.95);
		else if (xSoul < xBalance) c.Box(xSoul, y, xBalance - xSoul, height, Color(255, 205, 70), 0.95);
		for (int i = 0; i < m.mSoulMarks.Size(); i++)
		{
			double x = c.mWidth * (m.mSoulMarks[i] - m.mSoulMin) / span;
			c.Box(clamp(x - 0.5, 0, c.mWidth - 1), y, 1, height, Color(255, 255, 255), 0.45);
		}
		c.Box(xBalance - 1, y - 1, 2, height + 2, Color(255, 255, 255), 0.9);
	}

	private static String DifficultyLabel(Sinwave_HudModel m)
	{
		String name = m.mRulesPresetName.Length() > 0 ? m.mRulesPresetName : "Défi personnalisé";
		return String.Format("%s (récompense x%.2f)", name, m.mRulesReward);
	}

	private void DrawBossBar(Sinwave_HudModel m)
	{
		let c = mCanvas;
		double width = min(420.0, c.mWidth - 40);
		double left = (c.mWidth - width) / 2;
		double top = 58;
		c.Box(left - 2, top - 2, width + 4, 14, Color(0, 0, 0), 0.8);
		c.Box(left, top, width * m.mBossHealth, 10, m.mBossEnraged ? Color(255, 60, 0) : Color(170, 0, 0), 0.95);
		c.Text(NewSmallFont, Font.CR_WHITE, c.mWidth / 2, top + 14, m.mBossName, 1.1, Sinwave_Canvas.ALIGN_CENTER);
	}

	// Attaques venues de l'angle mort, comme dans Doom: The Dark Ages : une marque
	// rouge sur un anneau autour du viseur, du côté de l'attaque (en haut : devant,
	// en bas : derrière). Elle suit la source quand le joueur tourne, et disparaît
	// dès que la source entre dans le champ de vision.
	private void DrawThreats(Sinwave_HudModel m, Vector3 viewPos, double viewAngle)
	{
		if (m.mThreatSources.Size() == 0) return;

		// Moitié du champ de vision horizontal. Le FOV de GZDoom vaut pour du 4:3 ;
		// un écran plus large montre davantage sur les côtés.
		double fov = players[consoleplayer].FOV > 0 ? players[consoleplayer].FOV : 90.0;
		double halfFov = atan(tan(fov / 2) * Screen.GetAspectRatio() / (4.0 / 3.0));

		// Centre de la vue 3D (au-dessus de la barre d'état), en pixels.
		int vx, vy, vw, vh;
		[vx, vy, vw, vh] = Screen.GetViewWindow();
		Vector2 center = (vx + vw / 2.0, vy + vh / 2.0);
		double unit = Screen.GetHeight() / Sinwave_Canvas.HEIGHT;
		double pulse = 0.75 + 0.25 * sin(Menu.MenuTime() * 30.0);

		int drawn = 0;
		for (int i = 0; i < m.mThreatSources.Size(); i++)
		{
			let source = m.mThreatSources[i];
			if (source == null) continue;
			Vector2 toSource = source.pos.xy - viewPos.xy;
			double relative = Actor.Normalize180(atan2(toSource.y, toSource.x) - viewAngle);
			if (abs(relative) < halfFov * THREAT_VISIBLE_RATIO) continue;	// déjà à l'écran

			double alpha = pulse * min(1.0, (m.mThreatAge[i] + 1) / 4.0);
			if (m.mThreatFade[i] >= 0) alpha *= m.mThreatFade[i] / THREAT_FADE_TICS;
			if (drawn == mShapes.Size()) mShapes.Push(new('Shape2D'));
			DrawThreatMark(mShapes[drawn++], center, unit, relative, alpha);
		}
	}

	// Un arc rouge et une pointe tournée vers l'extérieur. `relative` : angle de la
	// menace par rapport au regard, en degrés, positif vers la gauche (comme Doom).
	private void DrawThreatMark(Shape2D shape, Vector2 center, double unit, double relative, double alpha)
	{
		shape.Clear();

		// Sur l'écran : 0° en haut, puis dans le sens des aiguilles d'une montre.
		double inner = THREAT_RADIUS * unit;
		double outer = (THREAT_RADIUS + THREAT_THICKNESS) * unit;
		int segments = 6;
		for (int k = 0; k <= segments; k++)
		{
			double a = -relative - THREAT_SPREAD + 2 * THREAT_SPREAD * k / segments;
			Vector2 edge = (sin(a), -cos(a));
			AddVertex(shape, center + edge * inner);
			AddVertex(shape, center + edge * outer);
			if (k > 0)
			{
				int v = 2 * k;
				shape.PushTriangle(v - 2, v - 1, v);
				shape.PushTriangle(v - 1, v + 1, v);
			}
		}

		Vector2 dir = (sin(-relative), -cos(-relative));
		Vector2 side = (-dir.y, dir.x);
		int tip = 2 * (segments + 1);
		AddVertex(shape, center + dir * (outer + 7 * unit));
		AddVertex(shape, center + dir * outer + side * (6 * unit));
		AddVertex(shape, center + dir * outer - side * (6 * unit));
		shape.PushTriangle(tip, tip + 1, tip + 2);

		// DrawShapeFill lit la couleur en bleu, vert, rouge : ceci donne un rouge vif.
		Screen.DrawShapeFill(Color(20, 40, 255), alpha, shape);
	}

	private static void AddVertex(Shape2D shape, Vector2 v)
	{
		shape.PushVertex(v);
		shape.PushCoord((0, 0));
	}

	private void DrawBanner(Sinwave_HudModel m)
	{
		if (m.mBannerTics <= 0) return;
		double alpha = min(1.0, m.mBannerTics / 17.0);
		double center = mCanvas.mWidth / 2;
		mCanvas.Text(NewSmallFont, Font.CR_GOLD, center, 118, m.mBanner, 2.0, Sinwave_Canvas.ALIGN_CENTER, alpha);
		if (m.mBannerDetail.Length() > 0)
		{
			mCanvas.Text(NewSmallFont, Font.CR_WHITE, center, 150, m.mBannerDetail, 1.2, Sinwave_Canvas.ALIGN_CENTER, alpha);
		}
	}

	private void DrawResult(Sinwave_HudModel m)
	{
		let c = mCanvas;
		double center = c.mWidth / 2;
		c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(10, 0, 0), 0.65);

		String title;
		int titleColor;
		switch (m.mEndReason)
		{
		case Sinwave_RunEndedEvent.REASON_VICTORY:	title = "PURGATOIRE VAINCU"; titleColor = Font.CR_GOLD; break;
		case Sinwave_RunEndedEvent.REASON_DEATH:	title = "TU AS SUCCOMBÉ"; titleColor = Font.CR_RED; break;
		default:									title = "RUN ABANDONNÉE"; titleColor = Font.CR_GRAY; break;
		}
		c.Text(BigFont, titleColor, center, 50, title, 2.2, Sinwave_Canvas.ALIGN_CENTER);

		// Verdict : décidé par le côté où penche l'âme à la fin de la run.
		String soul = String.Format("corruption %d/%d : %s", m.mCorruption, m.mSoulMax, m.mSoulTierName);
		switch (m.mVerdict)
		{
		case Sinwave_CorruptionChangedEvent.VERDICT_ABSOLUTION:
			c.Text(NewSmallFont, Font.CR_GOLD, center, 108, "Verdict : ABSOLUTION  (" .. soul .. ")", 1.4, Sinwave_Canvas.ALIGN_CENTER);
			break;
		case Sinwave_CorruptionChangedEvent.VERDICT_DAMNATION:
			c.Text(NewSmallFont, Font.CR_RED, center, 108, "Verdict : DAMNATION  (" .. soul .. ")", 1.4, Sinwave_Canvas.ALIGN_CENTER);
			break;
		default:
			c.Text(NewSmallFont, Font.CR_WHITE, center, 108, "Verdict : PURGATOIRE  (" .. soul .. ")", 1.4, Sinwave_Canvas.ALIGN_CENTER);
			break;
		}

		c.Text(NewSmallFont, Font.CR_WHITE, center, 145, String.Format("Score : %d", m.mScore), 1.6, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 175,
			String.Format("Victimes : %d     Niveau : %d     Temps : %s", m.mKills, m.mLevel, Sinwave_Canvas.FormatTime(m.mRunTics)),
			1.2, Sinwave_Canvas.ALIGN_CENTER);

		if (m.mResultReady)
		{
			c.Text(NewSmallFont, Font.CR_ORANGE, center, 212,
				String.Format("+%d indulgences   (total : %d)", m.mEarned, m.mIndulgences), 1.4, Sinwave_Canvas.ALIGN_CENTER);
			if (m.mNewBest) c.Text(NewSmallFont, Font.CR_GOLD, center, 240, "NOUVEAU RECORD !", 1.4, Sinwave_Canvas.ALIGN_CENTER);
			// Le Jugement de l'âme a bougé : la boutique n'ouvre plus les mêmes rayons.
			int shift = m.mJudgement - m.mJudgementBefore;
			int judgementColor = shift > 0 ? Font.CR_PURPLE : (shift < 0 ? Font.CR_GOLD : Font.CR_GRAY);
			c.Text(NewSmallFont, judgementColor, center, 264,
				String.Format("Jugement : %d -> %d  (%s)", m.mJudgementBefore, m.mJudgement, m.mJudgementTierName), 1.2, Sinwave_Canvas.ALIGN_CENTER);
		}

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			c.Text(NewSmallFont, Font.CR_WHITE, center, 300, "UTILISER (E / A) : recommencer          B : boutique", 1.3, Sinwave_Canvas.ALIGN_CENTER);
		}
	}
}
