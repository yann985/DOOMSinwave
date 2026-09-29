// =============================================================================
//  HUD : dessin des écrans titre, de run et de fin, à partir du modèle.
// =============================================================================
//
//  Portée « ui » : ne fait que lire Sinwave_HudModel. Aucun calcul de jeu ici.
//  Les menus (pause, vertus, boutique, arènes) se dessinent eux-mêmes par-dessus.

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

		c.Text(NewSmallFont, Font.CR_ORANGE, center, 160, String.Format("Indulgences : %d", m.mIndulgences), 1.4, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 184, String.Format("Meilleur score : %d     Runs : %d", m.mBestScore, m.mRuns), 1.1, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_WHITE, center, 212, "Arène : " .. m.mArenaName, 1.2, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 234, "Difficulté : " .. DifficultyLabel(m), 1.1, Sinwave_Canvas.ALIGN_CENTER);

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			String prompt = m.mArenaNames.Size() > 1 ? "UTILISER : choisir une arène et descendre" : "UTILISER : descendre dans le Purgatoire";
			c.Text(NewSmallFont, Font.CR_WHITE, center, 270, prompt, 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}
		c.Text(NewSmallFont, Font.CR_GOLD, center, 300, "B : boutique des indulgences", 1.2, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_DARKGRAY, center, 335, "En run : P pause     1, 2, 3 choisir une vertu ou un péché", 1.0, Sinwave_Canvas.ALIGN_CENTER);
	}

	private void DrawRun(Sinwave_HudModel m)
	{
		let c = mCanvas;

		// La corruption teinte l'écran de rouge à mesure qu'elle approche du seuil.
		if (m.mCorruption > 0 && m.mCorruptionThreshold > 0)
		{
			double ratio = min(1.0, double(m.mCorruption) / m.mCorruptionThreshold);
			c.Box(0, 0, c.mWidth, Sinwave_Canvas.HEIGHT, Color(120, 0, 0), 0.12 * ratio);
		}

		// Barres d'expérience (bleue) et de corruption (violette) en haut de l'écran.
		double xpRatio = m.mXpNeeded > 0 ? clamp(double(m.mXp) / m.mXpNeeded, 0.0, 1.0) : 0.0;
		c.Box(0, 0, c.mWidth, 6, Color(20, 20, 40), 0.8);
		c.Box(0, 0, c.mWidth * xpRatio, 6, Color(80, 170, 255), 0.9);
		double corruptionRatio = m.mCorruptionThreshold > 0 ? clamp(double(m.mCorruption) / m.mCorruptionThreshold, 0.0, 1.0) : 0.0;
		c.Box(0, 6, c.mWidth, 3, Color(30, 0, 30), 0.8);
		c.Box(0, 6, c.mWidth * corruptionRatio, 3, Color(200, 40, 200), 0.9);

		c.Text(NewSmallFont, Font.CR_LIGHTBLUE, 8, 14, String.Format("Niveau %d", m.mLevel), 1.4);
		c.Text(NewSmallFont, Font.CR_GRAY, 8, 34, Sinwave_Canvas.FormatTime(m.mRunTics), 1.1);
		int corruptionColor = m.mCorruption >= m.mCorruptionThreshold ? Font.CR_RED : Font.CR_PURPLE;
		c.Text(NewSmallFont, corruptionColor, 8, 50, String.Format("Corruption %d/%d", m.mCorruption, m.mCorruptionThreshold), 1.1);
		c.Text(NewSmallFont, Font.CR_DARKGRAY, 8, 66, DifficultyLabel(m), 1.0);

		c.Text(NewSmallFont, Font.CR_GOLD, c.mWidth - 8, 14, String.Format("Score %d", m.mScore), 1.4, Sinwave_Canvas.ALIGN_RIGHT);
		c.Text(NewSmallFont, Font.CR_GRAY, c.mWidth - 8, 34, String.Format("Victimes %d", m.mKills), 1.1, Sinwave_Canvas.ALIGN_RIGHT);

		double center = c.mWidth / 2;
		if (m.mWaveCount > 0)
		{
			String waveLine;
			if (m.mBetweenWaves) waveLine = "Répit...";
			else if (m.mWaveTicsLeft > 0) waveLine = String.Format("Cercle %d/%d : %s   %s", m.mWave + 1, m.mWaveCount, m.mWaveName, Sinwave_Canvas.FormatTime(m.mWaveTicsLeft));
			else waveLine = String.Format("Cercle %d/%d : %s", m.mWave + 1, m.mWaveCount, m.mWaveName);
			c.Text(NewSmallFont, Font.CR_RED, center, 14, waveLine, 1.4, Sinwave_Canvas.ALIGN_CENTER);
			if (!m.mBetweenWaves && m.mCurseDescription.Length() > 0)
			{
				c.Text(NewSmallFont, Font.CR_ORANGE, center, 34, "Malédiction : " .. m.mCurseDescription, 1.0, Sinwave_Canvas.ALIGN_CENTER);
			}
		}

		if (m.mBossActive) DrawBossBar(m);
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

		// Verdict : décidé par la corruption accumulée pendant la run.
		if (m.mDamned) c.Text(NewSmallFont, Font.CR_RED, center, 108, String.Format("Verdict : DAMNATION  (corruption %d/%d)", m.mCorruption, m.mCorruptionThreshold), 1.4, Sinwave_Canvas.ALIGN_CENTER);
		else c.Text(NewSmallFont, Font.CR_GOLD, center, 108, String.Format("Verdict : ABSOLUTION  (corruption %d/%d)", m.mCorruption, m.mCorruptionThreshold), 1.4, Sinwave_Canvas.ALIGN_CENTER);

		c.Text(NewSmallFont, Font.CR_WHITE, center, 145, String.Format("Score : %d", m.mScore), 1.6, Sinwave_Canvas.ALIGN_CENTER);
		c.Text(NewSmallFont, Font.CR_GRAY, center, 175,
			String.Format("Victimes : %d     Niveau : %d     Temps : %s", m.mKills, m.mLevel, Sinwave_Canvas.FormatTime(m.mRunTics)),
			1.2, Sinwave_Canvas.ALIGN_CENTER);

		if (m.mResultReady)
		{
			c.Text(NewSmallFont, Font.CR_ORANGE, center, 212,
				String.Format("+%d indulgences   (total : %d)", m.mEarned, m.mIndulgences), 1.4, Sinwave_Canvas.ALIGN_CENTER);
			if (m.mNewBest) c.Text(NewSmallFont, Font.CR_GOLD, center, 240, "NOUVEAU RECORD !", 1.4, Sinwave_Canvas.ALIGN_CENTER);
		}

		if ((Menu.MenuTime() / 20) % 2 == 0)
		{
			c.Text(NewSmallFont, Font.CR_WHITE, center, 300, "UTILISER : recommencer          B : boutique", 1.3, Sinwave_Canvas.ALIGN_CENTER);
		}
	}
}
