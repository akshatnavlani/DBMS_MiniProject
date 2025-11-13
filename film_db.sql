DROP DATABASE IF EXISTS filmdb;
CREATE DATABASE filmdb;
USE filmdb;

-- =========================
-- Strong Entities
-- =========================

CREATE TABLE DIRECTOR (
    director_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    dob DATE,
    gender ENUM('M','F','Other') DEFAULT 'Other',
    nationality VARCHAR(80)
);

CREATE TABLE PRODUCER (
    producer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    company VARCHAR(120),
    contact VARCHAR(50),
    email VARCHAR(120),
    dob DATE
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
    market_share DECIMAL(5,2) DEFAULT 0.00
);

CREATE TABLE ACTOR (
    actor_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    dob DATE,
    gender ENUM('M','F','Other') DEFAULT 'Other',
    nationality VARCHAR(80),
    stage_name VARCHAR(120)
);

CREATE TABLE CREW (
    crew_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    role VARCHAR(60) NOT NULL,
    dob DATE,
    experience_years INT DEFAULT 0,
    department VARCHAR(60),
    supervisor_id INT NULL,
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
    duration INT,
    language VARCHAR(80),
    boxoffice_collection DECIMAL(15,2) DEFAULT 0,
    rating DECIMAL(3,1),
    FK_director_id INT NULL,
    primary_genre VARCHAR(60),
    production_status ENUM('Pre-Production','In Progress','Post-Production','Released') DEFAULT 'Pre-Production',
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (FK_director_id) REFERENCES DIRECTOR(director_id) ON DELETE SET NULL
);

ALTER TABLE FILM ADD CONSTRAINT chk_film_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 10));
ALTER TABLE FILM ADD CONSTRAINT chk_film_duration CHECK (duration IS NULL OR duration > 0);
ALTER TABLE FILM ADD CONSTRAINT chk_film_budget CHECK (budget >= 0);
ALTER TABLE DISTRIBUTOR ADD CONSTRAINT chk_dist_market_share CHECK (market_share >= 0 AND market_share <= 100);
ALTER TABLE EQUIPMENT ADD CONSTRAINT chk_equipment_cost CHECK (cost >= 0);
ALTER TABLE SHOOTING_LOCATION ADD CONSTRAINT chk_location_cost CHECK (cost_per_day >= 0);
ALTER TABLE CREW ADD CONSTRAINT chk_experience_years CHECK (experience_years >= 0);

-- =========================
-- Audit & Logging Tables for Triggers
-- =========================

CREATE TABLE ROLE_AUDIT (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    actor_id INT NOT NULL,
    film_id INT NOT NULL,
    character_name VARCHAR(120),
    salary DECIMAL(14,2),
    action VARCHAR(20),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE EQUIPMENT_AUDIT (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    equipment_id INT NOT NULL,
    equipment_name VARCHAR(120),
    old_availability VARCHAR(50),
    new_availability VARCHAR(50),
    action VARCHAR(20),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE FILM_AUDIT (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    film_id INT NOT NULL,
    film_title VARCHAR(200),
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    old_budget DECIMAL(15,2),
    new_budget DECIMAL(15,2),
    action VARCHAR(20),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- Weak / Multi-valued / 1:1
-- =========================

CREATE TABLE ACTOR_LANGUAGE (
    actor_id INT NOT NULL,
    language VARCHAR(80) NOT NULL,
    fluency_level ENUM('Basic','Conversational','Fluent','Native') DEFAULT 'Conversational',
    PRIMARY KEY (actor_id, language),
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

CREATE TABLE FILM_GENRE (
    film_id INT NOT NULL,
    genre VARCHAR(60) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (film_id, genre),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

CREATE TABLE DIRECTOR_SPECIALIZATION (
    director_id INT NOT NULL,
    specialization VARCHAR(80) NOT NULL,
    years_experience INT DEFAULT 0,
    PRIMARY KEY (director_id, specialization),
    FOREIGN KEY (director_id) REFERENCES DIRECTOR(director_id) ON DELETE CASCADE
);

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

CREATE TABLE SCENE (
    scene_id INT PRIMARY KEY AUTO_INCREMENT,
    film_id INT NOT NULL,
    location VARCHAR(200),
    description TEXT,
    duration INT,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE
);

-- =========================
-- Relationship / Junction tables
-- =========================

CREATE TABLE ROLE (
    role_id INT PRIMARY KEY AUTO_INCREMENT,
    actor_id INT NOT NULL,
    film_id INT NOT NULL,
    character_name VARCHAR(120),
    screen_time INT,
    importance ENUM('Lead','Supporting','Cameo') DEFAULT 'Supporting',
    salary DECIMAL(14,2) DEFAULT 0,
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE,
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    UNIQUE (actor_id, film_id, character_name)
);

CREATE TABLE PRODUCED_BY (
    film_id INT NOT NULL,
    producer_id INT NOT NULL,
    investment DECIMAL(15,2) DEFAULT 0,
    PRIMARY KEY (film_id, producer_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (producer_id) REFERENCES PRODUCER(producer_id) ON DELETE CASCADE
);

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

CREATE TABLE `USAGE` (
    film_id INT NOT NULL,
    equipment_id INT NOT NULL,
    usage_start DATE,
    usage_end DATE,
    PRIMARY KEY (film_id, equipment_id),
    FOREIGN KEY (film_id) REFERENCES FILM(film_id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES EQUIPMENT(equipment_id) ON DELETE CASCADE
);

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


-- Create user metadata table (for storing additional user info)
CREATE TABLE IF NOT EXISTS USER_METADATA (
    username VARCHAR(50) PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE,
    role ENUM('admin', 'manager', 'viewer') DEFAULT 'viewer',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    last_login TIMESTAMP NULL
);

-- Create user activity log
CREATE TABLE USER_ACTIVITY_LOG (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    action_description TEXT,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username)
);

-- Create default admin MySQL user and metadata
-- Note: Run these commands with root privileges

-- Drop users if they exist
DROP USER IF EXISTS 'admin'@'localhost';
DROP USER IF EXISTS 'admin'@'%';

-- Create admin user
CREATE USER 'admin'@'localhost' IDENTIFIED BY 'Admin@123';
CREATE USER 'admin'@'%' IDENTIFIED BY 'Admin@123';

-- Grant all privileges to admin
GRANT ALL PRIVILEGES ON filmdb.* TO 'admin'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON filmdb.* TO 'admin'@'%' WITH GRANT OPTION;

-- Grant user management privileges to admin
GRANT CREATE USER ON *.* TO 'admin'@'localhost';
GRANT CREATE USER ON *.* TO 'admin'@'%';

FLUSH PRIVILEGES;

-- Insert admin metadata
INSERT INTO USER_METADATA (username, full_name, email, role, is_active, created_by)
VALUES ('admin', 'System Administrator', 'admin@filmdb.com', 'admin', TRUE, NULL);


-- =========================
-- TRIGGERS
-- =========================

-- TRIGGER 1: Validate actor age (must be 18+)
DELIMITER $$
CREATE TRIGGER tr_actor_age_validation
BEFORE INSERT ON ACTOR
FOR EACH ROW
BEGIN
    IF YEAR(CURDATE()) - YEAR(NEW.dob) < 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor must be at least 18 years old';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 2: Validate film budget (minimum $100,000)
DELIMITER $$
CREATE TRIGGER tr_film_budget_check
BEFORE INSERT ON FILM
FOR EACH ROW
BEGIN
    IF NEW.budget < 100000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Minimum film budget is $100,000';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 3: Validate film budget on update
DELIMITER $$
CREATE TRIGGER tr_film_budget_check_update
BEFORE UPDATE ON FILM
FOR EACH ROW
BEGIN
    IF NEW.budget < 100000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Minimum film budget is $100,000';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 4: Audit role insertions (salary tracking)
DELIMITER $$
CREATE TRIGGER tr_role_salary_audit
AFTER INSERT ON ROLE
FOR EACH ROW
BEGIN
    INSERT INTO ROLE_AUDIT (actor_id, film_id, character_name, salary, action)
    VALUES (NEW.actor_id, NEW.film_id, NEW.character_name, NEW.salary, 'INSERT');
END$$
DELIMITER ;

-- TRIGGER 5: Audit role deletions
DELIMITER $$
CREATE TRIGGER tr_role_deletion_audit
AFTER DELETE ON ROLE
FOR EACH ROW
BEGIN
    INSERT INTO ROLE_AUDIT (actor_id, film_id, character_name, salary, action)
    VALUES (OLD.actor_id, OLD.film_id, OLD.character_name, OLD.salary, 'DELETE');
END$$
DELIMITER ;

-- TRIGGER 6: Log equipment availability changes
DELIMITER $$
CREATE TRIGGER tr_equipment_availability_log
AFTER UPDATE ON EQUIPMENT
FOR EACH ROW
BEGIN
    IF OLD.availability != NEW.availability THEN
        INSERT INTO EQUIPMENT_AUDIT (equipment_id, equipment_name, old_availability, new_availability, action)
        VALUES (NEW.equipment_id, NEW.name, OLD.availability, NEW.availability, 'UPDATE');
    END IF;
END$$
DELIMITER ;

-- TRIGGER 7: Validate equipment cost (non-negative)
DELIMITER $$
CREATE TRIGGER tr_equipment_cost_validation
BEFORE INSERT ON EQUIPMENT
FOR EACH ROW
BEGIN
    IF NEW.cost < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipment cost cannot be negative';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 8: Log film status changes
DELIMITER $$
CREATE TRIGGER tr_film_status_audit
AFTER UPDATE ON FILM
FOR EACH ROW
BEGIN
    IF OLD.production_status != NEW.production_status THEN
        INSERT INTO FILM_AUDIT (film_id, film_title, old_status, new_status, old_budget, new_budget, action)
        VALUES (NEW.film_id, NEW.title, OLD.production_status, NEW.production_status, OLD.budget, NEW.budget, 'STATUS_CHANGE');
    END IF;
END$$
DELIMITER ;

-- TRIGGER 9: Validate location cost per day (non-negative)
DELIMITER $$
CREATE TRIGGER tr_location_cost_validation
BEFORE INSERT ON SHOOTING_LOCATION
FOR EACH ROW
BEGIN
    IF NEW.cost_per_day < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Location cost per day cannot be negative';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 10: Validate crew experience (non-negative)
DELIMITER $$
CREATE TRIGGER tr_crew_experience_validation
BEFORE INSERT ON CREW
FOR EACH ROW
BEGIN
    IF NEW.experience_years < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Experience years cannot be negative';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 11: Prevent shooting end date before start date
DELIMITER $$
CREATE TRIGGER tr_shot_at_date_validation
BEFORE INSERT ON SHOT_AT
FOR EACH ROW
BEGIN
    IF NEW.shooting_end < NEW.shooting_start THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shooting end date cannot be before start date';
    END IF;
END$$
DELIMITER ;

-- TRIGGER 12: Validate role salary (non-negative)
DELIMITER $$
CREATE TRIGGER tr_role_salary_validation
BEFORE INSERT ON ROLE
FOR EACH ROW
BEGIN
    IF NEW.salary < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role salary cannot be negative';
    END IF;
END$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER tr_log_user_creation
AFTER INSERT ON USER_METADATA
FOR EACH ROW
BEGIN
    INSERT INTO USER_ACTIVITY_LOG (username, action_type, action_description)
    VALUES (NEW.username, 'USER_CREATED', CONCAT('User ', NEW.username, ' created with role ', NEW.role));
END$$
DELIMITER ;

-- Trigger to log user updates
DELIMITER $$
CREATE TRIGGER tr_log_user_update
AFTER UPDATE ON USER_METADATA
FOR EACH ROW
BEGIN
    IF OLD.is_active != NEW.is_active THEN
        INSERT INTO USER_ACTIVITY_LOG (username, action_type, action_description)
        VALUES (NEW.username, 'USER_STATUS_CHANGE', 
                CONCAT('User ', NEW.username, ' status changed to ', 
                       IF(NEW.is_active, 'ACTIVE', 'INACTIVE')));
    END IF;
    
    IF OLD.role != NEW.role THEN
        INSERT INTO USER_ACTIVITY_LOG (username, action_type, action_description)
        VALUES (NEW.username, 'USER_ROLE_CHANGE', 
                CONCAT('User ', NEW.username, ' role changed from ', OLD.role, ' to ', NEW.role));
    END IF;
END$$
DELIMITER ;


-- =========================
-- FUNCTIONS
-- =========================

-- FUNCTION 1: Calculate film profit/loss
DELIMITER $$
CREATE FUNCTION fn_calculate_film_profit(film_id INT)
RETURNS DECIMAL(15,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE profit DECIMAL(15,2);
    SELECT (COALESCE(boxoffice_collection, 0) - COALESCE(budget, 0))
    INTO profit
    FROM FILM WHERE FILM.film_id = film_id;
    RETURN IFNULL(profit, 0);
END$$
DELIMITER ;

-- FUNCTION 2: Calculate actor age from date of birth
DELIMITER $$
CREATE FUNCTION fn_get_actor_age(actor_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE age INT;
    SELECT YEAR(CURDATE()) - YEAR(dob)
    INTO age
    FROM ACTOR WHERE ACTOR.actor_id = actor_id;
    RETURN IFNULL(age, 0);
END$$
DELIMITER ;

-- FUNCTION 3: Count films directed by director
DELIMITER $$
CREATE FUNCTION fn_director_film_count(director_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE film_count INT;
    SELECT COUNT(*) INTO film_count
    FROM FILM WHERE FK_director_id = director_id;
    RETURN IFNULL(film_count, 0);
END$$
DELIMITER ;

-- FUNCTION 4: Get total investment by producer
DELIMITER $$
CREATE FUNCTION fn_producer_total_investment(producer_id INT)
RETURNS DECIMAL(15,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_investment DECIMAL(15,2);
    SELECT COALESCE(SUM(investment), 0)
    INTO total_investment
    FROM PRODUCED_BY WHERE producer_id = producer_id;
    RETURN total_investment;
END$$
DELIMITER ;

-- FUNCTION 5: Calculate total crew working hours on a film
DELIMITER $$
CREATE FUNCTION fn_film_total_crew_hours(film_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_hours INT;
    SELECT COALESCE(SUM(duration_minutes), 0)
    INTO total_hours
    FROM SCENE_FILMING WHERE SCENE_FILMING.film_id = film_id;
    RETURN total_hours;
END$$
DELIMITER ;

-- FUNCTION 6: Check if equipment is available
DELIMITER $$
CREATE FUNCTION fn_equipment_available(equipment_id INT)
RETURNS VARCHAR(50)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avail_status VARCHAR(50);
    SELECT availability
    INTO avail_status
    FROM EQUIPMENT WHERE EQUIPMENT.equipment_id = equipment_id;
    RETURN IFNULL(avail_status, 'Unknown');
END$$
DELIMITER ;

-- FUNCTION 7: Get actor screen time in a film
DELIMITER $$
CREATE FUNCTION fn_actor_screen_time(actor_id INT, film_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE screen_time INT;
    SELECT COALESCE(SUM(screen_time), 0)
    INTO screen_time
    FROM ROLE WHERE ROLE.actor_id = actor_id AND ROLE.film_id = film_id;
    RETURN screen_time;
END$$
DELIMITER ;

-- FUNCTION 8: Calculate ROI (Return on Investment) for a film
DELIMITER $$
CREATE FUNCTION fn_calculate_film_roi(film_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE roi DECIMAL(5,2);
    DECLARE profit DECIMAL(15,2);
    DECLARE budget DECIMAL(15,2);
    
    SELECT COALESCE(boxoffice_collection, 0) - COALESCE(FILM.budget, 0),
           COALESCE(FILM.budget, 1)
    INTO profit, budget
    FROM FILM WHERE FILM.film_id = film_id;
    
    IF budget > 0 THEN
        SET roi = (profit / budget) * 100;
    ELSE
        SET roi = 0;
    END IF;
    
    RETURN IFNULL(roi, 0);
END$$
DELIMITER ;

-- FUNCTION 9: Get total scenes in a film
DELIMITER $$
CREATE FUNCTION fn_film_total_scenes(film_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE scene_count INT;
    SELECT COUNT(*) INTO scene_count
    FROM SCENE WHERE SCENE.film_id = film_id;
    RETURN IFNULL(scene_count, 0);
END$$
DELIMITER ;

-- FUNCTION 10: Get average actor salary in a film
DELIMITER $$
CREATE FUNCTION fn_film_avg_actor_salary(film_id INT)
RETURNS DECIMAL(14,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_salary DECIMAL(14,2);
    SELECT COALESCE(AVG(salary), 0)
    INTO avg_salary
    FROM ROLE WHERE ROLE.film_id = film_id;
    RETURN avg_salary;
END$$
DELIMITER ;

-- FUNCTION: Authenticate user (check if MySQL user exists and is active)
DELIMITER $$

DROP FUNCTION IF EXISTS fn_authenticate_user$$
CREATE FUNCTION fn_authenticate_user(
    p_username VARCHAR(50)
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_is_active BOOLEAN;
    DECLARE v_role VARCHAR(20);
    
    -- Check if user exists in metadata and is active
    SELECT is_active, role
    INTO v_is_active, v_role
    FROM USER_METADATA
    WHERE username = p_username
    LIMIT 1;

    IF v_role IS NULL THEN
        RETURN -1; -- User not found in metadata
    ELSEIF NOT v_is_active THEN
        RETURN -3; -- Account inactive
    ELSE
        RETURN 1; -- Successful authentication
    END IF;
END$$
DELIMITER ;


-- =========================
-- STORED PROCEDURES
-- =========================

-- PROCEDURE 1: Add film with multiple genres
DELIMITER $$
CREATE PROCEDURE sp_add_film_with_genres(
    IN p_title VARCHAR(200),
    IN p_budget DECIMAL(15,2),
    IN p_duration INT,
    IN p_director_id INT,
    IN p_language VARCHAR(80),
    IN p_genres VARCHAR(500)
)
BEGIN
    DECLARE film_id INT;
    DECLARE genre_list VARCHAR(500);
    DECLARE genre_name VARCHAR(60);
    DECLARE comma_pos INT;
    
    -- Insert the main film record
    INSERT INTO FILM (title, budget, duration, FK_director_id, language, primary_genre, production_status)
    VALUES (p_title, p_budget, p_duration, p_director_id, p_language, 'Drama', 'Pre-Production');
    
    SET film_id = LAST_INSERT_ID();
    SET genre_list = CONCAT(p_genres, ',');
    
    -- Insert each genre
    WHILE CHAR_LENGTH(genre_list) > 0 DO
        SET comma_pos = INSTR(genre_list, ',');
        IF comma_pos > 0 THEN
            SET genre_name = TRIM(SUBSTRING(genre_list, 1, comma_pos - 1));
            SET genre_list = SUBSTRING(genre_list, comma_pos + 1);
        ELSE
            SET genre_name = TRIM(genre_list);
            SET genre_list = '';
        END IF;
        
        IF CHAR_LENGTH(genre_name) > 0 THEN
            INSERT IGNORE INTO FILM_GENRE (film_id, genre, is_primary)
            VALUES (film_id, genre_name, FALSE);
        END IF;
    END WHILE;
    
    SELECT film_id as new_film_id;
END$$
DELIMITER ;

-- PROCEDURE 2: Get complete actor filmography
DELIMITER $$
CREATE PROCEDURE sp_get_actor_filmography(IN p_actor_id INT)
BEGIN
    SELECT 
        f.film_id,
        f.title,
        f.release_date,
        f.duration,
        f.language,
        r.character_name,
        r.screen_time,
        r.importance,
        r.salary,
        d.name as director_name
    FROM FILM f
    JOIN ROLE r ON f.film_id = r.film_id
    LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id
    WHERE r.actor_id = p_actor_id
    ORDER BY f.release_date DESC;
END$$
DELIMITER ;

-- PROCEDURE 3: Calculate producer investment details
DELIMITER $$
CREATE PROCEDURE sp_calculate_producer_investment(IN p_producer_id INT)
BEGIN
    SELECT 
        p.producer_id,
        p.name,
        p.company,
        COUNT(DISTINCT pb.film_id) as total_films,
        SUM(pb.investment) as total_investment,
        AVG(pb.investment) as avg_investment,
        MAX(pb.investment) as max_investment,
        MIN(pb.investment) as min_investment
    FROM PRODUCER p
    LEFT JOIN PRODUCED_BY pb ON p.producer_id = pb.producer_id
    WHERE p.producer_id = p_producer_id
    GROUP BY p.producer_id, p.name, p.company;
END$$
DELIMITER ;

-- PROCEDURE 4: Allocate crew to film
DELIMITER $$
CREATE PROCEDURE sp_allocate_crew_to_film(
    IN p_crew_id INT,
    IN p_film_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE crew_department VARCHAR(80);
    
    -- Get crew department
    SELECT department INTO crew_department
    FROM CREW WHERE crew_id = p_crew_id;
    
    -- Insert work assignment
    INSERT INTO WORKS_ON (crew_id, film_id, start_date, end_date, department)
    VALUES (p_crew_id, p_film_id, p_start_date, p_end_date, crew_department);
    
    SELECT 'Crew allocated successfully' as message;
END$$
DELIMITER ;

-- PROCEDURE 5: Cast actor in film
DELIMITER $$
CREATE PROCEDURE sp_cast_actor_in_film(
    IN p_actor_id INT,
    IN p_film_id INT,
    IN p_character_name VARCHAR(120),
    IN p_importance VARCHAR(20),
    IN p_salary DECIMAL(14,2)
)
BEGIN
    INSERT INTO ROLE (actor_id, film_id, character_name, screen_time, importance, salary)
    VALUES (p_actor_id, p_film_id, p_character_name, 0, p_importance, p_salary);
    
    SELECT 'Actor cast successfully' as message;
END$$
DELIMITER ;

-- PROCEDURE 6: Get film production summary
DELIMITER $$
CREATE PROCEDURE sp_get_film_production_summary(IN p_film_id INT)
BEGIN
    SELECT 
        f.film_id,
        f.title,
        f.production_status,
        f.budget,
        f.duration,
        d.name as director,
        COUNT(DISTINCT r.actor_id) as total_actors,
        COUNT(DISTINCT s.scene_id) as total_scenes,
        COUNT(DISTINCT wo.crew_id) as total_crew,
        COUNT(DISTINCT sl.location_id) as total_locations
    FROM FILM f
    LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id
    LEFT JOIN ROLE r ON f.film_id = r.film_id
    LEFT JOIN SCENE s ON f.film_id = s.film_id
    LEFT JOIN WORKS_ON wo ON f.film_id = wo.film_id
    LEFT JOIN SHOT_AT sa ON f.film_id = sa.film_id
    LEFT JOIN SHOOTING_LOCATION sl ON sa.location_id = sl.location_id
    WHERE f.film_id = p_film_id
    GROUP BY f.film_id, f.title, f.production_status, f.budget, f.duration, d.name;
END$$
DELIMITER ;

-- PROCEDURE 7: Update equipment availability and log
DELIMITER $$
CREATE PROCEDURE sp_update_equipment_status(
    IN p_equipment_id INT,
    IN p_new_status VARCHAR(50)
)
BEGIN
    UPDATE EQUIPMENT
    SET availability = p_new_status
    WHERE equipment_id = p_equipment_id;
    
    SELECT CONCAT('Equipment ', p_equipment_id, ' status updated to ', p_new_status) as message;
END$$
DELIMITER ;

-- PROCEDURE 8: Get director films with profitability
DELIMITER $$
CREATE PROCEDURE sp_get_director_filmography_with_profit(IN p_director_id INT)
BEGIN
    SELECT 
        f.film_id,
        f.title,
        f.release_date,
        f.budget,
        f.boxoffice_collection,
        fn_calculate_film_profit(f.film_id) as profit,
        fn_calculate_film_roi(f.film_id) as roi_percentage,
        f.rating,
        f.production_status
    FROM FILM f
    WHERE f.FK_director_id = p_director_id
    ORDER BY f.release_date DESC;
END$$
DELIMITER ;

-- PROCEDURE 9: Add shooting location with scenes
DELIMITER $$
CREATE PROCEDURE sp_add_shooting_location(
    IN p_film_id INT,
    IN p_location_name VARCHAR(120),
    IN p_city VARCHAR(80),
    IN p_country VARCHAR(80),
    IN p_shooting_start DATE,
    IN p_shooting_end DATE,
    IN p_cost_per_day DECIMAL(12,2)
)
BEGIN
    DECLARE location_id INT;
    DECLARE total_days INT;
    DECLARE total_cost DECIMAL(15,2);
    
    -- Create new location if not exists
    INSERT IGNORE INTO SHOOTING_LOCATION (name, city, country, cost_per_day)
    VALUES (p_location_name, p_city, p_country, p_cost_per_day);
    
    SELECT location_id INTO location_id
    FROM SHOOTING_LOCATION
    WHERE name = p_location_name AND city = p_city
    LIMIT 1;
    
    -- Calculate total cost
    SET total_days = DATEDIFF(p_shooting_end, p_shooting_start) + 1;
    SET total_cost = total_days * p_cost_per_day;
    
    -- Add to SHOT_AT
    INSERT INTO SHOT_AT (film_id, location_id, shooting_start, shooting_end, total_cost)
    VALUES (p_film_id, location_id, p_shooting_start, p_shooting_end, total_cost);
    
    SELECT location_id, total_days, total_cost as calculated_cost;
END$
DELIMITER ;

-- PROCEDURE 10: Generate crew payroll for a film
DELIMITER $
CREATE PROCEDURE sp_get_film_crew_payroll(IN p_film_id INT)
BEGIN
    SELECT 
        c.crew_id,
        c.name,
        c.role,
        c.department,
        wo.start_date,
        wo.end_date,
        DATEDIFF(wo.end_date, wo.start_date) + 1 as working_days,
        COUNT(DISTINCT sf.filming_id) as shoots,
        SUM(sf.duration_minutes) as total_minutes
    FROM CREW c
    JOIN WORKS_ON wo ON c.crew_id = wo.crew_id
    LEFT JOIN SCENE_FILMING sf ON c.crew_id = sf.crew_id AND wo.film_id = sf.film_id
    WHERE wo.film_id = p_film_id
    GROUP BY c.crew_id, c.name, c.role, c.department, wo.start_date, wo.end_date;
END$
DELIMITER ;

-- PROCEDURE 11: Get equipment usage report for a film
DELIMITER $
CREATE PROCEDURE sp_get_equipment_usage_report(IN p_film_id INT)
BEGIN
    SELECT 
        e.equipment_id,
        e.name,
        e.type,
        e.cost,
        fce.days_used,
        fce.efficiency_rating,
        fce.maintenance_required,
        COUNT(DISTINCT sf.filming_id) as times_used,
        COUNT(DISTINCT sf.crew_id) as crew_members_used
    FROM EQUIPMENT e
    LEFT JOIN FILM_CREW_EQUIPMENT fce ON e.equipment_id = fce.equipment_id AND fce.film_id = p_film_id
    LEFT JOIN SCENE_FILMING sf ON e.equipment_id = sf.equipment_id AND sf.film_id = p_film_id
    WHERE p_film_id IS NULL OR fce.film_id = p_film_id
    GROUP BY e.equipment_id, e.name, e.type, e.cost, fce.days_used, fce.efficiency_rating, fce.maintenance_required;
END$
DELIMITER ;

-- PROCEDURE 12: Update film production status with audit
DELIMITER $
CREATE PROCEDURE sp_update_film_status(
    IN p_film_id INT,
    IN p_new_status VARCHAR(50)
)
BEGIN
    DECLARE old_status VARCHAR(50);
    
    SELECT production_status INTO old_status
    FROM FILM WHERE film_id = p_film_id;
    
    UPDATE FILM
    SET production_status = p_new_status
    WHERE film_id = p_film_id;
    
    INSERT INTO FILM_AUDIT (film_id, film_title, old_status, new_status, action)
    SELECT film_id, title, old_status, p_new_status, 'STATUS_UPDATE'
    FROM FILM WHERE film_id = p_film_id;
    
    SELECT CONCAT('Film status updated from ', old_status, ' to ', p_new_status) as message;
END$
DELIMITER ;

-- PROCEDURE 13: Get box office analysis
DELIMITER $
CREATE PROCEDURE sp_get_boxoffice_analysis()
BEGIN
    SELECT 
        f.film_id,
        f.title,
        f.release_date,
        f.budget,
        f.boxoffice_collection,
        fn_calculate_film_profit(f.film_id) as profit,
        fn_calculate_film_roi(f.film_id) as roi_percentage,
        d.name as director,
        COUNT(DISTINCT r.actor_id) as cast_size
    FROM FILM f
    LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id
    LEFT JOIN ROLE r ON f.film_id = r.film_id
    WHERE f.boxoffice_collection > 0
    GROUP BY f.film_id, f.title, f.release_date, f.budget, f.boxoffice_collection, d.name
    ORDER BY f.boxoffice_collection DESC;
END$
DELIMITER ;

-- PROCEDURE 14: Get actor award history
DELIMITER $
CREATE PROCEDURE sp_get_actor_award_history(IN p_actor_id INT)
BEGIN
    SELECT 
        a.first_name,
        a.last_name,
        a.nationality,
        aa.award_name,
        aa.award_year,
        COUNT(*) OVER (PARTITION BY aa.actor_id) as total_awards
    FROM ACTOR a
    LEFT JOIN ACTOR_AWARD aa ON a.actor_id = aa.actor_id
    WHERE a.actor_id = p_actor_id
    ORDER BY aa.award_year DESC;
END$
DELIMITER ;

-- PROCEDURE 15: Get distributor performance
DELIMITER $
CREATE PROCEDURE sp_get_distributor_performance()
BEGIN
    SELECT 
        d.distributor_id,
        d.name,
        d.region,
        d.market_share,
        COUNT(DISTINCT dist.film_id) as films_distributed,
        SUM(dist.distribution_fee) as total_fees,
        AVG(f.boxoffice_collection) as avg_boxoffice
    FROM DISTRIBUTOR d
    LEFT JOIN DISTRIBUTES dist ON d.distributor_id = dist.distributor_id
    LEFT JOIN FILM f ON dist.film_id = f.film_id
    GROUP BY d.distributor_id, d.name, d.region, d.market_share
    ORDER BY total_fees DESC;
END$
DELIMITER ;

-- Procedure to create new user (admin only) - Creates MySQL user and metadata
DELIMITER $$
CREATE PROCEDURE sp_create_user(
    IN p_admin_username VARCHAR(50),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_full_name VARCHAR(120),
    IN p_email VARCHAR(120),
    IN p_role VARCHAR(20)
)
BEGIN
    DECLARE v_admin_role VARCHAR(20);
    DECLARE v_sql_stmt VARCHAR(500);
    
    -- Check if creating user is admin
    SELECT role INTO v_admin_role
    FROM USER_METADATA
    WHERE username = p_admin_username;
    
    IF v_admin_role != 'admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Only administrators can create users';
    END IF;
    
    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM USER_METADATA WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'User already exists';
    END IF;
    
    -- Create MySQL user for localhost
    SET @sql_create_local = CONCAT('CREATE USER ''', p_username, '''@''localhost'' IDENTIFIED BY ''', p_password, '''');
    PREPARE stmt FROM @sql_create_local;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Create MySQL user for remote access
    SET @sql_create_remote = CONCAT('CREATE USER ''', p_username, '''@''%'' IDENTIFIED BY ''', p_password, '''');
    PREPARE stmt FROM @sql_create_remote;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Grant privileges based on role
    IF p_role = 'admin' THEN
        -- Admin gets all privileges including user management
        SET @sql_grant_local = CONCAT('GRANT ALL PRIVILEGES ON filmdb.* TO ''', p_username, '''@''localhost'' WITH GRANT OPTION');
        PREPARE stmt FROM @sql_grant_local;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET @sql_grant_remote = CONCAT('GRANT ALL PRIVILEGES ON filmdb.* TO ''', p_username, '''@''%'' WITH GRANT OPTION');
        PREPARE stmt FROM @sql_grant_remote;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET @sql_grant_create_user_local = CONCAT('GRANT CREATE USER ON *.* TO ''', p_username, '''@''localhost''');
        PREPARE stmt FROM @sql_grant_create_user_local;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET @sql_grant_create_user_remote = CONCAT('GRANT CREATE USER ON *.* TO ''', p_username, '''@''%''');
        PREPARE stmt FROM @sql_grant_create_user_remote;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
    ELSEIF p_role = 'manager' THEN
        -- Manager can SELECT, INSERT, UPDATE, DELETE, EXECUTE
        SET @sql_grant_local = CONCAT('GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON filmdb.* TO ''', p_username, '''@''localhost''');
        PREPARE stmt FROM @sql_grant_local;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET @sql_grant_remote = CONCAT('GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON filmdb.* TO ''', p_username, '''@''%''');
        PREPARE stmt FROM @sql_grant_remote;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
    ELSE -- viewer
        -- Viewer can only SELECT and EXECUTE (for read-only operations)
        SET @sql_grant_local = CONCAT('GRANT SELECT, EXECUTE ON filmdb.* TO ''', p_username, '''@''localhost''');
        PREPARE stmt FROM @sql_grant_local;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SET @sql_grant_remote = CONCAT('GRANT SELECT, EXECUTE ON filmdb.* TO ''', p_username, '''@''%''');
        PREPARE stmt FROM @sql_grant_remote;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
    
    FLUSH PRIVILEGES;
    
    -- Insert metadata
    INSERT INTO USER_METADATA (username, full_name, email, role, created_by)
    VALUES (p_username, p_full_name, p_email, p_role, p_admin_username);
    
    SELECT CONCAT('User ', p_username, ' created successfully') as message;
END$$
DELIMITER ;

-- Procedure to update user login
DELIMITER $$
CREATE PROCEDURE sp_update_login(
    IN p_username VARCHAR(50),
    IN p_success BOOLEAN,
    IN p_ip_address VARCHAR(45)
)
BEGIN
    IF p_success THEN
        UPDATE USER_METADATA
        SET last_login = CURRENT_TIMESTAMP
        WHERE username = p_username;
        
        INSERT INTO USER_ACTIVITY_LOG (username, action_type, action_description, ip_address)
        VALUES (p_username, 'LOGIN_SUCCESS', 'User logged in successfully', p_ip_address);
    ELSE
        INSERT INTO USER_ACTIVITY_LOG (username, action_type, action_description, ip_address)
        VALUES (p_username, 'LOGIN_FAILED', 'Failed login attempt', p_ip_address);
    END IF;
END$$
DELIMITER ;

-- Procedure to get all users (admin only)
DELIMITER $$
CREATE PROCEDURE sp_get_all_users(IN p_admin_username VARCHAR(50))
BEGIN
    DECLARE v_admin_role VARCHAR(20);
    
    SELECT role INTO v_admin_role
    FROM USER_METADATA
    WHERE username = p_admin_username;
    
    IF v_admin_role != 'admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Only administrators can view all users';
    END IF;
    
    SELECT 
        username,
        full_name,
        email,
        role,
        is_active,
        created_at,
        last_login,
        created_by
    FROM USER_METADATA
    ORDER BY created_at DESC;
END$$
DELIMITER ;

-- Procedure to update user status
DELIMITER $$
CREATE PROCEDURE sp_update_user_status(
    IN p_admin_username VARCHAR(50),
    IN p_target_username VARCHAR(50),
    IN p_is_active BOOLEAN
)
BEGIN
    DECLARE v_admin_role VARCHAR(20);
    
    SELECT role INTO v_admin_role
    FROM USER_METADATA
    WHERE username = p_admin_username;
    
    IF v_admin_role != 'admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Only administrators can update user status';
    END IF;
    
    UPDATE USER_METADATA
    SET is_active = p_is_active
    WHERE username = p_target_username;
    
    SELECT 'User status updated successfully' as message;
END$$
DELIMITER ;

-- Procedure to delete user (admin only) - Drops MySQL user and removes metadata
DELIMITER $$
CREATE PROCEDURE sp_delete_user(
    IN p_admin_username VARCHAR(50),
    IN p_target_username VARCHAR(50)
)
BEGIN
    DECLARE v_admin_role VARCHAR(20);
    DECLARE v_target_role VARCHAR(20);
    
    SELECT role INTO v_admin_role
    FROM USER_METADATA
    WHERE username = p_admin_username;
    
    SELECT role INTO v_target_role
    FROM USER_METADATA
    WHERE username = p_target_username;
    
    IF v_admin_role != 'admin' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Only administrators can delete users';
    END IF;
    
    -- Prevent deleting the last admin
    IF v_target_role = 'admin' THEN
        IF (SELECT COUNT(*) FROM USER_METADATA WHERE role = 'admin' AND is_active = TRUE) <= 1 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Cannot delete the last active administrator';
        END IF;
    END IF;
    
    -- Drop MySQL user
    SET @sql_drop_local = CONCAT('DROP USER IF EXISTS ''', p_target_username, '''@''localhost''');
    PREPARE stmt FROM @sql_drop_local;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    SET @sql_drop_remote = CONCAT('DROP USER IF EXISTS ''', p_target_username, '''@''%''');
    PREPARE stmt FROM @sql_drop_remote;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    FLUSH PRIVILEGES;
    
    -- Delete metadata
    DELETE FROM USER_METADATA WHERE username = p_target_username;
    
    SELECT 'User deleted successfully' as message;
END$$
DELIMITER ;

-- View for user activity summary
CREATE VIEW view_user_activity_summary AS
SELECT 
    u.username,
    u.full_name,
    u.role,
    COUNT(DISTINCT al.log_id) as total_activities,
    MAX(al.timestamp) as last_activity,
    SUM(CASE WHEN al.action_type = 'LOGIN_SUCCESS' THEN 1 ELSE 0 END) as successful_logins,
    SUM(CASE WHEN al.action_type = 'LOGIN_FAILED' THEN 1 ELSE 0 END) as failed_logins
FROM USER_METADATA u
LEFT JOIN USER_ACTIVITY_LOG al ON u.username = al.username
GROUP BY u.username, u.full_name, u.role;


-- =========================
-- Indexes & Views
-- =========================

CREATE INDEX idx_film_director ON FILM(FK_director_id);
CREATE INDEX idx_role_actor ON ROLE(actor_id);
CREATE INDEX idx_role_film ON ROLE(film_id);
CREATE INDEX idx_scene_film ON SCENE(film_id);
CREATE INDEX idx_works_on_film ON WORKS_ON(film_id);
CREATE INDEX idx_works_on_crew ON WORKS_ON(crew_id);
CREATE INDEX idx_shot_at_film ON SHOT_AT(film_id);
CREATE INDEX idx_shot_at_location ON SHOT_AT(location_id);
CREATE INDEX idx_equipment_avail ON EQUIPMENT(availability);
CREATE INDEX idx_produced_by_film ON PRODUCED_BY(film_id);
CREATE INDEX idx_produced_by_producer ON PRODUCED_BY(producer_id);
CREATE INDEX idx_film_status ON FILM(production_status);
CREATE INDEX idx_scene_filming_film ON SCENE_FILMING(film_id);
CREATE INDEX idx_scene_filming_crew ON SCENE_FILMING(crew_id);

-- VIEW 1: Film basic information with director
CREATE VIEW view_film_basic AS
SELECT f.film_id, f.title, f.release_date, f.budget, f.duration, f.language, f.rating, 
       f.production_status, d.name AS director_name, f.created_date
FROM FILM f
LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id;

-- VIEW 2: Film profitability
CREATE VIEW view_film_profitability AS
SELECT 
    f.film_id,
    f.title,
    f.budget,
    f.boxoffice_collection,
    fn_calculate_film_profit(f.film_id) as profit,
    fn_calculate_film_roi(f.film_id) as roi_percentage,
    d.name as director,
    f.production_status
FROM FILM f
LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id
WHERE f.boxoffice_collection > 0;

-- VIEW 3: Actor details with age
CREATE VIEW view_actor_details AS
SELECT 
    a.actor_id,
    CONCAT(a.first_name, ' ', a.last_name) as full_name,
    a.stage_name,
    a.dob,
    fn_get_actor_age(a.actor_id) as age,
    a.gender,
    a.nationality,
    COUNT(DISTINCT r.film_id) as total_films
FROM ACTOR a
LEFT JOIN ROLE r ON a.actor_id = r.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name, a.stage_name, a.dob, a.gender, a.nationality;

-- VIEW 4: Director filmography with stats
CREATE VIEW view_director_filmography AS
SELECT 
    d.director_id,
    d.name,
    d.nationality,
    COUNT(f.film_id) as total_films,
    SUM(f.budget) as total_budget,
    SUM(f.boxoffice_collection) as total_boxoffice,
    AVG(f.rating) as avg_rating
FROM DIRECTOR d
LEFT JOIN FILM f ON d.director_id = f.FK_director_id
GROUP BY d.director_id, d.name, d.nationality;

-- VIEW 5: Producer investment overview
CREATE VIEW view_producer_investment AS
SELECT 
    p.producer_id,
    p.name,
    p.company,
    COUNT(DISTINCT pb.film_id) as portfolio_films,
    SUM(pb.investment) as total_investment,
    AVG(pb.investment) as avg_investment
FROM PRODUCER p
LEFT JOIN PRODUCED_BY pb ON p.producer_id = pb.producer_id
GROUP BY p.producer_id, p.name, p.company;

-- VIEW 6: Crew department summary
CREATE VIEW view_crew_by_department AS
SELECT 
    c.department,
    COUNT(DISTINCT c.crew_id) as crew_count,
    AVG(c.experience_years) as avg_experience,
    MAX(c.experience_years) as max_experience,
    COUNT(DISTINCT wo.film_id) as films_worked
FROM CREW c
LEFT JOIN WORKS_ON wo ON c.crew_id = wo.crew_id
WHERE c.department IS NOT NULL
GROUP BY c.department;

-- VIEW 7: Equipment availability status
CREATE VIEW view_equipment_status AS
SELECT 
    e.equipment_id,
    e.name,
    e.type,
    e.cost,
    e.availability,
    e.`condition`,
    COUNT(DISTINCT fce.film_id) as films_used,
    AVG(fce.efficiency_rating) as avg_efficiency
FROM EQUIPMENT e
LEFT JOIN FILM_CREW_EQUIPMENT fce ON e.equipment_id = fce.equipment_id
GROUP BY e.equipment_id, e.name, e.type, e.cost, e.availability, e.`condition`;

-- VIEW 8: Scene filming summary
CREATE VIEW view_scene_filming_summary AS
SELECT 
    s.scene_id,
    s.film_id,
    f.title as film_title,
    s.location,
    s.description,
    s.duration,
    COUNT(DISTINCT sf.crew_id) as crew_involved,
    COUNT(DISTINCT sf.equipment_id) as equipment_used,
    COUNT(DISTINCT sf.filming_id) as filming_sessions
FROM SCENE s
JOIN FILM f ON s.film_id = f.film_id
LEFT JOIN SCENE_FILMING sf ON s.scene_id = sf.scene_id
GROUP BY s.scene_id, s.film_id, f.title, s.location, s.description, s.duration;

-- =========================
-- Sample Data
-- =========================

INSERT INTO DIRECTOR (name, dob, gender, nationality) VALUES
('Christopher Nolan','1970-07-30','M','British'),
('Greta Gerwig','1983-08-04','F','American'),
('Ava DuVernay','1972-08-24','F','American'),
('Denis Villeneuve','1967-10-03','M','Canadian');

INSERT INTO PRODUCER (name, company, contact, email, dob) VALUES
('Emma Thomas','Syncopy','+1-555-0101','emma@syncopy.example','1971-12-09'),
('Scott Rudin','Rudin Productions','+1-555-0102','scott@rudin.example','1958-07-14'),
('Dede Gardner','Plan B Entertainment','+1-555-0103','dede@planb.example','1967-01-01');

INSERT INTO STUDIO (name, location, established_year, capacity, facilities) VALUES
('Warner Bros. Studios','Burbank, CA',1923,4800,'sound stages, backlot, editing suites'),
('Universal Studios','Universal City, CA',1912,5200,'post-production, VFX, sound'),
('Pinewood Studios','Iver Heath, UK',1936,6000,'stages, backlot, water tank');

INSERT INTO DISTRIBUTOR (name, region, market_share) VALUES
('Warner Distribution','Worldwide',22.50),
('Universal Pictures','Worldwide',24.30),
('Sony Pictures','North America',12.00);

INSERT INTO ACTOR (first_name,last_name,dob,gender,nationality,stage_name) VALUES
('Leonardo','DiCaprio','1974-11-11','M','American','Leo'),
('Emma','Stone','1988-11-06','F','American','Emma Stone'),
('Robert','Downey Jr.','1965-04-04','M','American','RDJ'),
('Tessa','Thompson','1983-10-03','F','American','Tessa');

INSERT INTO CREW (name, role, dob, experience_years, department, supervisor_id) VALUES
('Sam Carter','Cinematographer','1982-04-15',15,'Camera',NULL),
('Alex Kim','Gaffer','1985-10-10',12,'Lighting',1),
('Priya Patel','Editor','1990-02-21',8,'Editing',NULL),
('Miguel Sanchez','Sound Designer','1978-06-30',18,'Sound',NULL);

INSERT INTO EQUIPMENT (name, type, cost, purchase_date, `condition`, availability) VALUES
('Arri Alexa Mini','Camera',120000,'2018-05-01','Good','Available'),
('RED Helium','Camera',90000,'2019-03-10','Good','In Use'),
('Dolly Track Set','Grip',15000,'2017-08-01','Good','Available'),
('Boom Microphone Kit','Sound',4000,'2020-01-15','Good','Available');

INSERT INTO SHOOTING_LOCATION (name, city, state, country, cost_per_day, area, amenities) VALUES
('Old Factory','Detroit','MI','USA',2500,'Large indoor','power, parking, dressing rooms'),
('Seaside Cliff','Santa Monica','CA','USA',3500,'Outdoor','permit required, safety crew'),
('Central Park','New York','NY','USA',5000,'Large outdoor','public access, permits');

INSERT INTO FILM (title, release_date, budget, duration, language, boxoffice_collection, rating, primary_genre, FK_director_id, production_status) VALUES
('Quantum Dreams','2024-06-01',50000000,130,'English',120000000,8.2,'Sci-Fi',1,'Released'),
('Tiny Stories','2023-11-10',12000000,95,'English',30000000,7.1,'Drama',2,'Released'),
('Echoes of Home','2025-03-20',15000000,110,'English',0,NULL,'Drama',3,'Post-Production'),
('Desert Horizon','2024-12-05',80000000,145,'English',400000000,9.0,'Action',4,'Released');

INSERT INTO FILM_GENRE (film_id, genre, is_primary) VALUES
(1,'Sci-Fi',TRUE),(1,'Adventure',FALSE),
(2,'Drama',TRUE),(2,'Comedy',FALSE),
(3,'Drama',TRUE),(3,'Family',FALSE),
(4,'Action',TRUE),(4,'Thriller',FALSE);

INSERT INTO SCENE (film_id, location, description, duration) VALUES
(1,'Space Station Interior','Opening corridor sequence',9),
(1,'Bridge','Action on the central bridge',12),
(2,'Café','Conversation scene',6),
(4,'Desert Dunes','Chase sequence',20),
(4,'Helicopter LZ','Rescue sequence',8);

INSERT INTO FILM_CERTIFICATE (film_id, rating_board, certificate_rating, issue_date, content_warnings) VALUES
(1,'MPAA','PG-13','2024-02-15','Intense sci-fi action sequences'),
(4,'MPAA','R','2024-10-20','Violence and intense action');

INSERT INTO ACTOR_LANGUAGE (actor_id, language, fluency_level) VALUES
(1,'English','Native'),
(1,'Italian','Conversational'),
(2,'English','Native'),
(3,'English','Native'),
(4,'English','Native'),(4,'Spanish','Conversational');

INSERT INTO DIRECTOR_SPECIALIZATION (director_id, specialization, years_experience) VALUES
(1,'Sci-Fi',20),(1,'Thriller',12),
(2,'Indie Drama',10),
(3,'Social Drama',15),
(4,'Thriller',18),(4,'Action',14);

INSERT INTO ROLE (actor_id, film_id, character_name, screen_time, importance, salary) VALUES
(1,1,'Commander Ray',40,'Lead',2000000),
(3,1,'Engineer Mark',25,'Supporting',800000),
(2,2,'Maya',50,'Lead',450000),
(4,4,'Agent Rivers',60,'Lead',3000000);

INSERT INTO PRODUCED_BY (film_id, producer_id, investment) VALUES
(1,1,25000000),(1,2,15000000),(1,3,10000000),
(2,2,8000000),
(4,1,30000000),(4,3,25000000);

INSERT INTO DISTRIBUTES (distributor_id, film_id, distribution_fee, distribution_date, territory) VALUES
(1,1,40000000,'2024-02-01','Worldwide'),
(2,1,0,'2024-02-01','Domestic'),
(3,4,50000000,'2024-11-01','North America');

INSERT INTO HOSTS (studio_id, film_id, rental_cost, rental_start, rental_end) VALUES
(1,1,500000,'2023-05-01','2023-10-31'),
(2,4,750000,'2024-01-15','2024-07-30');

INSERT INTO WORKS_ON (crew_id, film_id, start_date, end_date, department) VALUES
(1,1,'2023-04-01','2023-08-15','Camera'),
(2,1,'2023-04-01','2023-07-30','Lighting'),
(3,1,'2023-06-01','2023-09-01','Editing'),
(1,4,'2024-01-05','2024-06-30','Camera'),
(4,4,'2024-02-01','2024-06-15','Sound');

INSERT INTO SHOT_AT (film_id, location_id, shooting_start, shooting_end, total_cost) VALUES
(1,1,'2023-05-20','2023-06-05',200000),
(1,2,'2023-06-10','2023-06-20',150000),
(4,2,'2024-02-01','2024-03-15',800000),
(4,3,'2024-03-16','2024-04-05',300000);

INSERT INTO SCENE_FILMING (film_id, scene_id, crew_id, equipment_id, filming_date, duration_minutes, notes) VALUES
(1,1,1,1,'2023-05-20',480,'Long take corridor sequence'),
(1,2,2,3,'2023-05-22',360,'Bridge action with dolly'),
(2,3,3,2,'2023-10-12',120,'Café dialogue'),
(4,4,1,2,'2024-02-20',1200,'Desert chase wide shots'),
(4,5,4,4,'2024-03-01',480,'Helicopter insertion sound setup');

INSERT INTO FILM_CREW_EQUIPMENT (film_id, crew_id, equipment_id, days_used, efficiency_rating, maintenance_required) VALUES
(1,1,1,45,9.1,FALSE),
(1,2,3,20,8.0,FALSE),
(4,1,2,60,8.8,TRUE);

INSERT INTO `USAGE` (film_id, equipment_id, usage_start, usage_end) VALUES
(1,1,'2023-04-01','2023-07-31'),
(1,2,'2023-04-01','2023-06-30'),
(4,2,'2024-01-01','2024-06-30');

INSERT INTO ACTOR_AWARD (actor_id, award_name, award_year) VALUES
(1,'Best Actor - Sci-Fi Fest',2024),
(3,'Best Supporting Actor',2020);

INSERT INTO DIRECTOR_AWARD (director_id, award_name, award_year) VALUES
(1,'Visionary Director',2023),
(4,'Best Director - Int. Festival',2022);

INSERT INTO CREW_AWARD (crew_id, award_name, award_year) VALUES
(1,'Best Cinematography',2024),
(3,'Best Editing',2021);
COMMIT;
