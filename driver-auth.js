/* RYDO DRIVER AUTH */

const SUPABASE_URL =
"https://kqtvuorasqyzjbnlkkxs.supabase.co";

const SUPABASE_KEY =
"sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const db = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);


/* ELEMENTS */

const authPage = document.getElementById("authPage");
const driverPage = document.getElementById("driverPage");

const loginTab = document.getElementById("loginTab");
const registerTab = document.getElementById("registerTab");

const loginBox = document.getElementById("loginBox");
const registerBox = document.getElementById("registerBox");

const loginEmail = document.getElementById("loginEmail");
const loginPassword = document.getElementById("loginPassword");
const loginBtn = document.getElementById("loginBtn");
const forgotBtn = document.getElementById("forgotBtn");

const regName = document.getElementById("regName");
const regEmail = document.getElementById("regEmail");
const regPhone = document.getElementById("regPhone");
const regPassword = document.getElementById("regPassword");

const licenseNumber = document.getElementById("licenseNumber");
const vehicleType = document.getElementById("vehicleType");
const vehicleNumber = document.getElementById("vehicleNumber");
const vehicleModel = document.getElementById("vehicleModel");

const licenseFile = document.getElementById("licenseFile");
const citizenshipFile = document.getElementById("citizenshipFile");
const bluebookFile = document.getElementById("bluebookFile");
const insuranceFile = document.getElementById("insuranceFile");
const vehiclePhoto = document.getElementById("vehiclePhoto");

const registerBtn = document.getElementById("registerBtn");
const message = document.getElementById("message");


/* MESSAGE */

function authMessage(text, type = "") {
  message.textContent = text;
  message.className = "message";

  if (type) message.classList.add(type);

  setTimeout(() => {
    message.classList.add("hidden");
  }, 5000);
}


/* TABS */

loginTab.onclick = () => {
  loginBox.classList.remove("hidden");
  registerBox.classList.add("hidden");

  loginTab.classList.add("active");
  registerTab.classList.remove("active");
};

registerTab.onclick = () => {
  registerBox.classList.remove("hidden");
  loginBox.classList.add("hidden");

  registerTab.classList.add("active");
  loginTab.classList.remove("active");
};


/* CHECK FILE */

function requiredFile(input, name) {
  if (!input.files.length) {
    authMessage(name + " is required.", "error");
    return false;
  }

  if (input.files[0].size > 10 * 1024 * 1024) {
    authMessage(name + " must be under 10 MB.", "error");
    return false;
  }

  return true;
}


/* REGISTER */

registerBtn.onclick = async () => {

  const name = regName.value.trim();
  const email = regEmail.value.trim();
  const phone = regPhone.value.trim();
  const password = regPassword.value;

  const license = licenseNumber.value.trim();
  const type = vehicleType.value;
  const vehicleNo = vehicleNumber.value.trim();
  const model = vehicleModel.value.trim();

  if (
    !name ||
    !email ||
    !phone ||
    !password ||
    !license ||
    !vehicleNo ||
    !model
  ) {
    authMessage(
      "Please complete all required fields.",
      "error"
    );
    return;
  }

  if (password.length < 6) {
    authMessage(
      "Password must be at least 6 characters.",
      "error"
    );
    return;
  }

  if (!requiredFile(licenseFile, "Driver License")) return;
  if (!requiredFile(citizenshipFile, "Citizenship / ID")) return;
  if (!requiredFile(bluebookFile, "Vehicle Registration")) return;
  if (!requiredFile(insuranceFile, "Vehicle Insurance")) return;
  if (!requiredFile(vehiclePhoto, "Vehicle Photo")) return;

  registerBtn.disabled = true;
  registerBtn.textContent = "Creating account...";

  try {

    const { data, error } = await db.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: name,
          phone,
          role: "driver",
          driver_license: license
        }
      }
    });

    if (error) throw error;

    if (!data.user) {
      throw new Error("Registration failed.");
    }

    const userId = data.user.id;

    /* PROFILE */

    const { error: profileError } =
      await db.from("profiles").upsert({
        id: userId,
        full_name: name,
        phone: phone,
        role: "driver",
        driver_license: license,
        is_online: false,
        is_verified: false
      });

    if (profileError) throw profileError;


    /* VEHICLE */

    const { error: vehicleError } =
      await db.from("vehicles").insert({
        driver_id: userId,
        vehicle_type: type,
        vehicle_number: vehicleNo,
        model: model
      });

    if (vehicleError) throw vehicleError;


    /* DOCUMENT UPLOADS */

    await uploadDoc(
      licenseFile,
      userId,
      "license"
    );

    await uploadDoc(
      citizenshipFile,
      userId,
      "citizenship"
    );

    await uploadDoc(
      bluebookFile,
      userId,
      "bluebook"
    );

    await uploadDoc(
      insuranceFile,
      userId,
      "insurance"
    );

    await uploadDoc(
      vehiclePhoto,
      userId,
      "vehicle-photo"
    );


    authMessage(
      "Registration submitted. Wait for RYDO admin verification.",
      "success"
    );

    loginEmail.value = email;

    loginBox.classList.remove("hidden");
    registerBox.classList.add("hidden");

    loginTab.classList.add("active");
    registerTab.classList.remove("active");

  } catch (err) {

    console.error(err);

    authMessage(
      err.message || "Registration failed.",
      "error"
    );

  } finally {

    registerBtn.disabled = false;
    registerBtn.textContent =
      "Submit Registration";
  }
};


/* UPLOAD DOCUMENT */

async function uploadDoc(input, userId, folder) {

  const file = input.files[0];

  const ext =
    file.name.includes(".")
      ? "." + file.name.split(".").pop()
      : "";

  const path =
    userId +
    "/" +
    folder +
    "/" +
    Date.now() +
    ext;

  const { error } =
    await db.storage
      .from("driver-documents")
      .upload(path, file);

  if (error) throw error;

  return path;
}


/* LOGIN */

loginBtn.onclick = async () => {

  const email = loginEmail.value.trim();
  const password = loginPassword.value;

  if (!email || !password) {
    authMessage(
      "Enter email and password.",
      "error"
    );
    return;
  }

  loginBtn.disabled = true;
  loginBtn.textContent = "Logging in...";

  try {

    const { data, error } =
      await db.auth.signInWithPassword({
        email,
        password
      });

    if (error) throw error;

    if (!data.user) {
      throw new Error("Login failed.");
    }

    const { data: profile, error: pError } =
      await db
        .from("profiles")
        .select("*")
        .eq("id", data.user.id)
        .single();

    if (pError) throw pError;

    if (profile.role !== "driver") {
      await db.auth.signOut();
      throw new Error(
        "This account is not a driver account."
      );
    }

    if (profile.is_verified !== true) {
      await db.auth.signOut();
      throw new Error(
        "Your driver account is not verified by RYDO admin yet."
      );
    }

    window.currentUser = data.user;
    window.currentDriver = profile;

    authPage.classList.add("hidden");
    driverPage.classList.remove("hidden");

    if (typeof window.startDriverApp === "function") {
      window.startDriverApp();
    }

  } catch (err) {

    console.error(err);

    authMessage(
      err.message || "Login failed.",
      "error"
    );

  } finally {

    loginBtn.disabled = false;
    loginBtn.textContent = "Login";
  }
};


/* FORGOT PASSWORD */

forgotBtn.onclick = async () => {

  const email = loginEmail.value.trim();

  if (!email) {
    authMessage(
      "Enter your email first.",
      "error"
    );
    return;
  }

  try {

    const { error } =
      await db.auth.resetPasswordForEmail(
        email,
        {
          redirectTo:
            window.location.origin +
            window.location.pathname
        }
      );

    if (error) throw error;

    authMessage(
      "Password reset email sent.",
      "success"
    );

  } catch (err) {

    authMessage(
      err.message ||
      "Could not send reset email.",
      "error"
    );
  }
};


/* EXISTING SESSION */

async function checkDriverSession() {

  const { data } =
    await db.auth.getSession();

  if (!data.session) return;

  const user = data.session.user;

  const { data: profile, error } =
    await db
      .from("profiles")
      .select("*")
      .eq("id", user.id)
      .single();

  if (error || !profile) return;

  if (
    profile.role !== "driver" ||
    profile.is_verified !== true
  ) {
    await db.auth.signOut();
    return;
  }

  window.currentUser = user;
  window.currentDriver = profile;

  authPage.classList.add("hidden");
  driverPage.classList.remove("hidden");

  if (typeof window.startDriverApp === "function") {
    window.startDriverApp();
  }
}


/* PASSWORD RECOVERY */

db.auth.onAuthStateChange(
  async (event, session) => {

    if (
      event === "PASSWORD_RECOVERY" &&
      session
    ) {

      const password =
        prompt("Enter your new password:");

      if (!password || password.length < 6) {
        authMessage(
          "Password must be at least 6 characters.",
          "error"
        );
        return;
      }

      const { error } =
        await db.auth.updateUser({
          password
        });

      if (error) {
        authMessage(
          error.message,
          "error"
        );
      } else {
        authMessage(
          "Password changed successfully.",
          "success"
        );
      }
    }
  }
);


/* START */

checkDriverSession();
