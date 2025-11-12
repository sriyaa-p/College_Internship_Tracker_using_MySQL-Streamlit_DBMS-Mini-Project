CREATE DATABASE college_internship_tracker;
USE college_internship_tracker;

CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role ENUM('student', 'faculty', 'admin') NOT NULL,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE Job_Postings (
    job_id INT PRIMARY KEY AUTO_INCREMENT,
    company_name VARCHAR(150) NOT NULL,
    role VARCHAR(100) NOT NULL,
    description TEXT,
    jd_link VARCHAR(255),
    deadline_date DATE NOT NULL,
    oa_date DATE,
    interview_date DATE,
    posted_by INT,
    FOREIGN KEY (posted_by) REFERENCES Users(user_id)
);

CREATE TABLE Applications (
    application_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    job_id INT NOT NULL,
    status ENUM('to_apply','applied', 'done', 'ignored') NOT NULL DEFAULT 'to_apply',
    applied_on DATETIME DEFAULT NULL,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Users(user_id),
    FOREIGN KEY (job_id) REFERENCES Job_Postings(job_id)
);

CREATE TABLE Notes (
    note_id INT PRIMARY KEY AUTO_INCREMENT,
    application_id INT NOT NULL,
    student_id INT NOT NULL,
    note_text TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES Applications(application_id),
    FOREIGN KEY (student_id) REFERENCES Users(user_id)
);
CREATE TABLE Note_Folders (
    folder_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    folder_name VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Users(user_id)
);

ALTER TABLE Notes
ADD COLUMN folder_id INT NOT NULL,
ADD FOREIGN KEY (folder_id) REFERENCES Note_Folders(folder_id);

-- New DDL for the Alerts table (required for the Trigger/Calendar logic)
CREATE TABLE Alerts (
    alert_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    application_id INT NOT NULL,
    alert_type ENUM('deadline', 'online_assessment', 'interview') NOT NULL, -- What the alert is about
    alert_date DATE NOT NULL,                                             -- When the event is
    reminder_date DATE NOT NULL,                                          -- When the alert should be sent (e.g., 2 days prior)
    message VARCHAR(255) NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE, -- To be used by the external cron job
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (student_id) REFERENCES Users(user_id),
    FOREIGN KEY (application_id) REFERENCES Applications(application_id),
    
    -- Ensures a student doesn't have two 'deadline' alerts for the same application
    UNIQUE KEY (application_id, alert_type) 
);

-- DML commands
-- user_ids start from 1, job_id starts from 3, application_id from 5, 
INSERT INTO Users (name, email, role, password_hash)
VALUES
  ('Asha Sharma', 'asha.sharma@student.college.edu', 'student',  'STUDENT1'),
  ('Ravi Kumar',   'ravi.kumar@student.college.edu',   'student',  'STUDENT2'),
  ('Dr. Mehta',    'mehta.faculty@college.edu',        'faculty',  'FACULTY123'),
  ('Admin Team',   'admin@college.edu',                'admin',    'ADMIN123');
SHOW COLUMNS FROM Users;
SELECT * FROM Users;

-- 2. Inserting into Job Postings
INSERT INTO Job_Postings (company_name, role, description, jd_link, deadline_date, oa_date, interview_date, posted_by)
VALUES
  ('InnovaTech', 'Software Intern', 'Backend development internship.','https://example.com/jd/innova', '2025-11-30', '2025-11-15', '2025-12-05', 3),
  ('GreenAI',   'ML Intern',       'Research & model deployment.','https://example.com/jd/greenai', '2025-12-10', '2025-11-28', '2025-12-12', 3);
SELECT * FROM Job_Postings;

-- 3. Insert into Applications Table
-- Example: student Asha applies to job 1, Ravi has it as "to_apply" (default)
INSERT INTO Applications (student_id, job_id, status, applied_on)
VALUES
(1, 3, 'applied', '2025-10-20 14:30:00'),
(2, 3, 'to_apply', NULL);
SELECT * FROM Applications;

-- 4. Insert into Notes_Folder
INSERT INTO Note_Folders (student_id, folder_name)
VALUES
  (1, 'Interview Prep'),
  (1, 'Applications - 2025'),
  (2, 'Company Research');
SELECT * FROM Note_Folders;

-- 5. Insert Notes
INSERT INTO Notes (application_id, student_id, folder_id, note_text)
VALUES
  (5, 1, 1, 'Read JD: focus on REST API and DB design. Prepare a sample project.'),
  (5, 1, 2, 'Follow up with recruiter if no response by Nov 1.'),
  (6, 2, 3, 'Look into company GreenAI papers and open source repos.');
SELECT * FROM Notes;
SELECT * FROM Notes WHERE note_id IS NULL;
DELETE FROM Notes WHERE note_id IS NULL;


-- 6. Insert into Alert
INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
VALUES
  (1, 5, 'deadline', '2025-11-30', '2025-11-28', 'Application deadline for InnovaTech is approaching!'),
  (1, 5, 'online_assessment', '2025-11-15', '2025-11-13', 'Online assessment for InnovaTech scheduled soon.');
SELECT * FROM Alerts;

-- UPDATE 
-- Student applies now for application_id = 2
UPDATE Applications
SET status = 'applied',
    applied_on = NOW()
WHERE application_id = 6;
SELECT * FROM Applications;

-- Mark application done:
UPDATE Applications
SET status = 'done'
WHERE application_id = 5;
SELECT * FROM Applications;

-- Move a note to a different folder:
UPDATE Notes
SET folder_id = 3
WHERE note_id = 4;
SELECT * FROM Notes;

-- Useful SELECT queries (reporting)
-- List all open job postings ordered by nearest deadline (pagination friendly):
SELECT job_id, company_name, role, deadline_date, jd_link
FROM Job_Postings
WHERE deadline_date >= CURDATE()
ORDER BY deadline_date ASC
LIMIT 20 OFFSET 0;    -- pagination

-- List a student's applications with job details and status:
SELECT a.application_id, a.status, a.applied_on, j.company_name, j.role, j.deadline_date
FROM Applications a
JOIN Job_Postings j ON a.job_id = j.job_id
WHERE a.student_id = 1
ORDER BY a.last_updated DESC;

-- Count applications per job (useful dashboard metric):
SELECT j.job_id, j.company_name, j.role, COUNT(a.application_id) AS num_applications
FROM Job_Postings j
LEFT JOIN Applications a ON j.job_id = a.job_id
GROUP BY j.job_id, j.company_name, j.role
ORDER BY num_applications DESC;

-- Upcoming interviews across all students:
SELECT j.job_id, j.company_name, j.interview_date, a.student_id, a.status
FROM Job_Postings j
JOIN Applications a ON j.job_id = a.job_id
WHERE j.interview_date >= CURDATE()
ORDER BY j.interview_date ASC;

-- Notes for a student's application:
SELECT n.note_id, n.note_text, n.created_at, f.folder_name
FROM Notes n
JOIN Note_Folders f ON n.folder_id = f.folder_id
WHERE n.application_id = 5
ORDER BY n.created_at DESC;

-- apply and create initial note atomically
START TRANSACTION;

-- 1) create application
INSERT INTO Applications (student_id, job_id, status, applied_on)
VALUES (1, 4, 'applied', NOW());
SELECT * FROM Applications;

-- get last inserted application_id (MySQL)
SET @app_id = LAST_INSERT_ID();

-- 2) create a default folder if needed (optional)
-- assume folder_id 2 exists; alternatively create and capture new folder_id

-- 3) create an initial note
INSERT INTO Notes (application_id, student_id, folder_id, note_text)
VALUES (@app_id, 1, 1, 'Applied via portal. Saved confirmation number in attachments.');

COMMIT;

SELECT * FROM Notes;

-- Parameterized / prepared statements (avoid SQL injection)
-- When you execute DML from application code, always use parameterized queries (prepared statements). Example in SQL (server-side prepared statement):

PREPARE apply_stmt FROM
  'INSERT INTO Applications (student_id, job_id, status, applied_on) VALUES (?, ?, ?, ?)';
SET @s_student_id = 1, @s_job_id = 3, @s_status = 'applied', @s_applied_on = NOW();
EXECUTE apply_stmt USING @s_student_id, @s_job_id, @s_status, @s_applied_on;
DEALLOCATE PREPARE apply_stmt;

-- Upsert pattern (INSERT ... ON DUPLICATE KEY UPDATE)
INSERT INTO Job_Postings (job_id, company_name, role, description, deadline_date, posted_by)
VALUES (10, 'Acme', 'Intern', 'desc', '2025-12-01', 3)
ON DUPLICATE KEY UPDATE
  company_name = VALUES(company_name),
  role = VALUES(role),
  description = VALUES(description),
  deadline_date = VALUES(deadline_date);
SELECT * FROM Job_Postings;

-- Functions 
-- Stored Procedures, Functions and Triggers . Views included
DELIMITER //

-- Function 1: Returns the total number of applications (any status) for a given job.
CREATE FUNCTION Get_Application_Count (
    p_job_id INT
)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT;

    -- Count all application records linked to the job ID
    SELECT COUNT(*) INTO v_count
    FROM Applications
    WHERE job_id = p_job_id;

    RETURN v_count;
END //

-- Function 2: Calculates the success ratio (applications marked 'done' / total applications) for a job.
CREATE FUNCTION Calculate_Success_Ratio (
    p_job_id INT
)
RETURNS DECIMAL(5, 2) -- Returns a percentage value (e.g., 25.50)
READS SQL DATA
BEGIN
    DECLARE total_count INT;
    DECLARE done_count INT;
    DECLARE success_ratio DECIMAL(5, 2);

    -- Get the total number of applications for the job
    SELECT COUNT(*) INTO total_count
    FROM Applications
    WHERE job_id = p_job_id;

    -- Get the number of applications marked as 'done' (Success)
    SELECT COUNT(*) INTO done_count
    FROM Applications
    WHERE job_id = p_job_id AND status = 'done';

    IF total_count > 0 THEN
        -- Calculate ratio as a percentage: (Done / Total) * 100
        SET success_ratio = (done_count * 100.0) / total_count;
    ELSE
        SET success_ratio = 0.00;
    END IF;

    RETURN success_ratio;
END //
DELIMITER ;


DELIMITER //
-- Procedure 1: Allows only 'faculty' or 'admin' to create a new Job Posting.
CREATE PROCEDURE Create_Job_Posting (
    IN p_company_name VARCHAR(150),
    IN p_role VARCHAR(100),
    IN p_description TEXT,
    IN p_jd_link VARCHAR(255),
    IN p_deadline_date DATE,
    IN p_oa_date DATE,
    IN p_interview_date DATE,
    IN p_posted_by INT -- User ID of the faculty/admin posting the job
)
BEGIN
    DECLARE user_role ENUM('student', 'faculty', 'admin');
    
    -- Check the role of the user posting the job
    SELECT role INTO user_role FROM Users WHERE user_id = p_posted_by;
    
    -- Check for authorization (Feature 1: Faculty only can post)
    IF user_role IN ('faculty', 'admin') THEN
        -- Insert the new job posting
        INSERT INTO Job_Postings (
            company_name, role, description, jd_link, deadline_date,
            oa_date, interview_date, posted_by
        )
        VALUES (
            p_company_name, p_role, p_description, p_jd_link, p_deadline_date,
            p_oa_date, p_interview_date, p_posted_by
        );
    ELSE
        -- Raise an error if the user is not authorized
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Only faculty or admin can post new jobs.';
    END IF;
END //

-- Procedure 2: Handles all application status changes by a student 
-- (Feature 2: Student can choose to put to_apply; Feature 4: Student can move to done).
CREATE PROCEDURE Set_Application_Status (
    IN p_student_id INT,
    IN p_job_id INT,
    IN p_new_status ENUM('to_apply', 'applied', 'done', 'ignored')
)
BEGIN
    DECLARE existing_app_id INT;
    
    -- Check if an application already exists for this student and job
    SELECT application_id INTO existing_app_id
    FROM Applications
    WHERE student_id = p_student_id AND job_id = p_job_id;
    
    IF existing_app_id IS NULL THEN
        -- If no application exists, create a new one
        INSERT INTO Applications (student_id, job_id, status, applied_on)
        VALUES (p_student_id, p_job_id, p_new_status, IF(p_new_status = 'applied', NOW(), NULL));
        
    ELSE
        -- If application exists, update its status 
        UPDATE Applications
        SET 
            status = p_new_status,
            -- If status is changed to 'applied', set the applied_on timestamp (Trigger 2 will handle alerts)
            applied_on = IF(p_new_status = 'applied' AND status <> 'applied', NOW(), applied_on)
        WHERE application_id = existing_app_id;
    END IF;
END //

-- Procedure 3: Provides key analytics, securely gated to Faculty and Admin.
CREATE PROCEDURE View_Job_Analytics (
    IN p_calling_user_id INT,
    IN p_job_id INT
)
BEGIN
    DECLARE user_role ENUM('student', 'faculty', 'admin');
    
    -- Check the role of the user requesting the analytics
    SELECT role INTO user_role FROM Users WHERE user_id = p_calling_user_id;
    
    IF user_role IN ('faculty', 'admin') THEN
        
        -- Retrieve and combine analytical data using the custom functions
        SELECT
            J.job_id,
            J.company_name,
            J.role,
            -- Functions are called here to get the calculated metrics:
            Get_Application_Count(p_job_id) AS total_applications_tracked,
            (SELECT COUNT(*) FROM Applications A WHERE A.job_id = p_job_id AND A.status = 'applied') AS applied_count,
            (SELECT COUNT(*) FROM Applications A WHERE A.job_id = p_job_id AND A.status = 'done') AS done_count,
            Calculate_Success_Ratio(p_job_id) AS success_ratio_percent
        FROM
            Job_Postings J
        WHERE
            J.job_id = p_job_id;
            
    ELSE
        -- Raise an error if the user is not authorized
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Analytics access is restricted to Faculty and Admin users.';
    END IF;
END //
DELIMITER ;

DELIMITER //
-- Trigger 1: Manages alert creation when a new Application record is INSERTED.
-- Handles auto-pulling dates based on status ('to_apply' or 'applied').
CREATE TRIGGER Alert_Generator_Insert
AFTER INSERT ON Applications
FOR EACH ROW
BEGIN
    
    DECLARE v_deadline DATE;
    DECLARE v_oa_date DATE;
    DECLARE v_interview_date DATE;
    DECLARE v_company_name VARCHAR(150);
    DECLARE v_role VARCHAR(100);

    -- 1. Fetch Job details from Job_Postings
    SELECT 
        deadline_date, 
        oa_date, 
        interview_date,
        company_name,
        role
    INTO 
        v_deadline, 
        v_oa_date, 
        v_interview_date,
        v_company_name,
        v_role
    FROM Job_Postings 
    WHERE job_id = NEW.job_id;

    -- A. Insert DEADLINE alert if application is active ('to_apply' or 'applied')
    IF NEW.status IN ('to_apply', 'applied') AND v_deadline IS NOT NULL THEN
        INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
        VALUES (
            NEW.student_id,
            NEW.application_id,
            'deadline',
            v_deadline,
            DATE_SUB(v_deadline, INTERVAL 2 DAY), -- Reminder 2 days prior
            CONCAT('DEADLINE: ', v_role, ' at ', v_company_name)
        );
    END IF;

    -- B. Only insert OA and INTERVIEW alerts if status is 'applied'
    IF NEW.status = 'applied' THEN
        
        -- Insert Online Assessment (OA) Alert
        IF v_oa_date IS NOT NULL THEN
            INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
            VALUES (
                NEW.student_id,
                NEW.application_id,
                'online_assessment',
                v_oa_date,
                DATE_SUB(v_oa_date, INTERVAL 2 DAY), 
                CONCAT('OA: ', v_role, ' at ', v_company_name)
            );
        END IF;
        
        -- Insert Interview Alert
        IF v_interview_date IS NOT NULL THEN
            INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
            VALUES (
                NEW.student_id,
                NEW.application_id,
                'interview',
                v_interview_date,
                DATE_SUB(v_interview_date, INTERVAL 2 DAY), 
                CONCAT('INTERVIEW: ', v_role, ' at ', v_company_name)
            );
        END IF;
    END IF;

END //

-- Trigger 2: Manages alert updates when an existing Application record is UPDATED (e.g., 'to_apply' -> 'applied').

CREATE TRIGGER Alert_Generator_Update
AFTER UPDATE ON Applications
FOR EACH ROW
BEGIN
    
    DECLARE v_deadline DATE;
    DECLARE v_oa_date DATE;
    DECLARE v_interview_date DATE;
    DECLARE v_company_name VARCHAR(150);
    DECLARE v_role VARCHAR(100);

    -- Only proceed if condition satisfied
    IF NEW.status <> OLD.status THEN

        -- 1. Fetch Job details from Job_Postings
        SELECT 
            deadline_date, 
            oa_date, 
            interview_date,
            company_name,
            role
        INTO 
            v_deadline, 
            v_oa_date, 
            v_interview_date,
            v_company_name,
            v_role
        FROM Job_Postings 
        WHERE job_id = NEW.job_id;

        -- 2. CRITICAL STEP: DELETE all existing alerts for this application
        DELETE FROM Alerts WHERE application_id = NEW.application_id;

        -- 3. --- RE-POPULATE ALERTS BASED ON NEW STATUS ---

        -- A. Always insert DEADLINE alert if application is active ('to_apply' or 'applied')
        IF NEW.status IN ('to_apply', 'applied') AND v_deadline IS NOT NULL THEN
            INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
            VALUES (
                NEW.student_id,
                NEW.application_id,
                'deadline',
                v_deadline,
                DATE_SUB(v_deadline, INTERVAL 2 DAY), 
                CONCAT('DEADLINE: ', v_role, ' at ', v_company_name)
            );
        END IF;

        -- B. Only insert OA and INTERVIEW alerts if status is 'applied'
        IF NEW.status = 'applied' THEN
            
            -- Insert Online Assessment (OA) Alert
            IF v_oa_date IS NOT NULL THEN
                INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
                VALUES (
                    NEW.student_id,
                    NEW.application_id,
                    'online_assessment',
                    v_oa_date,
                    DATE_SUB(v_oa_date, INTERVAL 2 DAY), 
                    CONCAT('OA: ', v_role, ' at ', v_company_name)
                );
            END IF;
            
            -- Insert Interview Alert
            IF v_interview_date IS NOT NULL THEN
                INSERT INTO Alerts (student_id, application_id, alert_type, alert_date, reminder_date, message)
                VALUES (
                    NEW.student_id,
                    NEW.application_id,
                    'interview',
                    v_interview_date,
                    DATE_SUB(v_interview_date, INTERVAL 2 DAY), 
                    CONCAT('INTERVIEW: ', v_role, ' at ', v_company_name)
                );
            END IF;
        END IF;
    
    END IF; 

END //


-- Trigger 3: Synchronizes the Alerts table when an existing Job_Postings record is updated.
-- This handles the necessary data consistency if a Faculty member changes a date later.
CREATE TRIGGER Update_Alerts_On_Job_Update
AFTER UPDATE ON Job_Postings
FOR EACH ROW
BEGIN

    DECLARE v_application_id INT;
    DECLARE done INT DEFAULT FALSE;

    DECLARE app_cursor CURSOR FOR 
        SELECT application_id 
        FROM Applications 
        WHERE job_id = NEW.job_id 
          AND status IN ('to_apply', 'applied'); 

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Only proceed if necessary
    IF NEW.deadline_date <> OLD.deadline_date OR 
       NEW.oa_date <> OLD.oa_date OR 
       NEW.interview_date <> OLD.interview_date 
    THEN

        OPEN app_cursor;

        read_loop: LOOP
            FETCH app_cursor INTO v_application_id;
            
            IF done THEN
                LEAVE read_loop;
            END IF;

            -- Update DEADLINE Alert if the date changed
            IF NEW.deadline_date <> OLD.deadline_date THEN
                UPDATE Alerts
                SET 
                    alert_date = NEW.deadline_date,
                    reminder_date = DATE_SUB(NEW.deadline_date, INTERVAL 2 DAY),
                    is_sent = FALSE 
                WHERE application_id = v_application_id AND alert_type = 'deadline';
            END IF;

            -- Update ONLINE ASSESSMENT Alert if the date changed
            IF NEW.oa_date <> OLD.oa_date THEN
                UPDATE Alerts
                SET 
                    alert_date = NEW.oa_date,
                    reminder_date = DATE_SUB(NEW.oa_date, INTERVAL 2 DAY),
                    is_sent = FALSE
                WHERE application_id = v_application_id AND alert_type = 'online_assessment';
            END IF;

            -- Update INTERVIEW Alert if the date changed
            IF NEW.interview_date <> OLD.interview_date THEN
                UPDATE Alerts
                SET 
                    alert_date = NEW.interview_date,
                    reminder_date = DATE_SUB(NEW.interview_date, INTERVAL 2 DAY),
                    is_sent = FALSE
                WHERE application_id = v_application_id AND alert_type = 'interview';
            END IF;
            
        END LOOP;

        CLOSE app_cursor;
    END IF;
END //

DELIMITER ;

-- View 1: Active Applications for the student dashboard and tracking.
CREATE VIEW Active_Applications_View AS
SELECT
    A.application_id,
    A.student_id,
    U.name AS student_name,
    J.company_name,
    J.role AS job_role,
    A.status,
    A.applied_on,
    J.deadline_date,
    J.oa_date,
    J.interview_date
FROM
    Applications A
JOIN
    Job_Postings J ON A.job_id = J.job_id
JOIN
    Users U ON A.student_id = U.user_id
WHERE
    A.status IN ('to_apply', 'applied') -- Only show applications that are actively being tracked
ORDER BY
    J.deadline_date ASC;