# College Internship Tracker using MySQL-Streamlit_DBMS-Mini-Project
The College Internship Tracker is a web-based application developed using Streamlit and MySQL to simplify internship management for students and faculty. 
It provides a unified platform for students, faculty and admin.

- Where students can browse internship postings, apply for opportunities, track their application progress, and maintain personal notes.
- Faculty and Admin members can post, update, or delete job listings and view analytics on student participation and application trends.

Interactive Plotly visualizations display insights such as application status distribution, trends, and success rates — enabling data-driven decision-making for academic institutions.

### **Tech Stack**
1. Frontend UI - Streamlit
2. Backend DB - MySQL
3. Database Connector - `mysql-connector-python`
4. Data Visualization - Plotly
5. Data Handling - Pandas
6. Environment Management - `python-dotenv`

### **Project Structure**
<pre>``` college_internship_tracker/ 
    ├── app.py # Streamlit main application
    ├── college_internship_tracker.sql # MySQL schema + sample data + triggers/functions
    ├── requirements.txt # Dependencies list
    ├── .env # (Create locally, not committed)
    ├── .gitignore # Ignore venv, .env, pycache, etc.
    └── README.md # Project documentation ``` </pre>

### **Secure Setup for Database Credentials**
**Create a .env file (not tracked by Git):**

>    `touch .env` (in mac/linux)
> 
>    `ni .env` (in windows)
> 
>    And then Add this content in the `.env` file
> 
>    Add:
>    ```
>     DB_HOST=localhost
>     DB_USER=root
>     DB_PASSWORD=your_mysql_password
>     DB_NAME=college_internship_tracker
>    ```

### **Database Schema Highlights**

Users — stores students, faculty, and admin details.
Job_Postings — manages internship/job listings posted by faculty.
Applications — tracks student internship applications and status.
Notes & Note_Folders — let students organize and store application notes.
Alerts — automatically generated reminders via triggers for deadlines, assessments, and interviews.
Stored Procedures & Functions — handle job posting creation, application updates, and analytics securely.
Views — pre-defined queries for active application tracking.

### **How to Run the Project**

**1. Set up the database:**

```
mysql -u root -p
SOURCE college_internship_tracker.sql;
```

**2. Install dependencies:**
```
pip install -r requirements.txt
```

**3.Run Streamlit app:**
```
streamlit run app.py
```
