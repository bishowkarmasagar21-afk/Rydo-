const SUPABASE_URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const client=window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

window.supabaseClient=client;

const form=document.getElementById("adminLoginForm");
const button=document.getElementById("adminLoginBtn");
const msg=document.getElementById("adminMessage");

async function login(){

  const email=document.getElementById("adminEmail").value.trim();
  const password=document.getElementById("adminPassword").value;

  if(!email||!password){
    msg.textContent="Enter email and password.";
    return;
  }

  button.disabled=true;
  button.textContent="Checking...";

  const {data,error}=await client.auth.signInWithPassword({
    email:email,
    password:password
  });

  if(error){
    msg.textContent=error.message;
    button.disabled=false;
    button.textContent="Login";
    return;
  }

  const {data:profile,error:pError}=await client
    .from("profiles")
    .select("full_name,role")
    .eq("id",data.user.id)
    .single();

  if(pError||!profile){
    msg.textContent="Admin profile not found.";
    await client.auth.signOut();
    button.disabled=false;
    button.textContent="Login";
    return;
  }

  if(profile.role!=="admin"){
    msg.textContent="This account is not an admin.";
    await client.auth.signOut();
    button.disabled=false;
    button.textContent="Login";
    return;
  }

  document.getElementById("adminLogin").style.display="none";
  document.getElementById("adminApp").style.display="block";
}

form.addEventListener("submit",function(e){
  e.preventDefault();
  login();
});
