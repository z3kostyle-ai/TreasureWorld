-- ═══════════════════════════════════════════════════════════════
--  TreasureWorld — traductions de « Visite d'Eaucourt-sur-Somme »
--  Langues : anglais, allemand, néerlandais, espagnol, italien
--  À coller dans : Supabase > SQL Editor > New query > Run
--  (modifiable ensuite dans l'app : Mes chasses > 🌐 Traductions)
-- ═══════════════════════════════════════════════════════════════

-- ─── Nom et histoire de la chasse ────────────────────────────────
insert into public.hunt_translations (hunt_id, lang, name, description) values
('ba0c6680-e938-4208-a73b-b3b5c59d8f1a', 'en', 'Discovering Eaucourt-sur-Somme',
'Hello and welcome, players! You are about to set off on a guided tour of Eaucourt.

⚠️ Safety first: always look left and right before crossing the road, never put yourself in danger, don''t look at your phone while on the road, and use the pedestrian crossings. Please take care as you move around!

Explore the village of Eaucourt-sur-Somme and learn more about our mill, the valley, the pagan cemetery (one of only two in the region) and the ruins of the medieval castle of Jean d''Eaucourt, now being restored by the ARCHE association, which leads the works and organises activities for young and old. Finally, a walk to understand the landscape, with the old flax-retting ponds and the Blue Spring.'),

('ba0c6680-e938-4208-a73b-b3b5c59d8f1a', 'de', 'Entdeckungstour durch Eaucourt-sur-Somme',
'Hallo und herzlich willkommen, liebe Spielerinnen und Spieler! Gleich beginnt eure Führung durch Eaucourt.

⚠️ Sicherheit geht vor: Schaut immer nach links und rechts, bevor ihr die Straße überquert, bringt euch nie in Gefahr, schaut auf der Fahrbahn nicht aufs Handy und benutzt die Zebrastreifen. Passt bitte gut auf euch auf!

Entdeckt das Dorf Eaucourt-sur-Somme und erfahrt mehr über unsere Mühle, das Tal, den heidnischen Friedhof (einer von nur zweien in der Region) und die Ruinen der mittelalterlichen Burg von Jean d''Eaucourt, die heute vom Verein ARCHE restauriert wird – er leitet die Arbeiten und organisiert Veranstaltungen für Groß und Klein. Zum Schluss ein Rundgang, um die Landschaft zu verstehen: mit den alten Flachsröstteichen und der Blauen Quelle.'),

('ba0c6680-e938-4208-a73b-b3b5c59d8f1a', 'nl', 'Ontdekkingstocht door Eaucourt-sur-Somme',
'Hallo en welkom, spelers! Jullie gaan zo op rondleiding door Eaucourt.

⚠️ Veiligheid voorop: kijk altijd naar links en rechts voordat je de weg oversteekt, breng jezelf nooit in gevaar, kijk niet op je telefoon op de rijbaan en gebruik de zebrapaden. Wees voorzichtig onderweg!

Ontdek het dorp Eaucourt-sur-Somme en leer meer over onze molen, de vallei, de heidense begraafplaats (een van de slechts twee in de streek) en de ruïnes van de middeleeuwse burcht van Jean d''Eaucourt, die nu wordt gerestaureerd door de vereniging ARCHE, die de werken leidt en activiteiten organiseert voor jong en oud. Tot slot een wandeling om het landschap te begrijpen, met de oude vlasrootputten en de Blauwe Bron.'),

('ba0c6680-e938-4208-a73b-b3b5c59d8f1a', 'es', 'Descubriendo Eaucourt-sur-Somme',
'¡Hola y bienvenidos, jugadores! Vais a embarcaros en una visita guiada por Eaucourt.

⚠️ La seguridad ante todo: mirad siempre a izquierda y derecha antes de cruzar la carretera, no os pongáis nunca en peligro, no miréis el móvil en la calzada y usad los pasos de peatones. ¡Tened cuidado en vuestros desplazamientos!

Visitad el pueblo de Eaucourt-sur-Somme y descubrid más sobre nuestro molino, el valle, el cementerio pagano (uno de los dos únicos de la región) y las ruinas del castillo medieval de Jean d''Eaucourt, hoy en restauración gracias a la asociación ARCHE, que dirige las obras y organiza actividades para pequeños y mayores. Por último, un paseo para comprender el territorio, con las antiguas balsas de enriado del lino y la Fuente Azul.'),

('ba0c6680-e938-4208-a73b-b3b5c59d8f1a', 'it', 'Alla scoperta di Eaucourt-sur-Somme',
'Ciao e benvenuti, giocatori! State per partire per una visita guidata di Eaucourt.

⚠️ La sicurezza prima di tutto: guardate sempre a destra e a sinistra prima di attraversare la strada, non mettetevi mai in pericolo, non guardate il telefono sulla carreggiata e usate le strisce pedonali. Fate attenzione durante gli spostamenti!

Visitate il villaggio di Eaucourt-sur-Somme e scoprite di più sul nostro mulino, sulla valle, sul cimitero pagano (uno dei soli due della regione) e sulle rovine del castello medievale di Jean d''Eaucourt, oggi in restauro grazie all''associazione ARCHE, che guida i lavori e organizza attività per grandi e piccini. Infine, una passeggiata per capire il territorio, con gli antichi maceratoi del lino e la Sorgente Blu.')
on conflict (hunt_id, lang) do update
  set name = excluded.name, description = excluded.description, updated_at = now();

-- ─── Étapes (texte, indice) ──────────────────────────────────────
insert into public.step_translations (step_id, lang, text, hint) values
-- 1. Mairie
('462d14f5-2b0d-411a-adc3-77466441f42b','en','Eaucourt-sur-Somme town hall',null),
('462d14f5-2b0d-411a-adc3-77466441f42b','de','Rathaus von Eaucourt-sur-Somme',null),
('462d14f5-2b0d-411a-adc3-77466441f42b','nl','Gemeentehuis van Eaucourt-sur-Somme',null),
('462d14f5-2b0d-411a-adc3-77466441f42b','es','Ayuntamiento de Eaucourt-sur-Somme',null),
('462d14f5-2b0d-411a-adc3-77466441f42b','it','Municipio di Eaucourt-sur-Somme',null),
-- 2. Moulin
('bf1a8785-2f49-4243-99d3-83d539bedab1','en','The Eaucourt-sur-Somme mill','The Eaucourt-sur-Somme mill'),
('bf1a8785-2f49-4243-99d3-83d539bedab1','de','Die Mühle von Eaucourt-sur-Somme','Die Mühle von Eaucourt-sur-Somme'),
('bf1a8785-2f49-4243-99d3-83d539bedab1','nl','De molen van Eaucourt-sur-Somme','De molen van Eaucourt-sur-Somme'),
('bf1a8785-2f49-4243-99d3-83d539bedab1','es','El molino de Eaucourt-sur-Somme','El molino de Eaucourt-sur-Somme'),
('bf1a8785-2f49-4243-99d3-83d539bedab1','it','Il mulino di Eaucourt-sur-Somme','Il mulino di Eaucourt-sur-Somme'),
-- 3. Le Saltimbanque
('0f1b5dba-d2a7-4efc-ad2b-308851cae15c','en','"Le Saltimbanque", by restaurateur Sébastien Porquet',null),
('0f1b5dba-d2a7-4efc-ad2b-308851cae15c','de','„Le Saltimbanque“ von Gastronom Sébastien Porquet',null),
('0f1b5dba-d2a7-4efc-ad2b-308851cae15c','nl','"Le Saltimbanque" van restauranthouder Sébastien Porquet',null),
('0f1b5dba-d2a7-4efc-ad2b-308851cae15c','es','«Le Saltimbanque», del restaurador Sébastien Porquet',null),
('0f1b5dba-d2a7-4efc-ad2b-308851cae15c','it','«Le Saltimbanque», del ristoratore Sébastien Porquet',null),
-- 4. Stade
('3b193dad-689c-4515-92e0-81c9ba86406c','en','The Olympique-Eaucourtois football ground',null),
('3b193dad-689c-4515-92e0-81c9ba86406c','de','Das Stadion von Olympique-Eaucourtois',null),
('3b193dad-689c-4515-92e0-81c9ba86406c','nl','Het stadion van Olympique-Eaucourtois',null),
('3b193dad-689c-4515-92e0-81c9ba86406c','es','El estadio del Olympique-Eaucourtois',null),
('3b193dad-689c-4515-92e0-81c9ba86406c','it','Lo stadio dell''Olympique-Eaucourtois',null),
-- 5. Église et cimetière païen
('58c27a0e-8848-442c-8fd6-55af9fdf5aa4','en','Saint-Aubin church and its pagan cemetery, dating from…',null),
('58c27a0e-8848-442c-8fd6-55af9fdf5aa4','de','Die Kirche Saint-Aubin und ihr heidnischer Friedhof aus der Zeit…',null),
('58c27a0e-8848-442c-8fd6-55af9fdf5aa4','nl','De kerk Saint-Aubin en haar heidense begraafplaats uit…',null),
('58c27a0e-8848-442c-8fd6-55af9fdf5aa4','es','La iglesia de Saint-Aubin y su cementerio pagano, que data de…',null),
('58c27a0e-8848-442c-8fd6-55af9fdf5aa4','it','La chiesa di Saint-Aubin e il suo cimitero pagano, risalente al…',null),
-- 6. Château
('0000b47a-8f37-4ae9-bf20-7b590abd1f1a','en','The ruined castle known as "Jean d''Eaucourt''s castle"',null),
('0000b47a-8f37-4ae9-bf20-7b590abd1f1a','de','Die Burgruine, genannt „Burg des Jean d''Eaucourt“',null),
('0000b47a-8f37-4ae9-bf20-7b590abd1f1a','nl','De kasteelruïne, het "kasteel van Jean d''Eaucourt"',null),
('0000b47a-8f37-4ae9-bf20-7b590abd1f1a','es','El castillo en ruinas llamado «de Jean d''Eaucourt»',null),
('0000b47a-8f37-4ae9-bf20-7b590abd1f1a','it','Il castello in rovina detto «di Jean d''Eaucourt»',null),
-- 7. Vieux pont
('47281d88-4dc6-434f-84d3-6d1bcc6fbb5a','en','The old bridge that survived the Second World War. André Mauduit defended it at the risk of his life and his comrades'' lives, thanks to the Polish soldiers on guard who would go on to liberate Abbeville – the bridge narrowly escaped destruction.',null),
('47281d88-4dc6-434f-84d3-6d1bcc6fbb5a','de','Die alte Brücke, die den Zweiten Weltkrieg überstanden hat. André Mauduit verteidigte sie unter Einsatz seines Lebens und des Lebens seiner Kameraden – dank der polnischen Soldaten auf Wache, die später Abbeville befreiten, entging die Brücke nur knapp der Zerstörung.',null),
('47281d88-4dc6-434f-84d3-6d1bcc6fbb5a','nl','De oude brug die de Tweede Wereldoorlog overleefde. André Mauduit verdedigde haar met gevaar voor zijn eigen leven en dat van zijn kameraden, dankzij de Poolse soldaten op wacht die later Abbeville zouden bevrijden – de brug ontsnapte ternauwernood aan vernietiging.',null),
('47281d88-4dc6-434f-84d3-6d1bcc6fbb5a','es','El viejo puente que sobrevivió a la Segunda Guerra Mundial. André Mauduit lo defendió poniendo en peligro su vida y la de sus compañeros, gracias a los soldados polacos de guardia que más tarde liberarían Abbeville: el puente se salvó por muy poco de la destrucción.',null),
('47281d88-4dc6-434f-84d3-6d1bcc6fbb5a','it','Il vecchio ponte sopravvissuto alla Seconda guerra mondiale. André Mauduit lo difese a rischio della propria vita e di quella dei suoi compagni, grazie ai soldati polacchi di guardia che avrebbero poi liberato Abbeville: il ponte scampò per un soffio alla distruzione.',null),
-- 8. Rouissoirs
('7a5f1558-c3e6-42ac-ad79-0ce829a4e6ff','en','The old flax-retting ponds',null),
('7a5f1558-c3e6-42ac-ad79-0ce829a4e6ff','de','Die alten Flachsröstteiche',null),
('7a5f1558-c3e6-42ac-ad79-0ce829a4e6ff','nl','De oude vlasrootputten',null),
('7a5f1558-c3e6-42ac-ad79-0ce829a4e6ff','es','Las antiguas balsas de enriado del lino',null),
('7a5f1558-c3e6-42ac-ad79-0ce829a4e6ff','it','Gli antichi maceratoi del lino',null),
-- 9. Source bleue
('47013eb5-6945-4227-8f5c-af2edb0dfd05','en','The Blue Spring','Legend has it that a cart full of gold lies at the bottom – which would explain the bubbles and the glittering flakes swirling in the water.'),
('47013eb5-6945-4227-8f5c-af2edb0dfd05','de','Die Blaue Quelle','Der Legende nach liegt auf dem Grund ein Karren voller Gold – das würde die Blasen und die im Wasser tanzenden Glitzerflocken erklären.'),
('47013eb5-6945-4227-8f5c-af2edb0dfd05','nl','De Blauwe Bron','Volgens de legende ligt er op de bodem een kar vol goud – dat zou de belletjes en de dwarrelende glinsteringen in het water verklaren.'),
('47013eb5-6945-4227-8f5c-af2edb0dfd05','es','La Fuente Azul','Se dice que en el fondo hay una carreta llena de oro, lo que explicaría las burbujas y los destellos que revolotean en el agua.'),
('47013eb5-6945-4227-8f5c-af2edb0dfd05','it','La Sorgente Blu','Si dice che sul fondo giaccia un carro pieno d''oro: spiegherebbe le bollicine e le pagliuzze scintillanti che volteggiano nell''acqua.')
on conflict (step_id, lang) do update
  set text = excluded.text, hint = excluded.hint;

-- ─── OPTIONNEL : version française corrigée ──────────────────────
-- La description d'origine contient des fautes de frappe (« CHAUSS2E? »,
-- points d'interrogation au lieu de virgules, texte anglais mélangé).
-- Retire les "--" ci-dessous pour la remplacer par cette version relue.
-- update public.hunts set description =
-- 'Bonjour à toutes et à tous ! Vous allez embarquer pour une visite guidée d''Eaucourt.
--
-- ⚠️ Prudence avant tout : regardez toujours à droite et à gauche avant de traverser, ne vous mettez jamais en danger, ne consultez pas votre téléphone sur la chaussée et empruntez les passages piétons. Prenez soin de vous pendant vos déplacements !
--
-- Visitez le village d''Eaucourt-sur-Somme et découvrez-en plus sur notre moulin, la vallée, le cimetière païen (l''un des deux seuls de la région) et les ruines du château médiéval de Jean d''Eaucourt, aujourd''hui en restauration grâce à l''association ARCHE, qui pilote les travaux et organise des animations pour petits et grands. Enfin, une balade pour comprendre le territoire, avec la zone des anciens rouissoirs et la Source bleue.'
-- where id = 'ba0c6680-e938-4208-a73b-b3b5c59d8f1a';
