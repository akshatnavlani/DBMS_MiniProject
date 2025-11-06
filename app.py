import streamlit as st
import mysql.connector
from mysql.connector import Error
import pandas as pd
from datetime import datetime, date, timedelta
import plotly.express as px
import plotly.graph_objects as go

# Configure page
st.set_page_config(page_title="Film Database Manager", layout="wide", initial_sidebar_state="expanded")

# Initialize session state
if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False
    st.session_state.user_id = None
    st.session_state.username = None
    st.session_state.user_role = None
    st.session_state.full_name = None
    st.session_state.db_host = 'localhost'
    st.session_state.db_user = 'root'
    st.session_state.db_password = ''
    st.session_state.db_name = 'filmdb'
    st.session_state.db_connected = False

# Database connection function
@st.cache_resource
def get_connection(host, user, password, database):
    """Create and return a database connection"""
    try:
        conn = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            database=database,
            autocommit=False
        )
        return conn
    except Error as e:
        return None

def execute_query(query, params=None, fetch=False):
    """Execute a SQL query with better error handling"""
    try:
        conn = get_connection(
            st.session_state.db_host,
            st.session_state.db_user,
            st.session_state.db_password,
            st.session_state.db_name
        )
        if conn is None:
            st.error("❌ No database connection. Please configure in sidebar.")
            return None
        
        cursor = conn.cursor(dictionary=True)
        
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        
        if fetch:
            result = cursor.fetchall()
            cursor.close()
            conn.commit()
            return result if result else []
        else:
            conn.commit()
            rows_affected = cursor.rowcount
            cursor.close()
            return {"success": True, "rows_affected": rows_affected}
    except mysql.connector.Error as e:
        st.error(f"❌ Query Error: {e.msg if hasattr(e, 'msg') else str(e)}")
        return None
    except Exception as e:
        st.error(f"❌ Unexpected Error: {str(e)}")
        return None

def call_procedure(procedure_name, params=None):
    """Call a stored procedure with error handling"""
    try:
        conn = get_connection(
            st.session_state.db_host,
            st.session_state.db_user,
            st.session_state.db_password,
            st.session_state.db_name
        )
        if conn is None:
            st.error("❌ No database connection. Please configure in sidebar.")
            return None
        
        cursor = conn.cursor(dictionary=True)
        if params:
            cursor.callproc(procedure_name, params)
        else:
            cursor.callproc(procedure_name)
        
        results = []
        for result in cursor.stored_results():
            results.extend(result.fetchall())
        
        conn.commit()
        cursor.close()
        return results if results else [{"success": True}]
    except mysql.connector.Error as e:
        st.error(f"❌ Procedure Error: {e.msg if hasattr(e, 'msg') else str(e)}")
        return None
    except Exception as e:
        st.error(f"❌ Unexpected Error: {str(e)}")
        return None

def authenticate_user(username, password):
    """Authenticate user against database"""
    result = execute_query(
        "SELECT fn_authenticate_user(%s, %s) as user_id",
        (username, password),
        fetch=True
    )
    
    if result and result[0]['user_id']:
        user_id = result[0]['user_id']
        
        if user_id == -1:
            return None, "Invalid username or password"
        elif user_id == -2:
            return None, "Account is locked due to multiple failed login attempts"
        elif user_id == -3:
            return None, "Account is inactive"
        else:
            # Get user details
            user_details = execute_query(
                "SELECT user_id, username, full_name, role FROM DB_USERS WHERE user_id = %s",
                (user_id,),
                fetch=True
            )
            if user_details:
                # Update login time
                call_procedure("sp_update_login", [user_id, True, "127.0.0.1"])
                return user_details[0], None
    
    return None, "Authentication failed"

def logout():
    """Logout user"""
    st.session_state.authenticated = False
    st.session_state.user_id = None
    st.session_state.username = None
    st.session_state.user_role = None
    st.session_state.full_name = None
    st.rerun()

def check_permission(operation='read'):
    """Check if user has permission for operation"""
    if operation == 'read':
        return True  # All roles can read
    elif operation in ['create', 'update', 'delete']:
        return st.session_state.user_role in ['admin', 'manager']
    return False

# =====================
# LOGIN PAGE
# =====================
if not st.session_state.authenticated:
    st.title("🎬 Film Database Management System")
    st.markdown("---")
    
    # Database configuration
    with st.expander("⚙️ Database Configuration", expanded=not st.session_state.db_connected):
        col1, col2 = st.columns(2)
        with col1:
            st.session_state.db_host = st.text_input("Host", st.session_state.db_host)
            st.session_state.db_user = st.text_input("DB User", st.session_state.db_user)
        with col2:
            st.session_state.db_password = st.text_input("DB Password", st.session_state.db_password, type="password")
            st.session_state.db_name = st.text_input("Database", st.session_state.db_name)
        
        if st.button("Test Connection"):
            conn = get_connection(
                st.session_state.db_host,
                st.session_state.db_user,
                st.session_state.db_password,
                st.session_state.db_name
            )
            if conn and conn.is_connected():
                st.session_state.db_connected = True
                st.success("✓ Connected to database successfully!")
            else:
                st.error("❌ Connection failed. Please check your credentials.")
    
    if st.session_state.db_connected:
        st.markdown("### 🔐 Login")
        
        col1, col2, col3 = st.columns([1, 2, 1])
        
        with col2:
            with st.form("login_form"):
                username = st.text_input("Username", placeholder="Enter your username")
                password = st.text_input("Password", type="password", placeholder="Enter your password")
                submit = st.form_submit_button("Login", use_container_width=True)
                
                if submit:
                    if username and password:
                        user, error = authenticate_user(username, password)
                        
                        if user:
                            st.session_state.authenticated = True
                            st.session_state.user_id = user['user_id']
                            st.session_state.username = user['username']
                            st.session_state.user_role = user['role']
                            st.session_state.full_name = user['full_name']
                            st.success(f"✓ Welcome, {user['full_name']}!")
                            st.rerun()
                        else:
                            st.error(f"❌ {error}")
                    else:
                        st.warning("Please enter both username and password")
            
            st.info("💡 Default credentials: **admin** / **Admin@123**")
            
            with st.expander("ℹ️ User Roles Information"):
                st.markdown("""
                **Admin**: Full access including user management  
                **Manager**: Can perform CRUD operations on all entities  
                **Viewer**: Read-only access to all data
                """)
    else:
        st.warning("⚠️ Please configure and test database connection first")
    
    st.stop()

# =====================
# AUTHENTICATED SECTION
# =====================

# Sidebar with user info and navigation
st.sidebar.title("🎬 Film Database Manager")
st.sidebar.markdown(f"**User:** {st.session_state.full_name}")
st.sidebar.markdown(f"**Role:** {st.session_state.user_role.upper()}")
st.sidebar.markdown(f"**Username:** {st.session_state.username}")

if st.sidebar.button("🚪 Logout"):
    logout()

st.sidebar.divider()

# Navigation based on role
navigation_options = ["Dashboard", "Film Management", "Cast & Roles", "Analytics & Reports"]

if st.session_state.user_role in ['admin', 'manager']:
    navigation_options.extend([
        "Director Operations",
        "Producer Analytics",
        "Crew Management",
        "Equipment & Locations",
        "Database Operations"
    ])

if st.session_state.user_role == 'admin':
    navigation_options.extend(["User Management", "Audit & Logs"])

page = st.sidebar.radio("Navigate", navigation_options)

st.sidebar.divider()
st.sidebar.caption(f"Session: {datetime.now().strftime('%Y-%m-%d %H:%M')}")

# =====================
# USER MANAGEMENT (Admin Only)
# =====================
if page == "User Management":
    if st.session_state.user_role != 'admin':
        st.error("🚫 Access Denied: This page is only accessible to administrators")
        st.stop()
    
    st.header("👥 User Management")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Create User", "View Users", "User Activity", "Manage Users"])
    
    with tab1:
        st.subheader("Create New User")
        
        with st.form("create_user_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                new_username = st.text_input("Username*", help="Unique username for login")
                new_full_name = st.text_input("Full Name*", help="User's full name")
                new_email = st.text_input("Email*", help="User's email address")
            
            with col2:
                new_password = st.text_input("Password*", type="password", help="Minimum 8 characters")
                confirm_password = st.text_input("Confirm Password*", type="password")
                new_role = st.selectbox("Role*", ["viewer", "manager", "admin"],
                    help="viewer: Read-only, manager: CRUD operations, admin: Full access")
            
            st.markdown("**Role Descriptions:**")
            st.markdown("- **Viewer**: Can only view data, no modifications")
            st.markdown("- **Manager**: Can create, update, and delete records")
            st.markdown("- **Admin**: Full system access including user management")
            
            submit = st.form_submit_button("Create User", use_container_width=True)
            
            if submit:
                if not all([new_username, new_full_name, new_email, new_password, confirm_password]):
                    st.error("❌ All fields are required")
                elif new_password != confirm_password:
                    st.error("❌ Passwords do not match")
                elif len(new_password) < 8:
                    st.error("❌ Password must be at least 8 characters")
                else:
                    try:
                        result = call_procedure("sp_create_user", [
                            st.session_state.user_id,
                            new_username,
                            new_password,
                            new_full_name,
                            new_email,
                            new_role
                        ])
                        
                        if result:
                            st.success(f"✓ User '{new_username}' created successfully!")
                            st.balloons()
                    except Exception as e:
                        if "Only administrators can create users" in str(e):
                            st.error("❌ Only administrators can create users")
                        elif "Duplicate entry" in str(e):
                            st.error("❌ Username or email already exists")
                        else:
                            st.error(f"❌ Error creating user: {str(e)}")
    
    with tab2:
        st.subheader("All Users")
        
        try:
            users = call_procedure("sp_get_all_users", [st.session_state.user_id])
            
            if users:
                df = pd.DataFrame(users)
                
                # Format the dataframe
                df['is_active'] = df['is_active'].apply(lambda x: '✅ Active' if x else '❌ Inactive')
                df['account_locked'] = df['account_locked'].apply(lambda x: '🔒 Locked' if x else '🔓 Unlocked')
                df['last_login'] = pd.to_datetime(df['last_login']).dt.strftime('%Y-%m-%d %H:%M')
                df['created_at'] = pd.to_datetime(df['created_at']).dt.strftime('%Y-%m-%d %H:%M')
                
                st.dataframe(df, use_container_width=True, hide_index=True)
                
                # User statistics
                st.divider()
                col1, col2, col3, col4 = st.columns(4)
                with col1:
                    st.metric("Total Users", len(df))
                with col2:
                    admin_count = len(df[df['role'] == 'admin'])
                    st.metric("Administrators", admin_count)
                with col3:
                    active_count = len(df[df['is_active'] == '✅ Active'])
                    st.metric("Active Users", active_count)
                with col4:
                    locked_count = len(df[df['account_locked'] == '🔒 Locked'])
                    st.metric("Locked Accounts", locked_count)
            else:
                st.info("No users found")
        except Exception as e:
            st.error(f"Error loading users: {str(e)}")
    
    with tab3:
        st.subheader("User Activity Summary")
        
        activity = execute_query("SELECT * FROM view_user_activity_summary ORDER BY last_activity DESC", fetch=True)
        
        if activity:
            df = pd.DataFrame(activity)
            df['last_activity'] = pd.to_datetime(df['last_activity']).dt.strftime('%Y-%m-%d %H:%M')
            st.dataframe(df, use_container_width=True, hide_index=True)
            
            st.divider()
            
            # Activity visualizations
            col1, col2 = st.columns(2)
            
            with col1:
                fig = px.bar(df, x='username', y='successful_logins', 
                           title="Successful Logins by User",
                           labels={'successful_logins': 'Logins', 'username': 'User'})
                st.plotly_chart(fig, use_container_width=True)
            
            with col2:
                fig = px.pie(df, values='total_activities', names='username',
                           title="Activity Distribution by User")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No activity data found")
    
    with tab4:
        st.subheader("Manage User Status")
        
        users = execute_query(
            "SELECT user_id, username, full_name, role, is_active FROM DB_USERS WHERE username != 'admin' ORDER BY full_name",
            fetch=True
        )
        
        if users:
            user_select = st.selectbox(
                "Select User",
                options=users,
                format_func=lambda x: f"{x['full_name']} ({x['username']}) - {x['role']}"
            )
            
            if user_select:
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("#### Activate/Deactivate User")
                    current_status = "Active" if user_select['is_active'] else "Inactive"
                    st.info(f"Current Status: **{current_status}**")
                    
                    new_status = st.radio(
                        "New Status",
                        [True, False],
                        format_func=lambda x: "Active" if x else "Inactive",
                        key="status_radio"
                    )
                    
                    if st.button("Update Status"):
                        try:
                            result = call_procedure("sp_update_user_status", [
                                st.session_state.user_id,
                                user_select['user_id'],
                                new_status
                            ])
                            if result:
                                st.success("✓ User status updated!")
                                st.rerun()
                        except Exception as e:
                            st.error(f"Error: {str(e)}")
                
                with col2:
                    st.markdown("#### Delete User")
                    st.warning("⚠️ This action cannot be undone!")
                    
                    confirm = st.checkbox("I confirm I want to delete this user")
                    
                    if st.button("Delete User", disabled=not confirm, type="primary"):
                        try:
                            result = call_procedure("sp_delete_user", [
                                st.session_state.user_id,
                                user_select['user_id']
                            ])
                            if result:
                                st.success("✓ User deleted successfully!")
                                st.rerun()
                        except Exception as e:
                            if "Cannot delete the last active administrator" in str(e):
                                st.error("❌ Cannot delete the last active administrator")
                            else:
                                st.error(f"Error: {str(e)}")
        else:
            st.info("No manageable users found")

# =====================
# DASHBOARD
# =====================
elif page == "Dashboard":
    st.header("🎬 Film Production Dashboard")
    
    if not st.session_state.db_connected:
        st.warning("⚠️ Please connect to database first (see sidebar)")
    else:
        # Key metrics
        col1, col2, col3, col4 = st.columns(4)
        
        total_films = execute_query("SELECT COUNT(*) as count FROM FILM", fetch=True)
        total_actors = execute_query("SELECT COUNT(*) as count FROM ACTOR", fetch=True)
        total_budget = execute_query("SELECT SUM(budget) as total FROM FILM", fetch=True)
        total_boxoffice = execute_query("SELECT SUM(boxoffice_collection) as total FROM FILM", fetch=True)
        
        with col1:
            st.metric("📽️ Total Films", total_films[0]['count'] if total_films else 0)
        with col2:
            st.metric("👥 Total Actors", total_actors[0]['count'] if total_actors else 0)
        with col3:
            budget_val = total_budget[0]['total'] if total_budget and total_budget[0]['total'] else 0
            st.metric("💰 Total Budget", f"${budget_val:,.0f}")
        with col4:
            boxoffice_val = total_boxoffice[0]['total'] if total_boxoffice and total_boxoffice[0]['total'] else 0
            st.metric("🎟️ Total Box Office", f"${boxoffice_val:,.0f}")
        
        st.divider()
        
        col1, col2 = st.columns(2)
        
        # Film Status Distribution
        with col1:
            st.subheader("Production Status")
            status_data = execute_query(
                "SELECT production_status, COUNT(*) as count FROM FILM GROUP BY production_status",
                fetch=True
            )
            if status_data:
                df = pd.DataFrame(status_data)
                fig = px.pie(df, values='count', names='production_status', 
                            title="Films by Production Status")
                st.plotly_chart(fig, use_container_width=True)
        
        # Top Grossing Films
        with col2:
            st.subheader("Top Grossing Films")
            top_films = execute_query(
                """SELECT title, boxoffice_collection FROM FILM 
                   WHERE boxoffice_collection > 0 
                   ORDER BY boxoffice_collection DESC LIMIT 5""",
                fetch=True
            )
            if top_films:
                df = pd.DataFrame(top_films)
                fig = px.bar(df, x='title', y='boxoffice_collection',
                            title="Top 5 Grossing Films")
                st.plotly_chart(fig, use_container_width=True)
        
        # Film Profitability Analysis
        st.subheader("Film Profitability Analysis")
        profit_data = execute_query(
            """SELECT f.title, f.budget, f.boxoffice_collection,
                      fn_calculate_film_profit(f.film_id) as profit,
                      fn_calculate_film_roi(f.film_id) as roi
               FROM FILM f WHERE f.boxoffice_collection > 0
               ORDER BY profit DESC""",
            fetch=True
        )
        if profit_data:
            df = pd.DataFrame(profit_data)
            df['budget'] = pd.to_numeric(df['budget'], errors='coerce')
            df['boxoffice_collection'] = pd.to_numeric(df['boxoffice_collection'], errors='coerce')
            df['profit'] = pd.to_numeric(df['profit'], errors='coerce')
            df['roi'] = pd.to_numeric(df['roi'], errors='coerce')
            
            col1, col2 = st.columns(2)
            with col1:
                fig = px.bar(df, x='title', y='profit', title="Profit by Film")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                fig = px.bar(df, x='title', y='roi', title="ROI % by Film")
                st.plotly_chart(fig, use_container_width=True)

# =====================
# FILM MANAGEMENT
# =====================
elif page == "Film Management":
    st.header("🎥 Film Management")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Add Film", "View Films", "Update Film", "Film Details"])
    
    with tab1:
        st.subheader("Add New Film with Genres")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to create films")
        else:
            with st.form("add_film"):
                col1, col2 = st.columns(2)
                
                with col1:
                    title = st.text_input("Film Title")
                    budget = st.number_input("Budget ($)", min_value=100000, step=100000)
                    duration = st.number_input("Duration (minutes)", min_value=30, step=5)
                    language = st.text_input("Language", "English")
                
                with col2:
                    directors = execute_query("SELECT director_id, name FROM DIRECTOR", fetch=True)
                    if directors:
                        director = st.selectbox("Director", options=directors, 
                                              format_func=lambda x: x['name'])
                        director_id = director['director_id']
                    else:
                        director_id = 1
                        st.warning("No directors found")
                    
                    release_date = st.date_input("Release Date")
                    genres = st.multiselect("Genres", 
                        ["Action", "Drama", "Sci-Fi", "Comedy", "Thriller", "Adventure", "Horror", "Romance"])
                
                if st.form_submit_button("Add Film"):
                    try:
                        if budget < 100000:
                            st.error("❌ Trigger Validation: Minimum film budget is $100,000")
                        else:
                            genres_str = ", ".join(genres) if genres else "Drama"
                            result = call_procedure("sp_add_film_with_genres", 
                                [title, budget, duration, director_id, language, genres_str])
                            if result:
                                st.success(f"✓ Film '{title}' added successfully!")
                                st.balloons()
                    except Exception as e:
                        st.error(f"Error: {str(e)}")
    
    with tab2:
        st.subheader("All Films")
        films = execute_query(
            """SELECT f.film_id, f.title, f.release_date, f.budget, 
                      f.boxoffice_collection, f.rating, f.production_status,
                      d.name as director FROM FILM f
               LEFT JOIN DIRECTOR d ON f.FK_director_id = d.director_id
               ORDER BY f.release_date DESC""",
            fetch=True
        )
        if films:
            df = pd.DataFrame(films)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No films found")
    
    with tab3:
        st.subheader("Update Film Information")
        
        if not check_permission('update'):
            st.warning("🚫 You don't have permission to update films")
        else:
            films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
            if films:
                film = st.selectbox("Select Film", options=films, format_func=lambda x: x['title'])
                if film:
                    col1, col2, col3 = st.columns(3)
                    
                    with col1:
                        new_boxoffice = st.number_input("Box Office Collection ($)", min_value=0)
                    with col2:
                        new_rating = st.slider("Rating", 0.0, 10.0, step=0.1)
                    with col3:
                        new_status = st.selectbox("Status", 
                            ["Pre-Production", "In Progress", "Post-Production", "Released"])
                    
                    if st.button("Update Film"):
                        execute_query(
                            """UPDATE FILM 
                               SET boxoffice_collection=%s, rating=%s, production_status=%s 
                               WHERE film_id=%s""",
                            (new_boxoffice, new_rating, new_status, film['film_id'])
                        )
                        st.success("✓ Film updated!")
    
    with tab4:
        st.subheader("Film Production Summary")
        films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
        if films:
            film = st.selectbox("Select Film for Details", options=films, 
                              format_func=lambda x: x['title'], key="film_details")
            if film:
                summary = call_procedure("sp_get_film_production_summary", [film['film_id']])
                if summary:
                    s = summary[0]
                    col1, col2, col3, col4 = st.columns(4)
                    with col1:
                        st.metric("Director", s.get('director', 'N/A'))
                    with col2:
                        st.metric("Actors", s.get('total_actors', 0))
                    with col3:
                        st.metric("Scenes", s.get('total_scenes', 0))
                    with col4:
                        st.metric("Locations", s.get('total_locations', 0))
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        st.metric("Crew Members", s.get('total_crew', 0))
                    with col2:
                        st.metric("Budget", f"${s.get('budget', 0):,.0f}")

# =====================
# CAST & ROLES
# =====================
elif page == "Cast & Roles":
    st.header("👥 Cast & Roles Management")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Add Actor", "Cast in Film", "View Actors", "Actor Filmography"])
    
    with tab1:
        st.subheader("Add New Actor")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to add actors")
        else:
            with st.form("add_actor"):
                col1, col2 = st.columns(2)
                
                with col1:
                    first_name = st.text_input("First Name")
                    last_name = st.text_input("Last Name")
                    stage_name = st.text_input("Stage Name (Optional)")
                
                with col2:
                    dob = st.date_input("Date of Birth", value=date(1990, 1, 1))
                    gender = st.selectbox("Gender", ["M", "F", "Other"])
                    nationality = st.text_input("Nationality")
                
                languages = st.multiselect("Languages", 
                    ["English", "Spanish", "French", "German", "Italian", "Mandarin", "Japanese"])
                
                if st.form_submit_button("Add Actor"):
                    age = datetime.now().year - dob.year
                    if age < 18:
                        st.error("❌ Trigger Validation: Actor must be at least 18 years old")
                    else:
                        result = execute_query(
                            """INSERT INTO ACTOR (first_name, last_name, dob, gender, nationality, stage_name)
                               VALUES (%s, %s, %s, %s, %s, %s)""",
                            (first_name, last_name, dob, gender, nationality, stage_name)
                        )
                        if result and result.get("success"):
                            st.success(f"✓ Actor {first_name} {last_name} added!")
                            if languages:
                                actor = execute_query(
                                    "SELECT actor_id FROM ACTOR ORDER BY actor_id DESC LIMIT 1",
                                    fetch=True
                                )
                                if actor:
                                    for lang in languages:
                                        execute_query(
                                            "INSERT INTO ACTOR_LANGUAGE (actor_id, language) VALUES (%s, %s)",
                                            (actor[0]['actor_id'], lang)
                                        )
    
    with tab2:
        st.subheader("Cast Actor in Film")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to cast actors")
        else:
            actors = execute_query(
                "SELECT actor_id, CONCAT(first_name, ' ', last_name) as name FROM ACTOR",
                fetch=True
            )
            films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
            
            if actors and films:
                with st.form("cast_actor"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        actor = st.selectbox("Select Actor", options=actors, 
                                            format_func=lambda x: x['name'])
                        film = st.selectbox("Select Film", options=films, 
                                           format_func=lambda x: x['title'])
                    
                    with col2:
                        character_name = st.text_input("Character Name")
                        importance = st.selectbox("Importance", ["Lead", "Supporting", "Cameo"])
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        screen_time = st.number_input("Screen Time (minutes)", min_value=0)
                    with col2:
                        salary = st.number_input("Salary ($)", min_value=0, step=1000)
                    
                    if st.form_submit_button("Cast Actor"):
                        try:
                            if salary < 0:
                                st.error("❌ Trigger Validation: Salary cannot be negative")
                            else:
                                result = execute_query(
                                    """INSERT INTO ROLE (actor_id, film_id, character_name, screen_time, importance, salary)
                                       VALUES (%s, %s, %s, %s, %s, %s)""",
                                    (actor['actor_id'], film['film_id'], character_name, screen_time, importance, salary)
                                )
                                if result and result.get("success"):
                                    st.success(f"✓ {actor['name']} cast as {character_name}!")
                        except Exception as e:
                            st.error(f"Error: {str(e)}")
    
    with tab3:
        st.subheader("All Actors")
        actors = execute_query(
            """SELECT a.actor_id, CONCAT(a.first_name, ' ', a.last_name) as name,
                      a.nationality, a.dob, fn_get_actor_age(a.actor_id) as age,
                      COUNT(DISTINCT r.film_id) as films
               FROM ACTOR a
               LEFT JOIN ROLE r ON a.actor_id = r.actor_id
               GROUP BY a.actor_id, a.first_name, a.last_name, a.nationality, a.dob
               ORDER BY a.first_name""",
            fetch=True
        )
        if actors:
            df = pd.DataFrame(actors)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No actors found")
    
    with tab4:
        st.subheader("Actor Filmography")
        actors = execute_query(
            "SELECT actor_id, CONCAT(first_name, ' ', last_name) as name FROM ACTOR",
            fetch=True
        )
        if actors:
            actor = st.selectbox("Select Actor", options=actors, 
                                format_func=lambda x: x['name'], key="actor_filmography")
            if st.button("View Filmography"):
                filmography = call_procedure("sp_get_actor_filmography", [actor['actor_id']])
                if filmography:
                    df = pd.DataFrame(filmography)
                    st.dataframe(df, use_container_width=True, hide_index=True)
                else:
                    st.info("No films found for this actor")

# =====================
# DIRECTOR OPERATIONS
# =====================
elif page == "Director Operations":
    st.header("🎬 Director Operations")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Directors", "Filmography with Profit", "By Specialty", "Awards"])
    
    with tab1:
        st.subheader("All Directors")
        directors = execute_query(
            """SELECT d.director_id, d.name, d.nationality, d.dob,
                      COUNT(f.film_id) as films,
                      SUM(f.budget) as total_budget,
                      SUM(f.boxoffice_collection) as total_boxoffice
               FROM DIRECTOR d
               LEFT JOIN FILM f ON d.director_id = f.FK_director_id
               GROUP BY d.director_id, d.name, d.nationality, d.dob
               ORDER BY d.name""",
            fetch=True
        )
        if directors:
            df = pd.DataFrame(directors)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No directors found")
    
    with tab2:
        st.subheader("Director Filmography with Profitability")
        directors = execute_query("SELECT director_id, name FROM DIRECTOR", fetch=True)
        if directors:
            director = st.selectbox("Select Director", options=directors, 
                                   format_func=lambda x: x['name'])
            if director:
                filmography = call_procedure("sp_get_director_filmography_with_profit", 
                                            [director['director_id']])
                if filmography:
                    df = pd.DataFrame(filmography)
                    df['budget'] = pd.to_numeric(df['budget'], errors='coerce')
                    df['boxoffice_collection'] = pd.to_numeric(df['boxoffice_collection'], errors='coerce')
                    df['profit'] = pd.to_numeric(df['profit'], errors='coerce')
                    df['roi_percentage'] = pd.to_numeric(df['roi_percentage'], errors='coerce')
                    df['rating'] = pd.to_numeric(df['rating'], errors='coerce')
                    
                    st.dataframe(df, use_container_width=True, hide_index=True)
                    
                    if not df.empty:
                        col1, col2 = st.columns(2)
                        with col1:
                            fig = px.bar(df, x='title', y='profit', title="Profit by Film")
                            st.plotly_chart(fig, use_container_width=True)
                        with col2:
                            fig = px.bar(df, x='title', y='roi_percentage', title="ROI % by Film",
                                       color='roi_percentage',
                                       color_continuous_scale='Viridis')
                            st.plotly_chart(fig, use_container_width=True)
    
    with tab3:
        st.subheader("Directors by Specialization")
        specializations = execute_query(
            """SELECT ds.specialization, d.name, ds.years_experience
               FROM DIRECTOR_SPECIALIZATION ds
               JOIN DIRECTOR d ON ds.director_id = d.director_id
               ORDER BY ds.specialization, d.name""",
            fetch=True
        )
        if specializations:
            df = pd.DataFrame(specializations)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No specializations found")
    
    with tab4:
        st.subheader("Director Awards")
        awards = execute_query(
            """SELECT d.name, da.award_name, da.award_year
               FROM DIRECTOR_AWARD da
               JOIN DIRECTOR d ON da.director_id = d.director_id
               ORDER BY da.award_year DESC""",
            fetch=True
        )
        if awards:
            df = pd.DataFrame(awards)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No awards found")

# =====================
# PRODUCER ANALYTICS
# =====================
elif page == "Producer Analytics":
    st.header("💼 Producer Analytics")
    
    tab1, tab2, tab3 = st.tabs(["All Producers", "Investment Details", "Performance"])
    
    with tab1:
        st.subheader("Producer Portfolio")
        producers = execute_query(
            """SELECT p.producer_id, p.name, p.company,
                      COUNT(DISTINCT pb.film_id) as films,
                      SUM(pb.investment) as total_investment,
                      AVG(pb.investment) as avg_investment
               FROM PRODUCER p
               LEFT JOIN PRODUCED_BY pb ON p.producer_id = pb.producer_id
               GROUP BY p.producer_id, p.name, p.company
               ORDER BY total_investment DESC""",
            fetch=True
        )
        if producers:
            df = pd.DataFrame(producers)
            st.dataframe(df, use_container_width=True, hide_index=True)
            
            fig = px.bar(df, x='name', y='total_investment', title="Total Investment by Producer")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No producers found")
    
    with tab2:
        st.subheader("Detailed Investment Analysis")
        producers = execute_query("SELECT producer_id, name FROM PRODUCER", fetch=True)
        if producers:
            producer = st.selectbox("Select Producer", options=producers, 
                                   format_func=lambda x: x['name'])
            if producer:
                result = call_procedure("sp_calculate_producer_investment", 
                                       [producer['producer_id']])
                if result:
                    r = result[0]
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.metric("Total Films", r.get('total_films', 0))
                    with col2:
                        st.metric("Total Investment", f"${r.get('total_investment', 0):,.0f}")
                    with col3:
                        st.metric("Avg Investment", f"${r.get('avg_investment', 0):,.0f}")
    
    with tab3:
        st.subheader("Distributor Performance")
        performance = call_procedure("sp_get_distributor_performance")
        if performance:
            df = pd.DataFrame(performance)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No distributor data found")

# =====================
# CREW MANAGEMENT
# =====================
elif page == "Crew Management":
    st.header("👷 Crew Management")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Allocate Crew", "View Crew", "By Department", "Payroll"])
    
    with tab1:
        st.subheader("Allocate Crew to Film")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to allocate crew")
        else:
            crews = execute_query("SELECT crew_id, name, role, department FROM CREW", fetch=True)
            films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
            
            if crews and films:
                with st.form("allocate_crew"):
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        crew = st.selectbox("Select Crew", options=crews, 
                                           format_func=lambda x: f"{x['name']} ({x['role']})")
                        film = st.selectbox("Select Film", options=films, 
                                           format_func=lambda x: x['title'])
                    
                    with col2:
                        start_date = st.date_input("Start Date")
                        end_date = st.date_input("End Date", value=start_date + timedelta(days=30))
                    
                    if st.form_submit_button("Allocate Crew"):
                        try:
                            result = execute_query(
                                """INSERT INTO WORKS_ON (crew_id, film_id, start_date, end_date, department)
                                   SELECT %s, %s, %s, %s, department FROM CREW WHERE crew_id = %s""",
                                (crew['crew_id'], film['film_id'], start_date, end_date, crew['crew_id'])
                            )
                            if result and result.get("success"):
                                st.success("✓ Crew allocated successfully!")
                        except Exception as e:
                            st.error(f"Error: {str(e)}")
    
    with tab2:
        st.subheader("All Crew Members")
        crews = execute_query(
            """SELECT crew_id, name, role, department, experience_years FROM CREW
               ORDER BY department, name""",
            fetch=True
        )
        if crews:
            df = pd.DataFrame(crews)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No crew members found")
    
    with tab3:
        st.subheader("Crew by Department")
        dept_data = execute_query(
            """SELECT department, COUNT(*) as count, AVG(experience_years) as avg_exp
               FROM CREW WHERE department IS NOT NULL
               GROUP BY department ORDER BY department""",
            fetch=True
        )
        if dept_data:
            df = pd.DataFrame(dept_data)
            col1, col2 = st.columns(2)
            with col1:
                fig = px.bar(df, x='department', y='count', title="Crew Count by Department")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                fig = px.bar(df, x='department', y='avg_exp', title="Avg Experience by Department")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No department data found")
    
    with tab4:
        st.subheader("Film Crew Payroll")
        films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
        if films:
            film = st.selectbox("Select Film", options=films, 
                               format_func=lambda x: x['title'], key="crew_payroll")
            if film:
                payroll = call_procedure("sp_get_film_crew_payroll", [film['film_id']])
                if payroll:
                    df = pd.DataFrame(payroll)
                    st.dataframe(df, use_container_width=True, hide_index=True)
                else:
                    st.info("No payroll data found")

# =====================
# EQUIPMENT & LOCATIONS
# =====================
elif page == "Equipment & Locations":
    st.header("⚙️ Equipment & Locations")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Equipment Status", "Add Equipment", "Locations", "Equipment Usage"])
    
    with tab1:
        st.subheader("Equipment Availability Status")
        equipment = execute_query(
            """SELECT e.equipment_id, e.name, e.type, e.cost, e.availability, e.`condition`,
                      COUNT(DISTINCT fce.film_id) as films_used,
                      AVG(fce.efficiency_rating) as avg_efficiency
               FROM EQUIPMENT e
               LEFT JOIN FILM_CREW_EQUIPMENT fce ON e.equipment_id = fce.equipment_id
               GROUP BY e.equipment_id, e.name, e.type, e.cost, e.availability, e.`condition`""",
            fetch=True
        )
        if equipment:
            df = pd.DataFrame(equipment)
            st.dataframe(df, use_container_width=True, hide_index=True)
            
            col1, col2 = st.columns(2)
            with col1:
                avail_data = df['availability'].value_counts()
                fig = px.pie(values=avail_data.values, names=avail_data.index,
                            title="Equipment Availability Status")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                fig = px.bar(df, x='name', y='avg_efficiency', title="Equipment Efficiency Rating")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No equipment found")
    
    with tab2:
        st.subheader("Add New Equipment")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to add equipment")
        else:
            with st.form("add_equipment"):
                col1, col2 = st.columns(2)
                
                with col1:
                    name = st.text_input("Equipment Name")
                    equip_type = st.text_input("Equipment Type")
                    cost = st.number_input("Cost ($)", min_value=0, step=1000)
                
                with col2:
                    purchase_date = st.date_input("Purchase Date")
                    condition = st.selectbox("Condition", ["Good", "Fair", "Needs Repair"])
                    availability = st.selectbox("Availability", ["Available", "In Use", "Under Maintenance"])
                
                if st.form_submit_button("Add Equipment"):
                    if cost < 0:
                        st.error("❌ Trigger Validation: Cost cannot be negative")
                    else:
                        result = execute_query(
                            """INSERT INTO EQUIPMENT (name, type, cost, purchase_date, `condition`, availability)
                               VALUES (%s, %s, %s, %s, %s, %s)""",
                            (name, equip_type, cost, purchase_date, condition, availability)
                        )
                        if result and result.get("success"):
                            st.success("✓ Equipment added!")
    
    with tab3:
        st.subheader("Shooting Locations")
        locations = execute_query(
            """SELECT location_id, name, city, state, country, cost_per_day, area
               FROM SHOOTING_LOCATION
               ORDER BY country, city""",
            fetch=True
        )
        if locations:
            df = pd.DataFrame(locations)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No locations found")
    
    with tab4:
        st.subheader("Equipment Usage Report")
        films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
        if films:
            film = st.selectbox("Select Film", options=films, 
                               format_func=lambda x: x['title'], key="equipment_usage")
            if film:
                usage = call_procedure("sp_get_equipment_usage_report", [film['film_id']])
                if usage:
                    df = pd.DataFrame(usage)
                    st.dataframe(df, use_container_width=True, hide_index=True)
                else:
                    st.info("No equipment usage found")

# =====================
# ANALYTICS & REPORTS
# =====================
elif page == "Analytics & Reports":
    st.header("📊 Analytics & Reports")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Box Office Analysis", "Production Summary", "Awards", "Views"])
    
    with tab1:
        st.subheader("Box Office Analysis")
        boxoffice = call_procedure("sp_get_boxoffice_analysis")
        if boxoffice:
            df = pd.DataFrame(boxoffice)
            df['budget'] = pd.to_numeric(df['budget'], errors='coerce')
            df['boxoffice_collection'] = pd.to_numeric(df['boxoffice_collection'], errors='coerce')
            df['roi_percentage'] = pd.to_numeric(df['roi_percentage'], errors='coerce')
            df['profit'] = pd.to_numeric(df['profit'], errors='coerce')
            
            st.dataframe(df, use_container_width=True, hide_index=True)
            
            col1, col2 = st.columns(2)
            with col1:
                fig = px.scatter(df, x='budget', y='boxoffice_collection',
                               size='roi_percentage', hover_data=['title'],
                               title="Budget vs Box Office")
                st.plotly_chart(fig, use_container_width=True)
            with col2:
                fig = px.bar(df, x='title', y='roi_percentage', 
                           title="ROI Percentage by Film",
                           color='roi_percentage',
                           color_continuous_scale='Viridis')
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No box office data found")
    
    with tab2:
        st.subheader("Production Summary")
        summary_data = execute_query(
            """SELECT 
                  f.film_id,
                  f.title,
                  f.production_status,
                  COUNT(DISTINCT r.actor_id) as actors,
                  COUNT(DISTINCT s.scene_id) as scenes,
                  COUNT(DISTINCT wo.crew_id) as crew,
                  COUNT(DISTINCT sa.location_id) as locations
               FROM FILM f
               LEFT JOIN ROLE r ON f.film_id = r.film_id
               LEFT JOIN SCENE s ON f.film_id = s.film_id
               LEFT JOIN WORKS_ON wo ON f.film_id = wo.film_id
               LEFT JOIN SHOT_AT sa ON f.film_id = sa.film_id
               GROUP BY f.film_id, f.title, f.production_status""",
            fetch=True
        )
        if summary_data:
            df = pd.DataFrame(summary_data)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No production data found")
    
    with tab3:
        st.subheader("Awards Summary")
        col1, col2, col3 = st.columns(3)
        
        actor_awards = execute_query("SELECT COUNT(*) as count FROM ACTOR_AWARD", fetch=True)
        director_awards = execute_query("SELECT COUNT(*) as count FROM DIRECTOR_AWARD", fetch=True)
        crew_awards = execute_query("SELECT COUNT(*) as count FROM CREW_AWARD", fetch=True)
        
        with col1:
            st.metric("🎬 Actor Awards", actor_awards[0]['count'] if actor_awards else 0)
        with col2:
            st.metric("🎥 Director Awards", director_awards[0]['count'] if director_awards else 0)
        with col3:
            st.metric("👷 Crew Awards", crew_awards[0]['count'] if crew_awards else 0)
        
        st.divider()
        
        st.subheader("Recent Awards")
        awards = execute_query(
            """(SELECT 'Actor' as type, a.first_name as name, aa.award_name, aa.award_year 
               FROM ACTOR_AWARD aa JOIN ACTOR a ON aa.actor_id = a.actor_id)
            UNION
            (SELECT 'Director', d.name, da.award_name, da.award_year 
             FROM DIRECTOR_AWARD da JOIN DIRECTOR d ON da.director_id = d.director_id)
            UNION
            (SELECT 'Crew', c.name, ca.award_name, ca.award_year 
             FROM CREW_AWARD ca JOIN CREW c ON ca.crew_id = c.crew_id)
            ORDER BY award_year DESC""",
            fetch=True
        )
        if awards:
            df = pd.DataFrame(awards)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No awards found")
    
    with tab4:
        st.subheader("Database Views")
        
        view_options = {
            "Film Basic Info": "SELECT * FROM view_film_basic LIMIT 10",
            "Film Profitability": "SELECT * FROM view_film_profitability",
            "Actor Details": "SELECT * FROM view_actor_details LIMIT 10",
            "Director Filmography": "SELECT * FROM view_director_filmography",
            "Producer Investment": "SELECT * FROM view_producer_investment",
            "Crew by Department": "SELECT * FROM view_crew_by_department",
            "Equipment Status": "SELECT * FROM view_equipment_status LIMIT 10",
            "Scene Filming Summary": "SELECT * FROM view_scene_filming_summary"
        }
        
        view_name = st.selectbox("Select View", options=list(view_options.keys()))
        if view_name:
            view_data = execute_query(view_options[view_name], fetch=True)
            if view_data:
                df = pd.DataFrame(view_data)
                st.dataframe(df, use_container_width=True, hide_index=True)
            else:
                st.info(f"No data in {view_name}")

# =====================
# AUDIT & LOGS
# =====================
elif page == "Audit & Logs":
    if st.session_state.user_role != 'admin':
        st.error("🚫 Access Denied: This page is only accessible to administrators")
        st.stop()
    
    st.header("📋 Audit & Activity Logs")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Role Audit", "Equipment Audit", "Film Audit", "User Activity"])
    
    with tab1:
        st.subheader("Role Audit Log")
        role_audit = execute_query(
            """SELECT audit_id, actor_id, film_id, character_name, salary, action, timestamp
               FROM ROLE_AUDIT
               ORDER BY timestamp DESC LIMIT 50""",
            fetch=True
        )
        if role_audit:
            df = pd.DataFrame(role_audit)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No role audit records found")
    
    with tab2:
        st.subheader("Equipment Audit Log")
        equipment_audit = execute_query(
            """SELECT audit_id, equipment_id, equipment_name, old_availability, 
                      new_availability, action, timestamp
               FROM EQUIPMENT_AUDIT
               ORDER BY timestamp DESC LIMIT 50""",
            fetch=True
        )
        if equipment_audit:
            df = pd.DataFrame(equipment_audit)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No equipment audit records found")
    
    with tab3:
        st.subheader("Film Audit Log")
        film_audit = execute_query(
            """SELECT audit_id, film_id, film_title, old_status, new_status,
                      old_budget, new_budget, action, timestamp
               FROM FILM_AUDIT
               ORDER BY timestamp DESC LIMIT 50""",
            fetch=True
        )
        if film_audit:
            df = pd.DataFrame(film_audit)
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No film audit records found")
    
    with tab4:
        st.subheader("User Activity Log")
        user_activity = execute_query(
            """SELECT al.log_id, u.username, u.full_name, al.action_type, 
                      al.action_description, al.timestamp
               FROM USER_ACTIVITY_LOG al
               JOIN DB_USERS u ON al.user_id = u.user_id
               ORDER BY al.timestamp DESC LIMIT 100""",
            fetch=True
        )
        if user_activity:
            df = pd.DataFrame(user_activity)
            df['timestamp'] = pd.to_datetime(df['timestamp']).dt.strftime('%Y-%m-%d %H:%M:%S')
            st.dataframe(df, use_container_width=True, hide_index=True)
        else:
            st.info("No user activity found")

# =====================
# DATABASE OPERATIONS
# =====================
elif page == "Database Operations":
    st.header("⚙️ Database Operations & Functions")
    
    tab1, tab2, tab3, tab4 = st.tabs(["Functions Demo", "Status Update", "Add Location", "Test Triggers"])
    
    with tab1:
        st.subheader("Database Functions Demo")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.markdown("### 🎂 Actor Age Calculator")
            actors = execute_query(
                "SELECT actor_id, CONCAT(first_name, ' ', last_name) as name FROM ACTOR",
                fetch=True
            )
            if actors:
                actor = st.selectbox("Select Actor", options=actors, 
                                    format_func=lambda x: x['name'], key="age_calc")
                if actor:
                    age = execute_query(
                        f"SELECT fn_get_actor_age({actor['actor_id']}) as age",
                        fetch=True
                    )
                    if age:
                        st.metric("Age", f"{age[0]['age']} years")
        
        with col2:
            st.markdown("### 🎬 Director Film Count")
            directors = execute_query(
                "SELECT director_id, name FROM DIRECTOR",
                fetch=True
            )
            if directors:
                director = st.selectbox("Select Director", options=directors, 
                                       format_func=lambda x: x['name'], key="film_count")
                if director:
                    count = execute_query(
                        f"SELECT fn_director_film_count({director['director_id']}) as count",
                        fetch=True
                    )
                    if count:
                        st.metric("Films Directed", count[0]['count'])
        
        with col3:
            st.markdown("### 💰 Film Profit Calculator")
            films = execute_query(
                "SELECT film_id, title FROM FILM WHERE boxoffice_collection > 0",
                fetch=True
            )
            if films:
                film = st.selectbox("Select Film", options=films, 
                                   format_func=lambda x: x['title'], key="profit_calc")
                if film:
                    profit = execute_query(
                        f"SELECT fn_calculate_film_profit({film['film_id']}) as profit",
                        fetch=True
                    )
                    if profit:
                        profit_val = profit[0]['profit']
                        st.metric("Profit/Loss", f"${profit_val:,.0f}")
        
        st.divider()
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("### ⚙️ Equipment Availability Check")
            equipment = execute_query("SELECT equipment_id, name FROM EQUIPMENT", fetch=True)
            if equipment:
                equip = st.selectbox("Select Equipment", options=equipment, 
                                    format_func=lambda x: x['name'], key="equip_avail")
                if equip:
                    avail = execute_query(
                        f"SELECT fn_equipment_available({equip['equipment_id']}) as availability",
                        fetch=True
                    )
                    if avail:
                        status = avail[0]['availability']
                        status_color = "🟢" if status == "Available" else "🔴" if status == "In Use" else "🟡"
                        st.metric("Status", f"{status_color} {status}")
        
        with col2:
            st.markdown("### 📈 Film ROI Calculator")
            films = execute_query(
                "SELECT film_id, title FROM FILM WHERE boxoffice_collection > 0",
                fetch=True
            )
            if films:
                film = st.selectbox("Select Film for ROI", options=films, 
                                   format_func=lambda x: x['title'], key="roi_calc")
                if film:
                    roi = execute_query(
                        f"SELECT fn_calculate_film_roi({film['film_id']}) as roi",
                        fetch=True
                    )
                    if roi:
                        roi_val = roi[0]['roi']
                        st.metric("ROI %", f"{roi_val:.2f}%")
    
    with tab2:
        st.subheader("Update Film Production Status")
        
        if not check_permission('update'):
            st.warning("🚫 You don't have permission to update film status")
        else:
            films = execute_query("SELECT film_id, title, production_status FROM FILM", fetch=True)
            if films:
                film = st.selectbox("Select Film", options=films, 
                                   format_func=lambda x: f"{x['title']} ({x['production_status']})")
                if film:
                    new_status = st.selectbox("New Status", 
                        ["Pre-Production", "In Progress", "Post-Production", "Released"])
                    
                    if st.button("Update Status"):
                        result = call_procedure("sp_update_film_status", 
                                              [film['film_id'], new_status])
                        if result:
                            st.success(f"✓ Status updated to '{new_status}'")
                            st.rerun()
    
    with tab3:
        st.subheader("Add Shooting Location with Cost Calculation")
        
        if not check_permission('create'):
            st.warning("🚫 You don't have permission to add locations")
        else:
            with st.form("add_location"):
                col1, col2 = st.columns(2)
                
                with col1:
                    films = execute_query("SELECT film_id, title FROM FILM", fetch=True)
                    if films:
                        film = st.selectbox("Select Film", options=films, 
                                           format_func=lambda x: x['title'])
                        film_id = film['film_id']
                    else:
                        st.error("No films available")
                        film_id = 1
                    
                    location_name = st.text_input("Location Name")
                    city = st.text_input("City")
                
                with col2:
                    country = st.text_input("Country", "USA")
                    cost_per_day = st.number_input("Cost per Day ($)", min_value=0, step=100)
                    shooting_start = st.date_input("Shooting Start Date")
                
                shooting_end = st.date_input("Shooting End Date", 
                                            value=shooting_start + timedelta(days=7))
                
                if st.form_submit_button("Add Location & Calculate Cost"):
                    if cost_per_day < 0:
                        st.error("❌ Trigger Validation: Cost cannot be negative")
                    else:
                        try:
                            result = execute_query(
                                """INSERT INTO SHOOTING_LOCATION (name, city, country, cost_per_day)
                                   VALUES (%s, %s, %s, %s)""",
                                (location_name, city, country, cost_per_day)
                            )
                            if result and result.get("success"):
                                location = execute_query(
                                    "SELECT location_id FROM SHOOTING_LOCATION ORDER BY location_id DESC LIMIT 1",
                                    fetch=True
                                )
                                if location:
                                    total_days = (shooting_end - shooting_start).days + 1
                                    total_cost = total_days * cost_per_day
                                    execute_query(
                                        """INSERT INTO SHOT_AT (film_id, location_id, shooting_start, shooting_end, total_cost)
                                           VALUES (%s, %s, %s, %s, %s)""",
                                        (film_id, location[0]['location_id'], shooting_start, shooting_end, total_cost)
                                    )
                                    st.success("✓ Location added!")
                                    col1, col2, col3 = st.columns(3)
                                    with col1:
                                        st.metric("Location ID", location[0]['location_id'])
                                    with col2:
                                        st.metric("Days", total_days)
                                    with col3:
                                        st.metric("Total Cost", f"${total_cost:,.0f}")
                        except Exception as e:
                            st.error(f"Error: {str(e)}")
    
    with tab4:
        st.subheader("Test Database Triggers")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### Test: Budget Validation Trigger")
            st.info("Minimum film budget is $100,000")
            
            test_budget = st.number_input("Test Budget ($)", min_value=0, step=1000, key="test_budget")
            if test_budget < 100000:
                st.error(f"❌ TRIGGER BLOCKED: Budget ${test_budget:,.0f} is below minimum")
            else:
                st.success(f"✓ Budget ${test_budget:,.0f} is valid")
        
        with col2:
            st.markdown("#### Test: Actor Age Validation Trigger")
            st.info("Actors must be at least 18 years old")
            
            test_dob = st.date_input("Test Date of Birth", key="test_dob")
            test_age = datetime.now().year - test_dob.year
            if test_age < 18:
                st.error(f"❌ TRIGGER BLOCKED: Age {test_age} is below minimum")
            else:
                st.success(f"✓ Age {test_age} is valid")
        
        st.divider()
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### Test: Equipment Cost Validation")
            test_cost = st.number_input("Test Equipment Cost ($)", min_value=-1000, step=100, key="test_equip_cost")
            if test_cost < 0:
                st.error(f"❌ TRIGGER BLOCKED: Negative cost not allowed")
            else:
                st.success(f"✓ Cost ${test_cost:,.0f} is valid")
        
        with col2:
            st.markdown("#### Test: Location Cost Validation")
            test_loc_cost = st.number_input("Test Location Cost per Day ($)", 
                                           min_value=-1000, step=100, key="test_loc_cost")
            if test_loc_cost < 0:
                st.error(f"❌ TRIGGER BLOCKED: Negative cost not allowed")
            else:
                st.success(f"✓ Cost ${test_loc_cost:,.0f} per day is valid")