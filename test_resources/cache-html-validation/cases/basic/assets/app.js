(function () {
  const mark = (id, text) => {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = text;
    element.classList.add("pass");
  };

  document.documentElement.dataset.wbkJs = "loaded";
  mark("js-check", "JavaScript loaded");

  window.addEventListener("load", () => {
    const image = document.querySelector("img.badge");
    const cssLoaded = getComputedStyle(document.body).fontFamily.includes("SF Pro");
    if (cssLoaded) mark("css-check", "Stylesheet loaded");
    if (image && image.complete && image.naturalWidth > 0) mark("image-check", "Image loaded");
  });
})();
