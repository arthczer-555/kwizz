# Base de données Kwizz (Supabase)

Oui, Supabase est un très bon choix pour Kwizz : c'est du PostgreSQL managé, avec
auth, Row Level Security et une API auto-générée. Ça couvre exactement les besoins
de la phase 2 du PLAN (comptes, questions servies à distance, classements, duels).

## Comment ça s'articule avec l'app

Le MVP reste **hors-ligne** : les questions sont dans `Resources/questions.json`
et la progression dans SwiftData. Supabase n'est pas requis pour jouer.

En **phase 2**, Supabase devient la source de vérité :

| Donnée | MVP (local) | Phase 2 (Supabase) |
|--------|-------------|--------------------|
| Questions / catégories | `questions.json` (bundle) | tables `questions`, `categories` |
| Profil, pièces, XP | SwiftData | table `profiles` (+ sync) |
| Items possédés/équipés | SwiftData | `owned_items`, `equipped_items` |
| Records | SwiftData | `best_scores` |
| Classements | - | vue `leaderboard`, `daily_results` |

Comme le schéma SQL **reflète 1:1 les modèles Swift** de `Sources/KwizzCore`, on
remplace l'implémentation des services (`QuestionService`, etc.) par des appels
Supabase **sans toucher aux écrans** (architecture décrite section 11.2 du PLAN).

## Le schéma des questions (le point sensible)

La table `questions` reprend exactement le modèle `Question` (text[] `answers` +
`correct_index`), donc l'export Supabase -> `questions.json` est direct. L'intégrité
est **verrouillée** pour qu'aucune question cassée ne soit servie :

- `answers` : entre 2 et 6 réponses (CHECK).
- `correct_index` : forcément un index valide de `answers` (CHECK).
- texte non vide, réponses trim, **aucune réponse en double** (trigger).
- la sous-catégorie, si présente, **appartient à la catégorie** (FK composite).
- workflow `status` (draft/review/published/archived) : on ne sert que `published`.

## Mise en place

1. Crée un projet sur [supabase.com](https://supabase.com).
2. Dans le **SQL Editor**, exécute `schema.sql` puis `seed.sql`.
3. Récupère l'URL du projet et la clé `anon` (Settings -> API) pour l'app iOS
   (SDK `supabase-swift`).

## Importer questions.json dans Supabase

`app_questions` est une vue aux mêmes clés camelCase que le JSON. Pour charger les
47 questions existantes, transforme le JSON en INSERT (les ids sont conservés) :

```bash
# Depuis la racine du repo, génère un fichier import.sql
python3 - <<'PY'
import json
rows = json.load(open("Resources/questions.json"))
def esc(s): return s.replace("'", "''")
def arr(a): return "array[" + ",".join("'"+esc(x)+"'" for x in a) + "]"
def val(q):
    sub = "'"+q["subcategoryID"]+"'" if q.get("subcategoryID") else "null"
    exp = "'"+esc(q["explanation"])+"'" if q.get("explanation") else "null"
    return (f"('{q['id']}','{q['categoryID']}',{sub},'{q['difficulty']}',"
            f"'{esc(q['text'])}',{arr(q['answers'])},{q['correctIndex']},{exp})")
sql = ("insert into questions (id,category_id,subcategory_id,difficulty,text,"
       "answers,correct_index,explanation) values\n"
       + ",\n".join(val(q) for q in rows)
       + "\non conflict (id) do nothing;")
open("supabase/import.sql","w").write(sql)
print("supabase/import.sql écrit :", len(rows), "questions")
PY
```

Puis exécute `supabase/import.sql` dans le SQL Editor.

## Exporter Supabase -> questions.json (pour le MVP local)

Dans le SQL Editor :

```sql
select json_agg(row_to_json(a) order by a.id) from app_questions a;
```

Le résultat est directement décodable par `QuestionBank.load`.

## Fichiers

- `schema.sql` - tables, types, contraintes, triggers, RLS, vues.
- `seed.sql` - 13 catégories, sous-catégories, catalogue avatar, 3 questions d'exemple.
- `import.sql` - généré (voir ci-dessus), non versionné par défaut.
