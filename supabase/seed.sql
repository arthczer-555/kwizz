-- =============================================================================
-- Kwizz - Données de départ (seed)
-- =============================================================================
-- À exécuter APRÈS schema.sql. Idempotent (on conflict do nothing / update).
-- Catégories + sous-catégories calquées sur Sources/KwizzCore/Category.swift.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Catégories (13)
-- -----------------------------------------------------------------------------
insert into categories (id, name, color_hex, symbol, sort_order) values
  ('histoire',    'Histoire',           '#ffb000', 'building.columns',   1),
  ('geographie',  'Géographie',         '#38d6ff', 'globe.europe.africa',2),
  ('sciences',    'Sciences',           '#00ff88', 'atom',               3),
  ('sport',       'Sport',              '#ff7a3c', 'sportscourt',        4),
  ('cinema',      'Ciné & Séries',      '#fb7185', 'film',               5),
  ('musique',     'Musique',            '#c084fc', 'music.note',         6),
  ('arts',        'Arts & Littérature', '#f0f0f0', 'paintbrush',         7),
  ('actu',        'Actu & Société',     '#38d6ff', 'newspaper',          8),
  ('nature',      'Nature & Animaux',   '#00ff88', 'leaf',               9),
  ('tech',        'Tech & Jeux',        '#fb7185', 'gamecontroller',    10),
  ('gastronomie', 'Gastronomie',        '#ffb000', 'fork.knife',        11),
  ('pop',         'Pop culture',        '#c084fc', 'star',              12),
  ('mythes',      'Mythes & Religions', '#ff7a3c', 'sparkles',          13)
on conflict (id) do update
  set name = excluded.name, color_hex = excluded.color_hex,
      symbol = excluded.symbol, sort_order = excluded.sort_order;

-- -----------------------------------------------------------------------------
-- 2. Sous-catégories : id = "<categorie>.<index>" (index 0-based, comme l'app)
-- -----------------------------------------------------------------------------
insert into subcategories (id, category_id, name, sort_order)
select c.cat || '.' || (idx - 1), c.cat, n, idx::int
from (values
  ('histoire',    array['Antiquité','Moyen Âge','Époque moderne','Époque contemporaine','Guerres mondiales','Histoire de France']),
  ('geographie',  array['Capitales','Drapeaux','Pays du monde','Fleuves & reliefs','Mers & océans','Géographie de France']),
  ('sciences',    array['Biologie','Physique','Chimie','Astronomie','Corps humain','Mathématiques']),
  ('sport',       array['Football','Tennis','Rugby','Jeux Olympiques','Sports US','Cyclisme','Auto/Moto']),
  ('cinema',      array['Films cultes','Acteurs & actrices','Disney/Pixar','Marvel/DC','Séries TV','Récompenses']),
  ('musique',     array['Variété française','Pop internationale','Rap/Hip-hop','Rock','Classique','Blind test']),
  ('arts',        array['Peinture','Littérature classique','BD & Manga','Poésie','Sculpture & architecture']),
  ('actu',        array['Politique','Économie','Faits de société','Événements récents']),
  ('nature',      array['Faune','Flore','Écologie','Dinosaures','Vie marine']),
  ('tech',        array['Internet & informatique','Jeux vidéo','Inventions','Intelligence artificielle','Marques tech']),
  ('gastronomie', array['Cuisine française','Cuisines du monde','Vins & boissons','Pâtisserie']),
  ('pop',         array['Célébrités','TV & télé-réalité','Mèmes & Internet','Logos & marques']),
  ('mythes',      array['Mythologie grecque & romaine','Mythologies nordique/égyptienne','Religions du monde','Légendes & croyances'])
) as c(cat, names)
cross join lateral unnest(c.names) with ordinality as t(n, idx)
on conflict (id) do update
  set name = excluded.name, sort_order = excluded.sort_order;

-- -----------------------------------------------------------------------------
-- 3. Catalogue avatar (calqué sur AvatarItem.catalog)
-- -----------------------------------------------------------------------------
insert into avatar_items (id, name, slot, rarity, price, unlock_level) values
  ('tete.casquette',    'Casquette',       'tete',     'commun',     80,  null),
  ('tete.bonnet',       'Bonnet',          'tete',     'commun',     120, null),
  ('tete.hautdeforme',  'Haut-de-forme',   'tete',     'rare',       260, null),
  ('tete.couronne',     'Couronne',        'tete',     'legendaire', 0,   20),
  ('cheveux.afro',      'Coupe afro',      'cheveux',  'rare',       220, null),
  ('cheveux.mohawk',    'Mohawk néon',     'cheveux',  'epique',     540, null),
  ('lunettes.rondes',   'Lunettes rondes', 'lunettes', 'commun',     90,  null),
  ('lunettes.neon',     'Lunettes néon',   'lunettes', 'rare',       200, null),
  ('lunettes.masque',   'Masque arcade',   'lunettes', 'epique',     600, null),
  ('haut.pull',         'Pull pixel',      'haut',     'commun',     140, null),
  ('haut.veste',        'Veste arcade',    'haut',     'rare',       350, null),
  ('haut.costume',      'Costume',         'haut',     'epique',     720, null),
  ('fond.uni',          'Fond uni',        'fond',     'commun',     50,  null),
  ('fond.crt',          'Fond CRT',        'fond',     'epique',     500, null),
  ('fond.synthwave',    'Fond synthwave',  'fond',     'epique',     520, null),
  ('cadre.vert',        'Cadre vert',      'cadre',    'rare',       300, null),
  ('cadre.or',          'Cadre or',        'cadre',    'legendaire', 0,   15)
on conflict (id) do update
  set name = excluded.name, slot = excluded.slot, rarity = excluded.rarity,
      price = excluded.price, unlock_level = excluded.unlock_level;

-- -----------------------------------------------------------------------------
-- 4. Questions d'exemple (montre la forme exacte attendue)
--    Le gros import se fait depuis Resources/questions.json (voir README).
-- -----------------------------------------------------------------------------
insert into questions
  (id, category_id, subcategory_id, difficulty, text, answers, correct_index, explanation) values
  ('his1', 'histoire', 'histoire.3', 'facile',
    'En quelle année a eu lieu la prise de la Bastille ?',
    array['1789','1799','1715','1804'], 0,
    'Le 14 juillet 1789, début de la Révolution française.'),
  ('geo1', 'geographie', 'geographie.0', 'facile',
    'Quelle est la capitale de l''Australie ?',
    array['Sydney','Melbourne','Canberra','Perth'], 2,
    'Canberra, pas Sydney.'),
  ('sci1', 'sciences', 'sciences.1', 'normal',
    'Quel est le symbole chimique de l''or ?',
    array['Or','Au','Ag','Go'], 1, null)
on conflict (id) do nothing;
