window.addEventListener("load", () => {
  const rows = performance.getEntriesByType("resource").map((entry) => ({
    name: entry.name.split("/").slice(-2).join("/"),
    transferSize: entry.transferSize,
    duration: Math.round(entry.duration)
  }));
  document.getElementById("metrics").textContent = JSON.stringify(rows, null, 2);
});
