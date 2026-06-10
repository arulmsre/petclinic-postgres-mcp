INSERT INTO visits (id, pet_id, visit_date, description) VALUES (1, 7, '2010-03-04', 'rabies shot') ON CONFLICT DO NOTHING;
INSERT INTO visits (id, pet_id, visit_date, description) VALUES (2, 8, '2011-03-04', 'rabies shot') ON CONFLICT DO NOTHING;
INSERT INTO visits (id, pet_id, visit_date, description) VALUES (3, 8, '2009-06-04', 'neutered')    ON CONFLICT DO NOTHING;
INSERT INTO visits (id, pet_id, visit_date, description) VALUES (4, 7, '2008-09-04', 'spayed')      ON CONFLICT DO NOTHING;

-- Reset sequence
SELECT setval('visits_id_seq', (SELECT MAX(id) FROM visits));
