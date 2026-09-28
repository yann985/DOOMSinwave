// =============================================================================
//  Bus d'événements (pattern Observer).
// =============================================================================

// Un abonnement : « tel abonné veut recevoir tel type d'événement ».
class Sinwave_Subscription play
{
	Sinwave_Listener mListener;
	class<Sinwave_Event> mType;	// null = tous les événements
}

// Les systèmes publient et s'abonnent ici au lieu de se référencer entre eux.
// Exemple : la mort d'un ennemi est publiée une seule fois, puis reçue séparément
// par le score, l'XP et l'interface, qui ne se connaissent pas.
//
// La diffusion est synchrone : Publish() appelle chaque abonné concerné, dans
// l'ordre d'abonnement, avant de rendre la main. Un abonné peut lui-même publier
// (publication imbriquée) ; les désabonnements pendant une diffusion sont différés.
class Sinwave_EventBus : Sinwave_Service
{
	private Array<Sinwave_Subscription> mSubscriptions;
	private int mDepth;			// nombre de diffusions en cours (imbrication)
	private bool mNeedsCleanup;

	static Sinwave_EventBus From(Sinwave_Services services)
	{
		return Sinwave_EventBus(services.Get('EventBus'));
	}

	// Abonne `listener` aux événements de la classe `type` ET de ses sous-classes.
	// Sans type, l'abonné reçoit tous les événements (utile pour le journal).
	void Subscribe(Sinwave_Listener listener, class<Sinwave_Event> type = null)
	{
		if (listener == null) return;
		let sub = new('Sinwave_Subscription');
		sub.mListener = listener;
		sub.mType = type;
		mSubscriptions.Push(sub);
	}

	// Retire tous les abonnements d'un abonné.
	void Unsubscribe(Sinwave_Listener listener)
	{
		for (int i = 0; i < mSubscriptions.Size(); i++)
		{
			if (mSubscriptions[i].mListener == listener)
			{
				mSubscriptions[i].mListener = null;
				mNeedsCleanup = true;
			}
		}
		Cleanup();
	}

	void Publish(Sinwave_Event e)
	{
		if (e == null) return;
		mDepth++;
		// Nombre figé : un abonné ajouté pendant la diffusion ne reçoit pas cet événement.
		int count = mSubscriptions.Size();
		for (int i = 0; i < count; i++)
		{
			let sub = mSubscriptions[i];
			if (sub.mListener != null && Matches(e, sub.mType))
			{
				sub.mListener.OnEvent(e);
			}
		}
		mDepth--;
		Cleanup();
	}

	int SubscriptionCount()
	{
		return mSubscriptions.Size();
	}

	// Vrai si l'événement est de la classe demandée ou d'une de ses sous-classes.
	private static bool Matches(Sinwave_Event e, class<Sinwave_Event> type)
	{
		if (type == null) return true;
		for (class<Object> cls = e.GetClass(); cls != null; cls = cls.GetParentClass())
		{
			if (cls == type) return true;
		}
		return false;
	}

	private void Cleanup()
	{
		if (mDepth > 0 || !mNeedsCleanup) return;
		for (int i = mSubscriptions.Size() - 1; i >= 0; i--)
		{
			if (mSubscriptions[i].mListener == null) mSubscriptions.Delete(i);
		}
		mNeedsCleanup = false;
	}
}
