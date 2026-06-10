INSERT INTO vets (id, first_name, last_name) VALUES (1, 'James',  'Carter')  ON CONFLICT DO NOTHING;
INSERT INTO vets (id, first_name, last_name) VALUES (2, 'Helen',  'Leary')   ON CONFLICT DO NOTHING;
INSERT INTO vets (id, first_name, last_name) VALUES (3, 'Linda',  'Douglas') ON CONFLICT DO NOTHING;
INSERT INTO vets (id, first_name, last_name) VALUES (4, 'Rafael', 'Ortega')  ON CONFLICT DO NOTHING;
INSERT INTO vets (id, first_name, last_name) VALUES (5, 'Henry',  'Stevens') ON CONFLICT DO NOTHING;
INSERT INTO vets (id, first_name, last_name) VALUES (6, 'Sharon', 'Jenkins') ON CONFLICT DO NOTHING;

INSERT INTO specialties (id, name) VALUES (1, 'radiology') ON CONFLICT DO NOTHING;
INSERT INTO specialties (id, name) VALUES (2, 'surgery')   ON CONFLICT DO NOTHING;
INSERT INTO specialties (id, name) VALUES (3, 'dentistry') ON CONFLICT DO NOTHING;

INSERT INTO vet_specialties (vet_id, specialty_id) VALUES (2, 1) ON CONFLICT DO NOTHING;
INSERT INTO vet_specialties (vet_id, specialty_id) VALUES (3, 2) ON CONFLICT DO NOTHING;
INSERT INTO vet_specialties (vet_id, specialty_id) VALUES (3, 3) ON CONFLICT DO NOTHING;
INSERT INTO vet_specialties (vet_id, specialty_id) VALUES (4, 2) ON CONFLICT DO NOTHING;
INSERT INTO vet_specialties (vet_id, specialty_id) VALUES (5, 1) ON CONFLICT DO NOTHING;

-- Reset sequences
SELECT setval('vets_id_seq',        (SELECT MAX(id) FROM vets));
SELECT setval('specialties_id_seq', (SELECT MAX(id) FROM specialties));
