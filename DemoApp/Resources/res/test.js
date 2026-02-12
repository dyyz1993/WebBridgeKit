console.log("V2 Test JS Loaded");
window.V2_SIGNAL = true;
document.addEventListener("DOMContentLoaded", function() {
    var status = document.getElementById("status");
    if (status) {
        status.innerText = "✅ JS 加载成功! (V2 - External)";
        status.style.color = "#f97316";
    }
});