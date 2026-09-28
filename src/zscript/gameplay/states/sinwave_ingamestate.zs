// En jeu : les vagues tournent. Cet état ne fait que surveiller les événements
// qui mènent vers un autre état.
class Sinwave_InGameState : Sinwave_GameState
{
	override Name Id() { return 'InGame'; }

	override void HandleEvent(Sinwave_Event e)
	{
		if (e is 'Sinwave_PlayerDiedEvent') EndRun(Sinwave_RunEndedEvent.REASON_DEATH);
		else if (e is 'Sinwave_AllWavesClearedEvent') EndRun(Sinwave_RunEndedEvent.REASON_VICTORY);
		else if (e is 'Sinwave_PauseRequestedEvent') SwitchTo('Sinwave_PauseState');
		else if (e is 'Sinwave_UpgradeOfferedEvent') SwitchTo('Sinwave_UpgradeState');
	}
}
