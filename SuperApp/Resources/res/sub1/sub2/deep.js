console.log("Deep Resource Loaded");
document.addEventListener("DOMContentLoaded", function() {
    var status = document.getElementById("status");
    if (status) {
        status.innerText = "✅ 深度目录 JS 加载成功! (res/sub1/sub2/deep.js)";
        status.style.color = "#0ea5e9";
    }
});