// =============================================================================
//  Lecture des fichiers de données texte (data/*.txt).
// =============================================================================
//
//  Format :
//
//      # commentaire (jusqu'à la fin de la ligne)
//      [type identifiant]
//      clé = valeur
//
//  Chaque en-tête [type identifiant] ouvre un bloc (Sinwave_DataBlock). Le parseur
//  ne connaît rien du jeu : ce sont les définitions de la couche data qui
//  interprètent les clés. Les erreurs de saisie sont signalées avec le fichier et
//  la ligne dans la console du moteur.

class Sinwave_DataBlock play
{
	String mFile;
	int mLine;
	Name mType;
	Name mId;

	private Array<String> mKeys;
	private Array<String> mValues;

	void Set(String key, String value)
	{
		int index = IndexOf(key);
		if (index >= 0)
		{
			mValues[index] = value;
			return;
		}
		mKeys.Push(key);
		mValues.Push(value);
	}

	bool Has(String key)
	{
		return IndexOf(key) >= 0;
	}

	String GetString(String key, String fallback = "")
	{
		int index = IndexOf(key);
		return index >= 0 ? mValues[index] : fallback;
	}

	int GetInt(String key, int fallback = 0)
	{
		int index = IndexOf(key);
		return index >= 0 ? mValues[index].ToInt(10) : fallback;
	}

	double GetDouble(String key, double fallback = 0)
	{
		int index = IndexOf(key);
		return index >= 0 ? mValues[index].ToDouble() : fallback;
	}

	bool GetBool(String key, bool fallback = false)
	{
		int index = IndexOf(key);
		if (index < 0) return fallback;
		String value = mValues[index].MakeLower();
		return value == "true" || value == "1" || value == "oui" || value == "yes";
	}

	// Découpe une valeur « a, b, c » en liste.
	void GetList(String key, out Array<String> result)
	{
		result.Clear();
		int index = IndexOf(key);
		if (index < 0) return;
		Array<String> parts;
		mValues[index].Split(parts, ",", TOK_SKIPEMPTY);
		for (int i = 0; i < parts.Size(); i++)
		{
			String part = parts[i];
			part.StripLeftRight();
			if (part.Length() > 0) result.Push(part);
		}
	}

	// Message d'erreur de saisie, avec la position du bloc.
	void Warn(String message)
	{
		Console.Printf("\cg[Sinwave] %s, ligne %d, [%s %s] : %s", mFile, mLine, mType, mId, message);
	}

	private int IndexOf(String key)
	{
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (mKeys[i] == key) return i;
		}
		return -1;
	}
}

class Sinwave_DataParser play
{
	// Lit un fichier de l'archive. S'il existe dans plusieurs archives chargées,
	// c'est la dernière qui gagne : un mod peut remplacer un fichier de données.
	// Renvoie false si le fichier est introuvable.
	static bool ParseLump(String path, out Array<Sinwave_DataBlock> blocks)
	{
		int lump = Wads.CheckNumForFullName(path);
		if (lump < 0)
		{
			Console.Printf("\cg[Sinwave] Fichier de données introuvable : %s", path);
			return false;
		}
		ParseText(path, Wads.ReadLump(lump), blocks);
		return true;
	}

	static void ParseText(String fileName, String text, out Array<Sinwave_DataBlock> blocks)
	{
		Array<String> lines;
		text.Split(lines, "\n");
		Sinwave_DataBlock current = null;

		for (int i = 0; i < lines.Size(); i++)
		{
			String line = lines[i];
			int comment = line.IndexOf("#");
			if (comment >= 0) line = line.Left(comment);
			line.StripLeftRight();
			if (line.Length() == 0) continue;

			if (line.Left(1) == "[")
			{
				current = ParseHeader(fileName, i + 1, line);
				if (current != null) blocks.Push(current);
				continue;
			}

			int equals = line.IndexOf("=");
			if (equals < 0 || current == null)
			{
				Console.Printf("\cg[Sinwave] %s, ligne %d : ligne ignorée, « clé = valeur » attendu dans un bloc.", fileName, i + 1);
				continue;
			}
			String key = line.Left(equals);
			String value = line.Mid(equals + 1);
			key.StripLeftRight();
			value.StripLeftRight();
			current.Set(key.MakeLower(), value);
		}
	}

	private static Sinwave_DataBlock ParseHeader(String fileName, int lineNumber, String line)
	{
		int close = line.IndexOf("]");
		Array<String> parts;
		if (close > 0) line.Mid(1, close - 1).Split(parts, " ", TOK_SKIPEMPTY);
		if (parts.Size() != 2)
		{
			Console.Printf("\cg[Sinwave] %s, ligne %d : en-tête invalide, [type identifiant] attendu.", fileName, lineNumber);
			return null;
		}
		let block = new('Sinwave_DataBlock');
		block.mFile = fileName;
		block.mLine = lineNumber;
		block.mType = parts[0].MakeLower();
		block.mId = parts[1].MakeLower();
		return block;
	}
}
