class MatrixRain3D {
  constructor(canvasId, fontSize = 16) {
    this.canvas = document.getElementById(canvasId);
    this.ctx = this.canvas.getContext("2d");
    this.fontSize = fontSize;
    this.glyphs =
      "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん一二三四五六七八九十零!@#$%^&*()-_=+[]{}|;:',.<>?/`~ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    this.drops = [];
    this.depths = [];
    this.lastDraw = 0;

    // Overlay settings
    this.overlayColor = "rgba(255, 255, 255, 0.8)";
    this.overlayFontSize = 24;
    this.overlayBlinkSpeed = 400;

    // Resize handling
    this.resizeCanvasAndDrops();
    window.addEventListener("load", () => this.resizeCanvasAndDrops());
    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => this.resizeCanvasAndDrops(), 100);
    });

    // Start both loops
    requestAnimationFrame((ts) => this.loop(ts));
    this.drawOverlay();
  }

  // Resize canvas and recalc drops
  resizeCanvasAndDrops() {
    // Account for device pixel ratio
    const dpr = window.devicePixelRatio || 1;

    // Set canvas size in physical pixels
    this.canvas.width = window.innerWidth * dpr;
    this.canvas.height = window.innerHeight * dpr;

    // Scale back down so drawing uses CSS pixel coordinates
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.scale(dpr, dpr);

    // Calculate new column count based on CSS pixels
    const newColumns = Math.floor(window.innerWidth / this.fontSize);

    // Preserve existing drops/depths where possible
    const newDrops = new Array(newColumns).fill(1);
    const newDepths = new Array(newColumns).fill(0);

    for (let i = 0; i < Math.min(this.drops.length, newColumns); i++) {
      newDrops[i] = this.drops[i];
      newDepths[i] = this.depths[i];
    }

    this.drops = newDrops;
    this.depths = newDepths.map((d) => d || Math.random());
  }
  
  // Matrix Rain draw
  draw() {
    this.ctx.fillStyle = "rgba(0, 0, 0, 0.085)";
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    for (let i = 0; i < this.drops.length; i++) {
      const text = this.glyphs[Math.floor(Math.random() * this.glyphs.length)];

      // Hybrid depth logic
      // 1. Drift slightly each frame
      this.depths[i] += (Math.random() - 0.5) * 0.02;
      this.depths[i] = Math.max(0, Math.min(1, this.depths[i])); // clamp 0–1
      const depth = this.depths[i];

      // 2. Use depth for size/brightness
      const size = this.fontSize * (0.5 + depth * 1.5);
      this.ctx.font = `${size}px monospace`;
      const brightness = Math.floor(100 + depth * 155);
      this.ctx.fillStyle = `rgb(0, ${brightness}, 0)`;

      this.ctx.shadowColor = "transparent";
      this.ctx.shadowBlur = (1 - depth) * 8;
      const x = i * this.fontSize + depth * 10;

      this.ctx.fillText(text, x, this.drops[i] * size);

      // Reset drop to top randomly after it goes off screen
      if (this.drops[i] * size > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
        this.depths[i] = Math.random(); // 🔄 new depth only on reset
      }
      this.drops[i]++;
    }
  }

  // Overlay draw
  drawOverlay() {
    this.ctx.fillStyle = this.overlayColor;
    this.ctx.font = `${this.overlayFontSize}px monospace`;

    for (let i = 0; i < 10; i++) {
      const text = this.glyphs[Math.floor(Math.random() * this.glyphs.length)];
      const x = Math.random() * this.canvas.width;
      const y = Math.random() * this.canvas.height;
      this.ctx.fillText(text, x, y);
    }

    setTimeout(
      () => requestAnimationFrame(() => this.drawOverlay()),
      this.overlayBlinkSpeed
    );
  }

  // Rain loop
  loop(timestamp) {
    if (timestamp - this.lastDraw > 60) {
      this.draw();
      this.lastDraw = timestamp;
    }
    requestAnimationFrame((ts) => this.loop(ts));
  }
}

// Usage
const matrix3D = new MatrixRain3D("matrixCanvasMain");
