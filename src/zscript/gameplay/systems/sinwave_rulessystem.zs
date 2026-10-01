// =============================================================================
//  Règles de la descente : difficulté prédéfinie, défi personnalisé, cercle de départ,
//  défis des péchés.
// =============================================================================
//
//  Écoute : RuleAdjusted, ArenaChosen
//  Publie : RulesChanged
//
//  Seul système qui modifie le service « Rules » (Sinwave_RunRules). Les systèmes
//  qui appliquent les règles (vagues, joueur, méta-progression) le lisent au début
//  de la run. Les réglages sont sauvegardés et retrouvés d'une partie à l'autre.

class Sinwave_RulesSystem : Sinwave_System
{
	private Sinwave_RunRules mRules;
	private Sinwave_GameData mData;
	private Sinwave_SaveService mSave;

	override void Setup()
	{
		mRules = Sinwave_RunRules.From(mServices);
		mData = Sinwave_GameData.From(mServices);
		mSave = Sinwave_SaveService.From(mServices);
		mSave.LoadRules(mRules);
		mRules.mArenaIndex = max(0, mData.mArenaIndex);
		ClampToArena();
		mBus.Subscribe(self, 'Sinwave_RuleAdjustedEvent');
		mBus.Subscribe(self, 'Sinwave_ArenaChosenEvent');
	}

	override void Start()
	{
		mBus.Publish(Sinwave_RulesChangedEvent.Create(mRules));
	}

	override void OnEvent(Sinwave_Event e)
	{
		let chosen = Sinwave_ArenaChosenEvent(e);
		if (chosen != null)
		{
			if (chosen.mIndex < 0 || chosen.mIndex >= mData.mArenas.Size()) return;
			mRules.mArenaIndex = chosen.mIndex;
			ClampToArena();
			mBus.Publish(Sinwave_RulesChangedEvent.Create(mRules));
			return;
		}
		let adjusted = Sinwave_RuleAdjustedEvent(e);
		if (adjusted == null) return;

		switch (adjusted.mField)
		{
		case Sinwave_RuleAdjustedEvent.FIELD_PRESET:
			CyclePreset(adjusted.mDelta);
			break;
		case Sinwave_RuleAdjustedEvent.FIELD_HEALTH:
			mRules.mEnemyHealth = Step(mRules.mEnemyHealth, adjusted.mDelta, Sinwave_RunRules.HEALTH_STEP, Sinwave_RunRules.HEALTH_MIN, Sinwave_RunRules.HEALTH_MAX);
			break;
		case Sinwave_RuleAdjustedEvent.FIELD_SPEED:
			mRules.mEnemySpeed = Step(mRules.mEnemySpeed, adjusted.mDelta, Sinwave_RunRules.SPEED_STEP, Sinwave_RunRules.SPEED_MIN, Sinwave_RunRules.SPEED_MAX);
			break;
		case Sinwave_RuleAdjustedEvent.FIELD_SPAWN:
			mRules.mSpawnRate = Step(mRules.mSpawnRate, adjusted.mDelta, Sinwave_RunRules.SPAWN_STEP, Sinwave_RunRules.SPAWN_MIN, Sinwave_RunRules.SPAWN_MAX);
			break;
		case Sinwave_RuleAdjustedEvent.FIELD_DAMAGE:
			mRules.mDamageTaken = Step(mRules.mDamageTaken, adjusted.mDelta, Sinwave_RunRules.DAMAGE_STEP, Sinwave_RunRules.DAMAGE_MIN, Sinwave_RunRules.DAMAGE_MAX);
			break;
		case Sinwave_RuleAdjustedEvent.FIELD_CIRCLE:
			mRules.mStartCircle += adjusted.mDelta;
			ClampToArena();
			break;
		default:
		{
			// Défi du péché d'un cercle : coché ou décoché, s'il existe pour ce cercle.
			int circle = adjusted.mField - Sinwave_RuleAdjustedEvent.FIELD_CHALLENGE;
			if (circle < 0 || mData.ChallengeOf(mRules.mArenaIndex, circle) == null) return;
			mRules.SetChallenge(circle, !mRules.HasChallenge(circle));
			break;
		}
		}
		if (adjusted.mField >= Sinwave_RuleAdjustedEvent.FIELD_HEALTH && adjusted.mField <= Sinwave_RuleAdjustedEvent.FIELD_DAMAGE)
		{
			RecognizePreset();
		}
		mSave.SaveRules(mRules);
		mBus.Publish(Sinwave_RulesChangedEvent.Create(mRules));
	}

	// Passe à la difficulté prédéfinie suivante (ou précédente).
	private void CyclePreset(int delta)
	{
		int count = mData.mDifficulties.Size();
		if (count == 0) return;
		int current = -1;
		for (int i = 0; i < count; i++)
		{
			if (mData.mDifficulties[i].mId == mRules.mPreset) current = i;
		}
		int next = current < 0 ? 0 : (current + delta + count) % count;
		mRules.ApplyPreset(mData.mDifficulties[next]);
	}

	// Après un réglage à la main : difficulté reconnue, ou défi personnalisé.
	private void RecognizePreset()
	{
		mRules.mPreset = 'None';
		for (int i = 0; i < mData.mDifficulties.Size(); i++)
		{
			if (mRules.Matches(mData.mDifficulties[i])) mRules.mPreset = mData.mDifficulties[i].mId;
		}
	}

	// Le cercle de départ doit exister dans l'arène choisie.
	// Cercle de départ et défis cochés limités aux cercles de l'arène choisie.
	private void ClampToArena()
	{
		int circles = 1;
		if (mRules.mArenaIndex < mData.mArenas.Size()) circles = max(1, mData.mArenas[mRules.mArenaIndex].mCircleNames.Size());
		mRules.mStartCircle = clamp(mRules.mStartCircle, 1, circles);
		for (int i = 0; i < Sinwave_RunRules.MAX_CHALLENGES; i++)
		{
			if (mRules.HasChallenge(i) && mData.ChallengeOf(mRules.mArenaIndex, i) == null) mRules.SetChallenge(i, false);
		}
	}

	private static double Step(double value, int delta, double stepSize, double minimum, double maximum)
	{
		return clamp(value + delta * stepSize, minimum, maximum);
	}
}
