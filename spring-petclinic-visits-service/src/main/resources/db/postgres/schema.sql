CREATE TABLE IF NOT EXISTS visits (
    id          SERIAL PRIMARY KEY,
    pet_id      INTEGER NOT NULL,
    visit_date  DATE,
    description VARCHAR(8192)
);
