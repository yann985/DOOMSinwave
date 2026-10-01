// =============================================================================
//  Textes du mode histoire (data/story.txt).
// =============================================================================

// Un texte affiché avant un cercle (clé « story » du cercle) ou à la fin d'une run
// (clés « ending » et « death » de l'arène). Il change selon l'âme du joueur :
//   text     : par défaut ;
//   virtue   : un palier de la vertu atteint ;
//   balance  : aucun palier ;
//   sin      : un palier du péché atteint ;
//   sin_max  : l'âme au bout du péché (la corruption maximale).
// Une variante absente se rabat sur « text ». « \n » commence un nouveau paragraphe.
class Sinwave_StoryDef play
{
	Name mId;
	String mTitle;
	String mText;
	String mVirtue;
	String mBalance;
	String mSin;
	String mSinMax;

	static Sinwave_StoryDef FromBlock(Sinwave_DataBlock block)
	{
		let def = new('Sinwave_StoryDef');
		def.mId = block.mId;
		def.mTitle = block.GetString("title");
		def.mText = Paragraphs(block.GetString("text"));
		def.mVirtue = Paragraphs(block.GetString("virtue"));
		def.mBalance = Paragraphs(block.GetString("balance"));
		def.mSin = Paragraphs(block.GetString("sin"));
		def.mSinMax = Paragraphs(block.GetString("sin_max"));
		if (def.mText.Length() == 0)
		{
			block.Warn("un texte d'histoire doit avoir la clé « text » (utilisée par défaut).");
			return null;
		}
		return def;
	}

	// `side` : côté du palier de l'âme atteint (+1 péché, -1 vertu, 0 aucun) ;
	// `atMax` : la corruption est au maximum.
	String TextFor(int side, bool atMax)
	{
		if (side > 0 && atMax && mSinMax.Length() > 0) return mSinMax;
		if (side > 0 && mSin.Length() > 0) return mSin;
		if (side < 0 && mVirtue.Length() > 0) return mVirtue;
		if (side == 0 && mBalance.Length() > 0) return mBalance;
		return mText;
	}

	private static String Paragraphs(String text)
	{
		text.Replace("\\n", "\n");
		return text;
	}
}
