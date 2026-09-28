// =============================================================================
//  HUD : dessin des écrans titre, de run et de fin, à partir du modèle.
// =============================================================================
//
//  Portée « ui » : ne fait que lire Sinwave_HudModel. Aucun calcul de jeu ici.

class Sinwave_Hud ui
{
	private Sinwave_Canvas mCanvas;

	void Draw(Sinwave_HudModel m)
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
			DrawBanner(m);
			break;
		case Sinwave_HudModel.SCREEN_PAUSE:
		case Sinwave_HudModel.SCREEN_UPGRADE:
			DrawRun(m);		// le menu s'affiche par-dessus
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

		c.Text(BigFont, Font.CR_RED, center, 60, "SINWAVE", 3.0, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GOLD, center, 125, "Les sept cercles du péché", 1.5, Sinwave_Canvas.ALIGN_CENTER);

		c.Text(NewSmallFont, Font.CR_WHITE, center, 175, String.Format("Âmes récoltées : %d", m.mSouls), 1.3, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 197, String.Format("Meilleur score : %d     Runs : %d", m.mBestScore, m.mRuns), 1.1, Sinwave_Canvas.ALIGN_CENTER);

		String next = m.mNextUnlockName.Length() > 0
			? String.Format("Prochaine bénédiction : %s (%d âmes)", m.mNextUnlockName, m.mNextUnlockSouls)
			: "Toutes les bénédictions sont obtenues";
		c.Text(NewSmallFont, Font.CR_ORANGE, center, 219, next, 1.1, Sinwave_Canvas.ALIGN_CENTER);

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			c.Text(NewSmallFont, Font.CR_WHITE, center, 290, "Appuie sur UTILISER pour descendre dans le Purgatoire", 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}
		c.Text(NewSmallFont, Font.CR_DARKGRAY, center, 330, "P : pause     1, 2, 3 : choisir une vertu", 1.0, Sinwave_Canvas.ALIGN_CENTER);
	}

	private void DrawRun(Sinwave_HudModel m)
	{
		let c = mCanvas;

		// Barre d'expérience en haut de l'écran.
		double ratio = m.mXpNeeded > 0 ? clamp(double(m.mXp) / m.mXpNeeded, 0.0, 1.0) : 0.0;
		c.Box(0, 0, c.mWidth, 7, Color(20, 20, 40), 0.8);
		c.Box(0, 0, c.mWidth * ratio, 7, Color(80, 170, 255), 0.9);

		c.Text(NewSmallFont, Font.CR_LIGHTBLUE, 8, 12, String.Format("Niveau %d", m.mLevel), 1.4);
		c.Text(NewSmallFont, Font.CR_GRAY, 8, 32, Sinwave_Canvas.FormatTime(m.mRunTics), 1.1);

		c.Text(NewSmallFont, Font.CR_GOLD, c.mWidth - 8, 12, String.Format("Score %d", m.mScore), 1.4, Sinwave_Canvas.ALIGN_RIGHT);
		c.Text(NewSmallFont, Font.CR_GRAY, c.mWidth - 8, 32, String.Format("Victimes %d", m.mKills), 1.1, Sinwave_Canvas.ALIGN_RIGHT);

		double center = c.mWidth / 2;
		if (m.mWaveCount > 0)
		{
			String waveLine = m.mBetweenWaves
				? "Répit..."
				: String.Format("Vague %d/%d   %s", m.mWave + 1, m.mWaveCount, Sinwave_Canvas.FormatTime(m.mWaveTicsLeft));
			c.Text(NewSmallFont, Font.CR_RED, center, 12, waveLine, 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}
	}

	private void DrawBanner(Sinwave_HudModel m)
	{
		if (m.mBannerTics <= 0) return;
		double alpha = min(1.0, m.mBannerTics / 17.0);
		mCanvas.Text(NewSmallFont, Font.CR_GOLD, mCanvas.mWidth / 2, 120, m.mBanner, 2.0, Sinwave_Canvas.ALIGN_CENTER, alpha);
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
		c.Text(BigFont, titleColor, center, 60, title, 2.2, Sinwave_Canvas.ALIGN_CENTER);

		c.Text(NewSmallFont, Font.CR_WHITE, center, 130, String.Format("Score : %d", m.mScore), 1.6, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 160,
			String.Format("Victimes : %d     Niveau : %d     Temps : %s", m.mKills, m.mLevel, Sinwave_Canvas.FormatTime(m.mRunTics)),
			1.2, Sinwave_Canvas.ALIGN_CENTER);

		if (m.mResultReady)
		{
			c.Text(NewSmallFont, Font.CR_ORANGE, center, 200,
				String.Format("+%d âmes   (total : %d)", m.mSoulsEarned, m.mSouls), 1.4, Sinwave_Canvas.ALIGN_CENTER);
			if (m.mNewBest) c.Text(NewSmallFont, Font.CR_GOLD, center, 228, "NOUVEAU RECORD !", 1.4, Sinwave_Canvas.ALIGN_CENTER);
			if (m.mUnlocked.Length() > 0)
			{
				c.Text(NewSmallFont, Font.CR_GREEN, center, 256, "Débloqué : " .. m.mUnlocked, 1.2, Sinwave_Canvas.ALIGN_CENTER);
			}
		}

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			c.Text(NewSmallFont, Font.CR_WHITE, center, 310, "Appuie sur UTILISER pour recommencer", 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}
	}
}
