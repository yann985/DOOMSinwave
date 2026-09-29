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

	// Le texte est placé en pixels réels, comme les cadres (Box). Un écran virtuel
	// (DTA_VirtualWidth) ne convient pas : GZDoom le suppose en 4:3 et, sur un
	// écran large, resserre le texte vers le centre, hors de ses cadres.
	void Text(Font fnt, int textColor, double x, double y, String text, double size = 1.0, int align = ALIGN_LEFT, double alpha = 1.0)
	{
		double textWidth = fnt.StringWidth(text) * size;
		if (align == ALIGN_CENTER) x -= textWidth / 2;
		else if (align == ALIGN_RIGHT) x -= textWidth;
		double scale = size * mScale;
		Screen.DrawText(fnt, textColor, x * mScale, y * mScale, text, DTA_ScaleX, scale, DTA_ScaleY, scale, DTA_Alpha, alpha);
	}

	void Box(double x, double y, double w, double h, Color fill, double alpha)
	{
		Screen.Dim(fill, alpha, int(x * mScale), int(y * mScale), int(w * mScale), int(h * mScale));
	}

	double TextHeight(Font fnt, double size = 1.0)
	{
		return fnt.GetHeight() * size;
	}

	// Position de la souris (pixels de l'écran) dans les coordonnées du canvas.
	static Vector2 FromScreen(double x, double y)
	{
		double scale = Screen.GetHeight() / HEIGHT;
		return (x / scale, y / scale);
	}

	static bool Inside(Vector2 p, double x, double y, double w, double h)
	{
		return p.x >= x && p.x < x + w && p.y >= y && p.y < y + h;
	}

	static String FormatTime(int tics)
	{
		int seconds = tics / TICRATE;
		return String.Format("%d:%02d", seconds / 60, seconds % 60);
	}
}
