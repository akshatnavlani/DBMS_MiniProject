DROP DATABASE IF EXISTS FilmDB;
CREATE DATABASE FilmDB;
USE FilmDB;

-- =========================
-- Strong Entities
-- =========================

CREATE TABLE DIRECTOR (
    director_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    dob DATE,
    gender ENUM('M','F','Other') DEFAULT 'Other',
    nationality VARCHAR(80)
    -- films_directed (derived)
);

CREATE TABLE PRODUCER (
    producer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    company VARCHAR(120),
    contact VARCHAR(50),
    email VARCHAR(120),
    dob DATE
    -- total_films_produced (derived)
);

CREATE TABLE STUDIO (
    studio_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    location VARCHAR(200),
    established_year INT,
    capacity INT,
    facilities TEXT
);

CREATE TABLE DISTRIBUTOR (
    distributor_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    region VARCHAR(80),
    market_share DECIMAL(5,2) DEFAULT 0.00 -- percentage 0..100
);

CREATE TABLE ACTOR (
    actor_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    dob DATE,
    gender ENUM('M','F','Other') DEFAULT 'Other',
    nationality VARCHAR(80),
    stage_name VARCHAR(120)
    -- age is derived from dob
);

CREATE TABLE CREW (
    crew_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    role VARCHAR(60) NOT NULL,
    dob DATE,
    experience_years INT DEFAULT 0,
    department VARCHAR(60),
    supervisor_id INT NULL,             -- self-recursive FK
    FOREIGN KEY (supervisor_id) REFERENCES CREW(crew_id) ON DELETE SET NULL
);

CREATE TABLE EQUIPMENT (
    equipment_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    type VARCHAR(60),
    cost DECIMAL(12,2) DEFAULT 0,
    purchase_date DATE,
    `condition` VARCHAR(30) DEFAULT 'Good',
    availability ENUM('Available','In Use','Under Maintenance') DEFAULT 'Available'
);

CREATE TABLE SHOOTING_LOCATION (
    location_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    city VARCHAR(80),
    state VARCHAR(80),
    country VARCHAR(80),
    cost_per_day DECIMAL(12,2) DEFAULT 0,
    area VARCHAR(80),
    amenities TEXT
);

CREATE TABLE FILM (
    film_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    release_date DATE,
    budget DECIMAL(15,2) DEFAULT 0,
    duration INT,               -- minutes
    language VARCHAR(80),
    boxoffice_collection DECIMAL(15,2) DEFAULT 0,
    rating DECIMAL(3,1),
    FK_director_id INT NULL,    -- partial participation: a film may be created before director assigned
    -- genre: to model multi-valued we use FILM_GENRES; kept single primary for convenience
    primary_genre VARCHAR(60),
    FOREIGN KEY (FK_director_id) REFERENCES DIRECTOR(director_id) ON DELETE SET NULL
);

-- Basic check constraints
ALTER TABLE FILM ADD CONSTRAINT chk_film_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 10));
ALTER TABLE FILM ADD CONSTRAINT chk_film_duration CHECK (duration IS NULL OR duration > 0);
ALTER TABLE FILM ADD CONSTRAINT chk_film_budget CHECK (budget >= 0);
ALTER TABLE DISTRIBUTOR ADD CONSTRAINT chk_dist_market_share CHECK (market_share >= 0 AND market_share <= 100);
ALTER TABLE EQUIPMENT ADD CONSTRAINT chk_equipment_cost CHECK (cost >= 0);
ALTER TABLE SHOOTING_LOCATION ADD CONSTRAINT chk_location_cost CHECK (cost_per_day >= 0);
ALTER TABLE CREW ADD CONSTRAINT chk_experience_years CHECK (experience_years >= 0);

-- =========================
-- Weak / Multi-valued / 1:1
-- =========================

-- Multi-valued languages for ACTOR
CREATE TABLE ACTOR_LANGUAGE (
    actor_id INT NOT NULL,
    language VARCHAR(80) NOT NULL,
    fluency_level ENUM('Basic','Conversational','Fluent','Native') DEFAULT 'Conversational',
    PRIMARY KEY (actor_id, language),
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- Multi-valued genres for FILM (models array)
CREATE TABLE FILM_GENRE (
    film_id INT NOT NULL,
    genre VARCHAR(60) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (film_id, genre),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- Director specializations (multi-valued)
CREATE TABLE DIRECTOR_SPECIALIZATION (
    director_id INT NOT NULL,
    specialization VARCHAR(80) NOT NULL,
    years_experience INT DEFAULT 0,
    PRIMARY KEY (director_id, specialization),
    FOREIGN KEY (director_id) REFERENCES DIRECTOR(director_id) ON DELETE CASCADE
);

-- 1:1 example: certificate per film
CREATE TABLE FILM_CERTIFICATE (
    certificate_id INT PRIMARY KEY AUTO_INCREMENT,
    film_id INT NOT NULL UNIQUE,
    rating_board VARCHAR(80) NOT NULL,
    certificate_rating VARCHAR(20) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    content_warnings TEXT,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- Scenes are dependent on film (weak in logical sense)
CREATE TABLE SCENE (
    scene_id INT PRIMARY KEY AUTO_INCREMENT,
    film_id INT NOT NULL,
    location VARCHAR(200),
    description TEXT,
    duration INT, -- minutes
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- =========================
-- Relationship / Junction tables
-- =========================

-- ROLE: actor acts in film (acts_in). Many descriptive attributes.
CREATE TABLE ROLE (
    role_id INT PRIMARY KEY AUTO_INCREMENT,
    actor_id INT NOT NULL,
    film_id INT NOT NULL,
    character_name VARCHAR(120),
    screen_time INT,                           -- minutes
    importance ENUM('Lead','Supporting','Cameo') DEFAULT 'Supporting',
    salary DECIMAL(14,2) DEFAULT 0,
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    UNIQUE (actor_id, film_id, character_name)
);

-- PRODUCED_BY: M:N between FILM and PRODUCER with investment attribute
CREATE TABLE PRODUCED_BY (
    film_id INT NOT NULL,
    producer_id INT NOT NULL,
    investment DECIMAL(15,2) DEFAULT 0,
    PRIMARY KEY (film_id, producer_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (producer_id) REFERENCES PRODUCER(producer_id) ON DELETE CASCADE
);

-- DISTRIBUTES: M:N between DISTRIBUTOR and FILM (with attributes)
CREATE TABLE DISTRIBUTES (
    distributor_id INT NOT NULL,
    film_id INT NOT NULL,
    distribution_fee DECIMAL(15,2) DEFAULT 0,
    distribution_date DATE,
    territory VARCHAR(120),
    PRIMARY KEY (distributor_id, film_id),
    FOREIGN KEY (distributor_id) REFERENCES DISTRIBUTOR(distributor_id) ON DELETE CASCADE,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- HOSTS: Studio hosts film (M:N) with rental info
CREATE TABLE HOSTS (
    studio_id INT NOT NULL,
    film_id INT NOT NULL,
    rental_cost DECIMAL(15,2) DEFAULT 0,
    rental_start DATE,
    rental_end DATE,
    PRIMARY KEY (studio_id, film_id),
    FOREIGN KEY (studio_id) REFERENCES STUDIO(studio_id) ON DELETE CASCADE,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- WORKS_ON: Crew works on film (M:N) with start/end dates
CREATE TABLE WORKS_ON (
    crew_id INT NOT NULL,
    film_id INT NOT NULL,
    start_date DATE,
    end_date DATE,
    department VARCHAR(80),
    PRIMARY KEY (crew_id, film_id),
    FOREIGN KEY (crew_id) REFERENCES CREW(crew_id) ON DELETE CASCADE,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- SHOT_AT: Film shots at location (M:N) with shooting dates and cost
CREATE TABLE SHOT_AT (
    film_id INT NOT NULL,
    location_id INT NOT NULL,
    shooting_start DATE,
    shooting_end DATE,
    total_cost DECIMAL(15,2) DEFAULT 0,
    PRIMARY KEY (film_id, location_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES SHOOTING_LOCATION(location_id) ON DELETE CASCADE
);

-- SCENE_FILMING: ternary-ish data: scene x crew x equipment (records which crew used which equipment for which scene)
CREATE TABLE SCENE_FILMING (
    filming_id INT PRIMARY KEY AUTO_INCREMENT,
    film_id INT NOT NULL,
    scene_id INT NOT NULL,
    crew_id INT NOT NULL,
    equipment_id INT NULL,
    filming_date DATE,
    duration_minutes INT,
    notes TEXT,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (scene_id) REFERENCES SCENE(scene_id) ON DELETE CASCADE,
    FOREIGN KEY (crew_id) REFERENCES CREW(crew_id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENT(equipment_id) ON DELETE SET NULL,
    UNIQUE KEY uq_scene_crew_equip (film_id, scene_id, crew_id, equipment_id)
);

-- FILM_CREW_EQUIPMENT: another ternary representation, usage stats across film
CREATE TABLE FILM_CREW_EQUIPMENT (
    film_id INT NOT NULL,
    crew_id INT NOT NULL,
    equipment_id INT NOT NULL,
    days_used INT DEFAULT 0,
    efficiency_rating DECIMAL(3,1) DEFAULT 0.0,
    maintenance_required BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (film_id, crew_id, equipment_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (crew_id) REFERENCES CREW(crew_id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENT(equipment_id) ON DELETE CASCADE
);

-- USAGE: film uses equipment (M:N) with usage start/end (separate from SCENE filming)
CREATE TABLE `USAGE` (
    film_id INT NOT NULL,
    equipment_id INT NOT NULL,
    usage_start DATE,
    usage_end DATE,
    PRIMARY KEY (film_id, equipment_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENT(equipment_id) ON DELETE CASCADE
);

-- SHOT_AT and HOSTS already model ternary aspects (studio hosts film at location etc.)

-- =========================
-- Awards (modeled as weak / dependent)
-- =========================

CREATE TABLE ACTOR_AWARD (
    actor_id INT NOT NULL,
    award_name VARCHAR(200) NOT NULL,
    award_year INT NOT NULL,
    PRIMARY KEY (actor_id, award_name, award_year),
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

CREATE TABLE DIRECTOR_AWARD (
    director_id INT NOT NULL,
    award_name VARCHAR(200) NOT NULL,
    award_year INT NOT NULL,
    PRIMARY KEY (director_id, award_name, award_year),
    FOREIGN KEY (director_id) REFERENCES DIRECTOR(director_id) ON DELETE CASCADE
);

CREATE TABLE CREW_AWARD (
    crew_id INT NOT NULL,
    award_name VARCHAR(200) NOT NULL,
    award_year INT NOT NULL,
    PRIMARY KEY (crew_id, award_name, award_year),
    FOREIGN KEY (crew_id) REFERENCES CREW(crew_id) ON DELETE CASCADE
);

-- =========================
-- Indexes & Views
-- =========================

CREATE INDEX idx_film_director ON FILM(FK_director_id);
CREATE INDEX idx_role_actor ON ROLE(actor_id);
CREATE INDEX idx_role_film ON ROLE(film_id);
CREATE INDEX idx_scene_film ON SCENE(film_id);
CREATE INDEX idx_works_on_film ON WORKS_ON(film_id);
CREATE INDEX idx_shot_at_film ON SHOT_AT(film_id);
CREATE INDEX idx_equipment_avail ON EQUIPMENT(availability);

CREATE VIEW view_film_basic AS
SELECT f.film_id, f.title, f.release_date, f.budget, f.duration, f.language, f.rating, d.name AS director_name
FROM FILM f
LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id;

-- =========================
-- Sample Data
-- =========================

-- DIRECTORS
INSERT INTO DIRECTOR (name, dob, gender, nationality) VALUES
('Christopher Nolan','1970-07-30','M','British'),
('Greta Gerwig','1983-08-04','F','American'),
('Ava DuVernay','1972-08-24','F','American'),
('Denis Villeneuve','1967-10-03','M','Canadian');

-- PRODUCERS
INSERT INTO PRODUCER (name, company, contact, email, dob) VALUES
('Emma Thomas','Syncopy','+1-555-0101','emma@syncopy.example','1971-12-09'),
('Scott Rudin','Rudin Productions','+1-555-0102','scott@rudin.example','1958-07-14'),
('Dede Gardner','Plan B Entertainment','+1-555-0103','dede@planb.example','1967-01-01');

-- STUDIOS
INSERT INTO STUDIO (name, location, established_year, capacity, facilities) VALUES
('Warner Bros. Studios','Burbank, CA',1923,4800,'sound stages, backlot, editing suites'),
('Universal Studios','Universal City, CA',1912,5200,'post-production, VFX, sound'),
('Pinewood Studios','Iver Heath, UK',1936,6000,'stages, backlot, water tank');

-- DISTRIBUTORS
INSERT INTO DISTRIBUTOR (name, region, market_share) VALUES
('Warner Distribution','Worldwide',22.50),
('Universal Pictures','Worldwide',24.30),
('Sony Pictures','North America',12.00);

-- ACTORS
INSERT INTO ACTOR (first_name,last_name,dob,gender,nationality,stage_name) VALUES
('Leonardo','DiCaprio','1974-11-11','M','American','Leo'),
('Emma','Stone','1988-11-06','F','American','Emma Stone'),
('Robert','Downey Jr.','1965-04-04','M','American','RDJ'),
('Tessa','Thompson','1983-10-03','F','American','Tessa');

-- CREW (include self-recursive supervision relationships)
INSERT INTO CREW (name, role, dob, experience_years, department, supervisor_id) VALUES
('Sam Carter','Cinematographer','1982-04-15',15,'Camera',NULL),    -- id 1
('Alex Kim','Gaffer','1985-10-10',12,'Lighting',1),                 -- id 2 supervised by Sam
('Priya Patel','Editor','1990-02-21',8,'Editing',NULL),             -- id 3
('Miguel Sanchez','Sound Designer','1978-06-30',18,'Sound',NULL);   -- id 4

-- EQUIPMENT
INSERT INTO EQUIPMENT (name, type, cost, purchase_date, `condition`, availability) VALUES
('Arri Alexa Mini','Camera',120000,'2018-05-01','Good','Available'), -- id 1
('RED Helium','Camera',90000,'2019-03-10','Good','In Use'),          -- id 2
('Dolly Track Set','Grip',15000,'2017-08-01','Good','Available'),    -- id 3
('Boom Microphone Kit','Sound',4000,'2020-01-15','Good','Available');-- id 4

-- LOCATIONS
INSERT INTO SHOOTING_LOCATION (name, city, state, country, cost_per_day, area, amenities) VALUES
('Old Factory','Detroit','MI','USA',2500,'Large indoor','power, parking, dressing rooms'), -- id 1
('Seaside Cliff','Santa Monica','CA','USA',3500,'Outdoor','permit required, safety crew'), -- id 2
('Central Park','New York','NY','USA',5000,'Large outdoor','public access, permits');       -- id 3

-- FILMS
INSERT INTO FILM (title, release_date, budget, duration, language, boxoffice_collection, rating, primary_genre, FK_director_id) VALUES
('Quantum Dreams','2024-06-01',50000000,130,'English',120000000,8.2,'Sci-Fi',1),  -- director Nolan
('Tiny Stories','2023-11-10',12000000,95,'English',30000000,7.1,'Drama',2),       -- director Gerwig
('Echoes of Home','2025-03-20',15000000,110,'English',0,NULL,'Drama',3),         -- director DuVernay (not yet released)
('Desert Horizon','2024-12-05',80000000,145,'English',400000000,9.0,'Action',4);  -- Villeneuve

-- FILM_GENRE (multi-valued)
INSERT INTO FILM_GENRE (film_id, genre, is_primary) VALUES
(1,'Sci-Fi',TRUE),(1,'Adventure',FALSE),
(2,'Drama',TRUE),(2,'Comedy',FALSE),
(3,'Drama',TRUE),(3,'Family',FALSE),
(4,'Action',TRUE),(4,'Thriller',FALSE);

-- SCENES (dependent on films) - total participation: each scene MUST belong to a film
INSERT INTO SCENE (film_id, location, description, duration) VALUES
(1,'Space Station Interior','Opening corridor sequence',9),    -- scene 1
(1,'Bridge','Action on the central bridge',12),                -- scene 2
(2,'Café','Conversation scene',6),                             -- scene 3
(4,'Desert Dunes','Chase sequence',20),                        -- scene 4
(4,'Helicopter LZ','Rescue sequence',8);                      -- scene 5

-- FILM_CERTIFICATE (1:1 example)
INSERT INTO FILM_CERTIFICATE (film_id, rating_board, certificate_rating, issue_date, content_warnings) VALUES
(1,'MPAA','PG-13','2024-02-15','Intense sci-fi action sequences'),
(4,'MPAA','R','2024-10-20','Violence and intense action');

-- ACTOR_LANGUAGE
INSERT INTO ACTOR_LANGUAGE (actor_id, language, fluency_level) VALUES
(1,'English','Native'),
(1,'Italian','Conversational'),
(2,'English','Native'),
(3,'English','Native'),
(4,'English','Native'),(4,'Spanish','Conversational');

-- DIRECTOR_SPECIALIZATION
INSERT INTO DIRECTOR_SPECIALIZATION (director_id, specialization, years_experience) VALUES
(1,'Sci-Fi',20),(1,'Thriller',12),
(2,'Indie Drama',10),
(3,'Social Drama',15),
(4,'Thriller',18),(4,'Action',14);

-- ROLE (actor acts in film) - show multiple cardinalities
INSERT INTO ROLE (actor_id, film_id, character_name, screen_time, importance, salary) VALUES
(1,1,'Commander Ray',40,'Lead',2000000),    -- Leo in Quantum Dreams
(3,1,'Engineer Mark',25,'Supporting',800000),
(2,2,'Maya',50,'Lead',450000),              -- Emma Stone in Tiny Stories
(4,4,'Agent Rivers',60,'Lead',3000000);     -- Tessa in Desert Horizon

-- PRODUCED_BY (M:N with investment)
INSERT INTO PRODUCED_BY (film_id, producer_id, investment) VALUES
(1,1,25000000),(1,2,15000000),(1,3,10000000),
(2,2,8000000),
(4,1,30000000),(4,3,25000000);

-- DISTRIBUTES (M:N)
INSERT INTO DISTRIBUTES (distributor_id, film_id, distribution_fee, distribution_date, territory) VALUES
(1,1,40000000,'2024-02-01','Worldwide'),
(2,1,0,'2024-02-01','Domestic'), -- different rows show multiple territories if needed
(3,4,50000000,'2024-11-01','North America');

-- HOSTS (studio hosts film)
INSERT INTO HOSTS (studio_id, film_id, rental_cost, rental_start, rental_end) VALUES
(1,1,500000,'2023-05-01','2023-10-31'),
(2,4,750000,'2024-01-15','2024-07-30');

-- WORKS_ON (crew working on films) -- M:N
INSERT INTO WORKS_ON (crew_id, film_id, start_date, end_date, department) VALUES
(1,1,'2023-04-01','2023-08-15','Camera'),
(2,1,'2023-04-01','2023-07-30','Lighting'),
(3,1,'2023-06-01','2023-09-01','Editing'),
(1,4,'2024-01-05','2024-06-30','Camera'),
(4,4,'2024-02-01','2024-06-15','Sound');

-- SHOT_AT (film shots at location)
INSERT INTO SHOT_AT (film_id, location_id, shooting_start, shooting_end, total_cost) VALUES
(1,1,'2023-05-20','2023-06-05',200000),
(1,2,'2023-06-10','2023-06-20',150000),
(4,2,'2024-02-01','2024-03-15',800000),
(4,3,'2024-03-16','2024-04-05',300000);

-- SCENE_FILMING (ternary-ish): crew & equipment used in scenes
INSERT INTO SCENE_FILMING (film_id, scene_id, crew_id, equipment_id, filming_date, duration_minutes, notes) VALUES
(1,1,1,1,'2023-05-20',480,'Long take corridor sequence'),
(1,2,2,3,'2023-05-22',360,'Bridge action with dolly'),
(2,3,3,2,'2023-10-12',120,'Café dialogue'),
(4,4,1,2,'2024-02-20',1200,'Desert chase wide shots'),
(4,5,4,4,'2024-03-01',480,'Helicopter insertion sound setup');

-- FILM_CREW_EQUIPMENT (ternary usage stats)
INSERT INTO FILM_CREW_EQUIPMENT (film_id, crew_id, equipment_id, days_used, efficiency_rating, maintenance_required) VALUES
(1,1,1,45,9.1,0),
(1,2,3,20,8.0,0),
(4,1,2,60,8.8,1);

-- USAGE (film uses equipment across production)
INSERT INTO `USAGE` (film_id, equipment_id, usage_start, usage_end) VALUES
(1,1,'2023-04-01','2023-07-31'),
(1,2,'2023-04-01','2023-06-30'),
(4,2,'2024-01-01','2024-06-30');

-- AWARDS
INSERT INTO ACTOR_AWARD (actor_id, award_name, award_year) VALUES
(1,'Best Actor - Sci-Fi Fest',2024),
(3,'Best Supporting Actor',2020);

INSERT INTO DIRECTOR_AWARD (director_id, award_name, award_year) VALUES
(1,'Visionary Director',2023),
(4,'Best Director - Int. Festival',2022);

INSERT INTO CREW_AWARD (crew_id, award_name, award_year) VALUES
(1,'Best Cinematography',2024),
(3,'Best Editing',2021);

-- EQUIPMENT availability changes via SCENE_FILMING/USAGE keep data consistent

COMMIT;
