// Accès au monde du moteur partagé par le gameplay.
class Sinwave_World play
{
	// Le joueur (Sinwave est un jeu solo : le premier joueur présent).
	static PlayerPawn Player()
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playeringame[i] && players[i].mo != null) return players[i].mo;
		}
		return null;
	}
}
