const URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const loginBox=document.getElementById("loginBox");
const registerBox=document.getElementById("registerBox");
const message=document.getElementById("message");

document.getElementById("showRegister").onclick=()=>{
  loginBox.classList.add("hidden");
  registerBox.classList.remove("hidden");
  message.textContent="";
};

document.getElementById("showLogin").onclick=()=>{
  registerBox.classList.add("hidden");
  loginBox.classList.remove("hidden");
  message.textContent="";
};

document.getElementById("registerForm").onsubmit=async e=>{
  e.preventDefault();

  const name=document.getElementById("name").value.trim();
  const phone=document.getElementById("phone").value.trim();
  const email=document.getElementById("registerEmail").value.trim();
  const password=document.getElementById("registerPassword").value;
  const confirm=document.getElementById("confirmPassword").value;

  if(password!==confirm){
    message.textContent="Passwords do not match.";
    return;
  }

  message.textContent="Creating account...";

  const r=await fetch(URL+"/auth/v1/signup",{
    method:"POST",
    headers:{
      apikey:KEY,
      "Content-Type":"application/json"
    },
    body:JSON.stringify({
      email,
      password,
      data:{
        full_name:name,
        phone,
        role:"passenger"
      }
    })
  });

  const data=await r.json();

  if(!r.ok){
    message.textContent=
      data.msg||data.error_description||"Registration failed.";
    return;
  }

  if(data.session){
    await fetch(URL+"/rest/v1/profiles",{
      method:"POST",
      headers:{
        apikey:KEY,
        Authorization:"Bearer "+data.session.access_token,
        "Content-Type":"application/json"
      },
      body:JSON.stringify({
        id:data.user.id,
        full_name:name,
        phone,
        role:"passenger"
      })
    });
  }

  message.textContent=
    "Account created. Please wait for verification before login.";

  document.getElementById("registerForm").reset();
};

document.getElementById("loginForm").onsubmit=async e=>{
  e.preventDefault();

  const email=document.getElementById("loginEmail").value.trim();
  const password=document.getElementById("loginPassword").value;

  message.textContent="Logging in...";

  const r=await fetch(
    URL+"/auth/v1/token?grant_type=password",
    {
      method:"POST",
      headers:{
        apikey:KEY,
        "Content-Type":"application/json"
      },
      body:JSON.stringify({email,password})
    }
  );

  const data=await r.json();

  if(!r.ok){
    message.textContent=
      data.error_description||"Login failed.";
    return;
  }

  const p=await fetch(
    URL+"/rest/v1/profiles?id=eq."+data.user.id+
    "&select=is_verified,role",
    {
      headers:{
        apikey:KEY,
        Authorization:"Bearer "+data.access_token
      }
    }
  );

  const profile=await p.json();

  if(!profile.length||profile[0].role!=="passenger"){
    message.textContent="Passenger account not found.";
    return;
  }

  if(profile[0].is_verified!==true){
    message.textContent="Your account is waiting for verification.";
    return;
  }

  localStorage.setItem("rydo_token",data.access_token);
  localStorage.setItem("rydo_user",data.user.id);

  message.textContent="Login successful.";
};
