CREATE TABLE IF NOT EXISTS vets (
    id         SERIAL PRIMARY KEY,
    first_name VARCHAR(30),
    last_name  VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS specialties (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS vet_specialties (
    vet_id       INTEGER NOT NULL REFERENCES vets(id),
    specialty_id INTEGER NOT NULL REFERENCES specialties(id),
    PRIMARY KEY (vet_id, specialty_id)
);
