importScripts("https://www.gstatic.com/firebasejs/10.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "",
  authDomain: "mha1-9eca0.firebaseapp.com",
  projectId: "mha1-9eca0",
  storageBucket: "mha1-9eca0.firebasestorage.app",
  messagingSenderId: "890170915182",
  appId: "1:890170915182:android:0f4932275c4850134e297f"
});

const messaging = firebase.messaging();
