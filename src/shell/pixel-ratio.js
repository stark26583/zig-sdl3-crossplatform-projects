// hiDPI-pre.js
if (typeof window !== "undefined") {
    const ratio = window.devicePixelRatio || 1;
    const canvas = document.getElementById("canvas"); // Emscripten's canvas
    if (canvas) {
        canvas.width  = window.innerWidth * ratio;
        canvas.height = window.innerHeight * ratio;
        canvas.style.width  = window.innerWidth + "px";
        canvas.style.height = window.innerHeight + "px";
    }
}

