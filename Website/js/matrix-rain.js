const canvas = document.getElementById("matrixCanvasMain");
class MatrixRain3D {
  constructor(canvasId, fontSize = 16) {
    this.canvas = document.getElementById(canvasId);
    this.ctx = this.canvas.getContext("2d");
    this.fontSize = fontSize;
    this.letters =
      "アァイィウヴエェオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモヤユヨラリルレロワヲン ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789";
    this.drops = [];
    this.depths = [];
    this.lastDraw = 0;

    this.resizeCanvasAndDrops();
    window.addEventListener("resize", () => this.debounceResize());
    window.addEventListener("load", () => this.resizeCanvasAndDrops());
    requestAnimationFrame((ts) => this.loop(ts));
  }

  resizeCanvasAndDrops() {
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = window.innerWidth * dpr;
    this.canvas.height = window.innerHeight * dpr;
    this.canvas.style.width = "100%";
    this.canvas.style.height = "100%";
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.scale(dpr, dpr);

    const columns = Math.floor(this.canvas.width / this.fontSize / dpr);
    this.drops = Array.from({ length: columns }, () => 1);
    this.depths = Array.from({ length: columns }, () => Math.random());
  }

  debounceResize() {
    clearTimeout(this.resizeTimeout);
    this.resizeTimeout = setTimeout(() => this.resizeCanvasAndDrops(), 100);
  }

  draw() {
    this.ctx.fillStyle = "rgba(0, 0, 0, 0.1)";
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    for (let i = 0; i < this.drops.length; i++) {
      const text =
        this.letters[Math.floor(Math.random() * this.letters.length)];
      const depth = this.depths[i];

      // Depth-based size and brightness
      const size = this.fontSize * (0.5 + depth * 1.5);
      this.ctx.font = `${size}px monospace`;
      const brightness = Math.floor(100 + depth * 155);
      this.ctx.fillStyle = `rgb(0, ${brightness}, 0)`;

      // Depth-based blur and parallax
      this.ctx.shadowColor = "transparent";
      this.ctx.shadowBlur = (1 - depth) * 8;
      const x = i * this.fontSize + depth * 10;

      this.ctx.fillText(text, x, this.drops[i] * size);

      if (this.drops[i] * size > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
      }
      this.drops[i]++;
    }
  }

  loop(timestamp) {
    if (timestamp - this.lastDraw > 50) {
      this.draw();
      this.lastDraw = timestamp;
    }
    requestAnimationFrame((ts) => this.loop(ts));
  }
}

// Usage:
const matrix3D = new MatrixRain3D("matrixCanvasMain");
