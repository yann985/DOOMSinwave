// Munitions infinies du palier « Damnation » (data/soul.txt, effet infiniteammo).
// Un bonus de munitions infinies du moteur, sans durée utile : il reste tant que
// Sinwave_PlayerSystem ne le retire pas (quand l'âme quitte le palier).
class Sinwave_EternalAmmo : PowerInfiniteAmmo
{
	Default
	{
		Powerup.Duration 0x7FFFFFF;
		+INVENTORY.UNDROPPABLE
	}
}
