// Outils de dessin partagés par le HUD et les menus.
// Toutes les coordonnées sont exprimées sur un écran virtuel de 400 unités de
// haut ; la largeur suit le format de l'écran (4:3, 16:9...) sans déformation.
class Sinwave_Canvas ui
{
	const HEIGHT = 400.0;

	enum EAlign
	{
		ALIGN_LEFT,
		ALIGN_CENTER,
		ALIGN_RIGHT
	}

	double mWidth;
	private double mScale;

	// À appeler au début de chaque image.
	void Begin()
	{
		mScale = Screen.GetHeight() / HEIGHT;
		mWidth = Screen.GetWidth() / mScale;
	}

	void Text(Font fnt, int textColor, double x, double y, String text, double size = 1.0, int align = ALIGN_LEFT, double alpha = 1.0)
	{
		double textWidth = fnt.StringWidth(text) * size;
		if (align == ALIGN_CENTER) x -= textWidth / 2;
		else if (align == ALIGN_RIGHT) x -= textWidth;
		Screen.DrawText(fnt, textColor, x / size, y / size, text,
			DTA_VirtualWidthF, mWidth / size, DTA_VirtualHeightF, HEIGHT / size, DTA_Alpha, alpha);
	}

	void Box(double x, double y, double w, double h, Color fill, double alpha)
	{
		Screen.Dim(fill, alpha, int(x * mScale), int(y * mScale), int(w * mScale), int(h * mScale));
	}

	double TextHeight(Font fnt, double size = 1.0)
	{
		return fnt.GetHeight() * size;
	}

	static String FormatTime(int tics)
	{
		int seconds = tics / TICRATE;
		return String.Format("%d:%02d", seconds / 60, seconds % 60);
	}
}
