import streamlit as st
import mysql.connector
from mysql.connector import Error
import pandas as pd
from datetime import datetime, timedelta
import plotly.express as px
import plotly.graph_objects as go
import os
from dotenv import load_dotenv

load_dotenv()

# Page configuration
st.set_page_config(
    page_title="College Internship Tracker",
    page_icon="💼",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
    <style>
    .main {
        padding: 0rem 1rem;
    }
    .stAlert {
        padding: 1rem;
        border-radius: 0.5rem;
    }
    div[data-testid="stMetricValue"] {
        font-size: 2rem;
        font-weight: 600;
    }
    .job-card {
        padding: 1.5rem;
        border-radius: 0.5rem;
        border: 1px solid #e0e0e0;
        margin-bottom: 1rem;
        background-color: #ffffff;
    }
    </style>
""", unsafe_allow_html=True)

# Database Configuration - EDIT THESE VALUES
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD')
}

# Database connection function
@st.cache_resource
def get_database_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        if connection.is_connected():
            db_info = connection.get_server_info()
            st.sidebar.success(f"✅ Connected to MySQL Server {db_info}")
            return connection
    except Error as e:
        st.error(f"❌ Error connecting to MySQL Database: {e}")
        st.info("""
        **Troubleshooting Tips:**
        1. Make sure MySQL is running
        2. Check your password in the DB_CONFIG (line 47)
        3. Verify database name: `college_internship_tracker`
        4. Run: `mysql -u root -p` in terminal to test connection
        """)
        return None

# Initialize session state
if 'logged_in' not in st.session_state:
    st.session_state.logged_in = False
if 'user_id' not in st.session_state:
    st.session_state.user_id = None
if 'user_role' not in st.session_state:
    st.session_state.user_role = None
if 'user_name' not in st.session_state:
    st.session_state.user_name = None

# Database query functions
def execute_query(query, params=None, fetch=True):
    """Execute a query and return results"""
    connection = get_database_connection()
    if connection is None:
        return None
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())
        
        if fetch:
            result = cursor.fetchall()
            cursor.close()
            return result
        else:
            connection.commit()
            cursor.close()
            return True
    except Error as e:
        st.error(f"Database query error: {e}")
        return None

def call_procedure(proc_name, params):
    """Call a stored procedure"""
    connection = get_database_connection()
    if connection is None:
        return False
    
    try:
        cursor = connection.cursor()
        cursor.callproc(proc_name, params)
        connection.commit()
        cursor.close()
        return True
    except Error as e:
        st.error(f"Procedure error: {e}")
        return False

# Authentication functions
def login_user(email, password):
    """Authenticate user"""
    # Debug: Check what we're searching for
    st.write(f"DEBUG - Searching for email: '{email}' with password: '{password}'")
    
    query = "SELECT user_id, name, email, role FROM Users WHERE email = %s AND password_hash = %s"
    result = execute_query(query, (email, password))
    
    # Debug: Show query result
    st.write(f"DEBUG - Query returned {len(result) if result else 0} results")
    if result:
        st.write(f"DEBUG - Result: {result}")
    
    if result is None:
        st.error("❌ Database connection failed. Cannot login.")
        return False
    
    if len(result) > 0:
        user = result[0]
        st.session_state.logged_in = True
        st.session_state.user_id = user['user_id']
        st.session_state.user_role = user['role']
        st.session_state.user_name = user['name']
        return True
    return False

def logout_user():
    """Logout user"""
    st.session_state.logged_in = False
    st.session_state.user_id = None
    st.session_state.user_role = None
    st.session_state.user_name = None

# Student Dashboard Functions
def get_student_stats(student_id):
    """Get statistics for student dashboard"""
    stats = {
        'total_jobs': 0,
        'applied': 0,
        'done': 0,
        'to_apply': 0
    }
    
    # Total available jobs
    query = "SELECT COUNT(*) as count FROM Job_Postings WHERE deadline_date >= CURDATE()"
    result = execute_query(query)
    if result:
        stats['total_jobs'] = result[0]['count']
    
    # Student applications by status
    query = """
        SELECT status, COUNT(*) as count 
        FROM Applications 
        WHERE student_id = %s 
        GROUP BY status
    """
    result = execute_query(query, (student_id,))
    if result:
        for row in result:
            stats[row['status']] = row['count']
    
    return stats

def get_upcoming_deadlines(student_id):
    """Get upcoming deadlines for student"""
    query = """
        SELECT 
            a.application_id,
            j.company_name,
            j.role,
            j.deadline_date,
            j.oa_date,
            j.interview_date,
            a.status,
            DATEDIFF(j.deadline_date, CURDATE()) as days_until
        FROM Applications a
        JOIN Job_Postings j ON a.job_id = j.job_id
        WHERE a.student_id = %s 
        AND a.status IN ('applied', 'to_apply')
        AND j.deadline_date >= CURDATE()
        ORDER BY j.deadline_date ASC
    """
    return execute_query(query, (student_id,))

def get_available_jobs(student_id):
    """Get all available jobs with application status"""
    query = """
        SELECT 
            j.*,
            a.application_id,
            a.status as app_status,
            a.applied_on,
            COALESCE(
                (SELECT note_text FROM Notes 
                 WHERE application_id = a.application_id 
                 ORDER BY created_at DESC LIMIT 1), 
                ''
            ) as latest_note
        FROM Job_Postings j
        LEFT JOIN Applications a ON j.job_id = a.job_id AND a.student_id = %s
        WHERE j.deadline_date >= CURDATE()
        ORDER BY j.deadline_date ASC
    """
    return execute_query(query, (student_id,))

def apply_to_job(student_id, job_id):
    """Apply to a job"""
    return call_procedure('Set_Application_Status', [student_id, job_id, 'applied'])

def ignore_job(student_id, job_id):
    """Ignore a job"""
    return call_procedure('Set_Application_Status', [student_id, job_id, 'ignored'])

def mark_as_done(student_id, job_id):
    """Mark application as done"""
    return call_procedure('Set_Application_Status', [student_id, job_id, 'done'])

def add_note(application_id, student_id, note_text):
    """Add a note to an application"""
    # Get or create a default folder
    query = "SELECT folder_id FROM Note_Folders WHERE student_id = %s LIMIT 1"
    result = execute_query(query, (student_id,))
    
    if not result:
        # Create default folder
        query = "INSERT INTO Note_Folders (student_id, folder_name) VALUES (%s, 'General Notes')"
        execute_query(query, (student_id,), fetch=False)
        query = "SELECT folder_id FROM Note_Folders WHERE student_id = %s LIMIT 1"
        result = execute_query(query, (student_id,))
    
    folder_id = result[0]['folder_id']
    
    query = "INSERT INTO Notes (application_id, student_id, folder_id, note_text) VALUES (%s, %s, %s, %s)"
    return execute_query(query, (application_id, student_id, folder_id, note_text), fetch=False)

# Faculty Dashboard Functions
def get_all_jobs():
    """Get all job postings"""
    query = """
        SELECT 
            j.*,
            u.name as posted_by_name,
            (SELECT COUNT(*) FROM Applications WHERE job_id = j.job_id) as total_apps
        FROM Job_Postings j
        LEFT JOIN Users u ON j.posted_by = u.user_id
        ORDER BY j.deadline_date DESC
    """
    return execute_query(query)

def create_job_posting(company_name, role, description, jd_link, deadline, oa_date, interview_date, posted_by):
    """Create a new job posting"""
    return call_procedure('Create_Job_Posting', [
        company_name, role, description, jd_link, deadline, oa_date, interview_date, posted_by
    ])

def update_job_posting(job_id, company_name, role, description, jd_link, deadline, oa_date, interview_date):
    """Update an existing job posting"""
    query = """
        UPDATE Job_Postings 
        SET company_name = %s, role = %s, description = %s, jd_link = %s,
            deadline_date = %s, oa_date = %s, interview_date = %s
        WHERE job_id = %s
    """
    return execute_query(query, (company_name, role, description, jd_link, deadline, oa_date, interview_date, job_id), fetch=False)

def delete_job_posting(job_id):
    """Delete a job posting"""
    query = "DELETE FROM Job_Postings WHERE job_id = %s"
    return execute_query(query, (job_id,), fetch=False)

# Analytics Functions
def get_analytics_data(user_id):
    """Get analytics data for faculty/admin"""
    analytics = {}
    
    # Applications by company
    query = """
        SELECT j.company_name, COUNT(a.application_id) as app_count
        FROM Job_Postings j
        LEFT JOIN Applications a ON j.job_id = a.job_id
        GROUP BY j.company_name
        ORDER BY app_count DESC
        LIMIT 10
    """
    analytics['by_company'] = execute_query(query)
    
    # Application status distribution
    query = """
        SELECT status, COUNT(*) as count
        FROM Applications
        GROUP BY status
    """
    analytics['by_status'] = execute_query(query)
    
    # Timeline data
    query = """
        SELECT 
            DATE_FORMAT(applied_on, '%Y-%m') as month,
            COUNT(*) as count
        FROM Applications
        WHERE applied_on IS NOT NULL
        GROUP BY DATE_FORMAT(applied_on, '%Y-%m')
        ORDER BY month
    """
    analytics['timeline'] = execute_query(query)
    
    return analytics

# Login Page
def show_login_page():
    st.title("🎓 College Internship Tracker")
    
    # Test database connection
    connection = get_database_connection()
    if connection is None:
        st.error("⚠️ Cannot connect to database. Please check your configuration.")
        st.stop()
    
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col2:
        st.markdown("### Login")
        
        email = st.text_input("Email", placeholder="student@college.edu")
        password = st.text_input("Password", type="password", placeholder="Enter your password")
        
        if st.button("Login", use_container_width=True):
            if not email or not password:
                st.warning("⚠️ Please enter both email and password")
            else:
                if login_user(email, password):
                    st.success(f"✅ Welcome, {st.session_state.user_name}!")
                    st.rerun()
                else:
                    st.error("❌ Invalid credentials. Please try again.")
        
        st.markdown("---")
        st.info("""
        **Demo Credentials:**
        - Student: `asha.sharma@student.college.edu` / `STUDENT1`
        - Faculty: `mehta.faculty@college.edu` / `FACULTY123`
        - Admin: `admin@college.edu` / `ADMIN123`
        """)
        
        with st.expander("🔧 Database Connection Help"):
            st.code("""
# Check if MySQL is running:
mysql -u root -p

# Verify database exists:
USE college_internship_tracker;
SHOW TABLES;
SELECT * FROM Users;

# Update password in app.py line 47:
DB_CONFIG = {
    'host': 'localhost',
    'database': 'college_internship_tracker',
    'user': 'root',
    'password': 'YOUR_ACTUAL_PASSWORD'
}
            """)

# Student Dashboard
def show_student_dashboard():
    st.title(f"👨‍🎓 Welcome, {st.session_state.user_name}")
    
    # Get statistics
    stats = get_student_stats(st.session_state.user_id)
    
    # Display metrics
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Total Jobs", stats['total_jobs'], delta="Available")
    with col2:
        st.metric("Applied", stats['applied'], delta="In Progress")
    with col3:
        st.metric("Completed", stats['done'], delta="Success")
    with col4:
        st.metric("To Apply", stats['to_apply'], delta="Pending")
    
    st.markdown("---")
    
    # Upcoming Deadlines
    st.subheader("📅 Upcoming Deadlines")
    deadlines = get_upcoming_deadlines(st.session_state.user_id)
    
    if deadlines:
        for deadline in deadlines:
            days_left = deadline['days_until']
            color = "🔴" if days_left <= 3 else "🟡" if days_left <= 7 else "🟢"
            
            with st.container():
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.markdown(f"**{deadline['company_name']} - {deadline['role']}**")
                    st.caption(f"Deadline: {deadline['deadline_date']} | OA: {deadline['oa_date']} | Interview: {deadline['interview_date']}")
                with col2:
                    st.markdown(f"{color} **{days_left} days left**")
                st.markdown("---")
    else:
        st.info("No upcoming deadlines. Apply to jobs to track them!")
    
    # Available Jobs
    st.subheader("💼 Available Internships")
    jobs = get_available_jobs(st.session_state.user_id)
    
    if jobs:
        for job in jobs:
            with st.container():
                col1, col2 = st.columns([3, 1])
                
                with col1:
                    st.markdown(f"### {job['company_name']}")
                    st.markdown(f"**{job['role']}**")
                    st.write(job['description'])
                    st.caption(f"⏰ Deadline: {job['deadline_date']} | 📝 OA: {job['oa_date']} | 🎤 Interview: {job['interview_date']}")
                    
                    if job['jd_link']:
                        st.markdown(f"[View Job Description]({job['jd_link']})")
                
                with col2:
                    status = job['app_status']
                    
                    if status == 'applied':
                        st.success("✅ Applied")
                        if st.button("Mark as Done", key=f"done_{job['job_id']}"):
                            if mark_as_done(st.session_state.user_id, job['job_id']):
                                st.success("Marked as done!")
                                st.rerun()
                        
                        with st.expander("Add Note"):
                            note = st.text_area("Note", key=f"note_{job['application_id']}")
                            if st.button("Save Note", key=f"save_{job['application_id']}"):
                                if add_note(job['application_id'], st.session_state.user_id, note):
                                    st.success("Note added!")
                                    st.rerun()
                        
                        if job['latest_note']:
                            st.info(f"📝 {job['latest_note']}")
                    
                    elif status == 'done':
                        st.success("🎉 Completed")
                    
                    elif status == 'ignored':
                        st.warning("🚫 Ignored")
                    
                    else:
                        if st.button("Apply", key=f"apply_{job['job_id']}", use_container_width=True):
                            if apply_to_job(st.session_state.user_id, job['job_id']):
                                st.success("Applied successfully!")
                                st.rerun()
                        
                        if st.button("Ignore", key=f"ignore_{job['job_id']}", use_container_width=True):
                            if ignore_job(st.session_state.user_id, job['job_id']):
                                st.info("Job ignored")
                                st.rerun()
                
                st.markdown("---")
    else:
        st.info("No jobs available at the moment.")

# Faculty Dashboard
def show_faculty_dashboard():
    st.title(f"👨‍🏫 Faculty Dashboard - {st.session_state.user_name}")
    
    tab1, tab2 = st.tabs(["📋 Manage Jobs", "➕ Post New Job"])
    
    with tab1:
        st.subheader("Posted Job Openings")
        jobs = get_all_jobs()
        
        if jobs:
            for job in jobs:
                with st.expander(f"{job['company_name']} - {job['role']} ({job['total_apps']} applications)"):
                    col1, col2 = st.columns([3, 1])
                    
                    with col1:
                        st.write(f"**Description:** {job['description']}")
                        st.write(f"**Deadline:** {job['deadline_date']}")
                        st.write(f"**OA Date:** {job['oa_date']}")
                        st.write(f"**Interview Date:** {job['interview_date']}")
                        st.write(f"**Posted by:** {job['posted_by_name']}")
                        if job['jd_link']:
                            st.write(f"**JD Link:** {job['jd_link']}")
                    
                    with col2:
                        if st.button("Edit", key=f"edit_{job['job_id']}"):
                            st.session_state[f'editing_{job["job_id"]}'] = True
                        
                        if st.button("Delete", key=f"delete_{job['job_id']}"):
                            if delete_job_posting(job['job_id']):
                                st.success("Job deleted!")
                                st.rerun()
                    
                    # Edit form
                    if st.session_state.get(f'editing_{job["job_id"]}', False):
                        with st.form(key=f"edit_form_{job['job_id']}"):
                            company = st.text_input("Company", value=job['company_name'])
                            role = st.text_input("Role", value=job['role'])
                            desc = st.text_area("Description", value=job['description'])
                            jd_link = st.text_input("JD Link", value=job['jd_link'] or "")
                            deadline = st.date_input("Deadline", value=job['deadline_date'])
                            oa = st.date_input("OA Date", value=job['oa_date'])
                            interview = st.date_input("Interview Date", value=job['interview_date'])
                            
                            col1, col2 = st.columns(2)
                            with col1:
                                if st.form_submit_button("Update"):
                                    if update_job_posting(job['job_id'], company, role, desc, jd_link, deadline, oa, interview):
                                        st.success("Job updated!")
                                        st.session_state[f'editing_{job["job_id"]}'] = False
                                        st.rerun()
                            with col2:
                                if st.form_submit_button("Cancel"):
                                    st.session_state[f'editing_{job["job_id"]}'] = False
                                    st.rerun()
        else:
            st.info("No jobs posted yet.")
    
    with tab2:
        st.subheader("Post New Internship")
        
        with st.form("new_job_form"):
            company = st.text_input("Company Name*")
            role = st.text_input("Role*")
            description = st.text_area("Job Description*")
            jd_link = st.text_input("JD Link (optional)")
            
            col1, col2, col3 = st.columns(3)
            with col1:
                deadline = st.date_input("Application Deadline*")
            with col2:
                oa_date = st.date_input("Online Assessment Date*")
            with col3:
                interview_date = st.date_input("Interview Date*")
            
            submitted = st.form_submit_button("Post Job", use_container_width=True)
            
            if submitted:
                if company and role and description and deadline and oa_date and interview_date:
                    if create_job_posting(
                        company, role, description, jd_link, 
                        deadline, oa_date, interview_date, 
                        st.session_state.user_id
                    ):
                        st.success("✅ Job posted successfully!")
                        st.rerun()
                else:
                    st.error("Please fill all required fields.")

# Analytics Dashboard
def show_analytics_dashboard():
    st.title(f"📊 Analytics Dashboard")
    
    analytics = get_analytics_data(st.session_state.user_id)
    
    # Summary metrics
    col1, col2, col3 = st.columns(3)
    
    total_apps = sum(item['count'] for item in analytics['by_status']) if analytics['by_status'] else 0
    done_apps = next((item['count'] for item in analytics['by_status'] if item['status'] == 'done'), 0)
    success_rate = (done_apps / total_apps * 100) if total_apps > 0 else 0
    
    with col1:
        st.metric("Total Applications", total_apps, delta="Across all students")
    with col2:
        st.metric("Completed", done_apps, delta="Successful")
    with col3:
        st.metric("Success Rate", f"{success_rate:.1f}%", delta="Overall")
    
    st.markdown("---")
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Applications by Company")
        if analytics['by_company']:
            df_company = pd.DataFrame(analytics['by_company'])
            fig = px.bar(df_company, x='company_name', y='app_count', 
                        labels={'company_name': 'Company', 'app_count': 'Applications'},
                        color='app_count', color_continuous_scale='Blues')
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No application data available.")
    
    with col2:
        st.subheader("Application Status Distribution")
        if analytics['by_status']:
            df_status = pd.DataFrame(analytics['by_status'])
            fig = px.pie(df_status, values='count', names='status', 
                        color_discrete_sequence=['#3b82f6', '#10b981', '#ef4444', '#f59e0b'])
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No status data available.")
    
    st.subheader("Application Timeline")
    if analytics['timeline']:
        df_timeline = pd.DataFrame(analytics['timeline'])
        fig = px.line(df_timeline, x='month', y='count', 
                     labels={'month': 'Month', 'count': 'Applications'},
                     markers=True)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No timeline data available.")

# Main Application
def main():
    if not st.session_state.logged_in:
        show_login_page()
    else:
        # Sidebar
        with st.sidebar:
            st.markdown(f"### 👤 {st.session_state.user_name}")
            st.caption(f"Role: {st.session_state.user_role.upper()}")
            st.markdown("---")
            
            if st.button("🚪 Logout", use_container_width=True):
                logout_user()
                st.rerun()
        
        # Show appropriate dashboard
        if st.session_state.user_role == 'student':
            show_student_dashboard()
        elif st.session_state.user_role in ['faculty', 'admin']:
            tab1, tab2 = st.tabs(["📋 Manage Jobs", "📊 Analytics"])
            with tab1:
                show_faculty_dashboard()
            with tab2:
                show_analytics_dashboard()

if __name__ == "__main__":
    main()