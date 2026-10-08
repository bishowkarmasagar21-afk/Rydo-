const SUPABASE_URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const db=window.supabase.createClient(
SUPABASE_URL,SUPABASE_KEY
);

let adminUser=null;

const $=id=>document.getElementById(id);

$("loginBtn").onclick=async()=>{
const email=$("email").value.trim();
const password=$("password").value;

if(!email||!password){
$("loginMsg").textContent="Enter email and password.";
return;
}

const {data,error}=await db.auth.signInWithPassword({
email,password
});

if(error){
$("loginMsg").textContent=error.message;
return;
}

const {data:p,error:pe}=await db
.from("profiles")
.select("id,full_name,role")
.eq("id",data.user.id)
.maybeSingle();

if(pe||!p||p.role!=="admin"){
$("loginMsg").textContent="Admin access denied.";
await db.auth.signOut();
return;
}

adminUser=data.user;
window.adminUser=adminUser;

$("loginPage").classList.add("hide");
$("adminPage").classList.remove("hide");
$("logoutBtn").classList.remove("hide");

$("adminName").textContent=p.full_name||"RYDO Administrator";

if(window.loadAdminDashboard)
loadAdminDashboard();
};

$("logoutBtn").onclick=async()=>{
await db.auth.signOut();
location.reload();
};
