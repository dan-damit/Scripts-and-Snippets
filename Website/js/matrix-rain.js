// Matrix Rain Characters
const latinChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*()-_=+[]{}|;:',.<>?/`~¡™£¢∞§¶•ªº–≠œ∑´®†¥¨ˆøπ“‘åß∂ƒ©˙∆˚¬Ω≈ç√∫˜µ≤≥÷";
const japaneseChars = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへみむめもよらりるれろわをん一二三四五六七八";
const matrixChars = latinChars + japaneseChars;
const characters = matrixChars.split("");

// Utility: resize canvas on window resize
function resizeMatrixCanvas() {
    const canvases = document.querySelectorAll('#matrixCanvasMain');
    const height = document.body.scrollHeight;
    const width = window.innerWidth;

    canvases.forEach(canvas => {
        canvas.width = width;
        canvas.height = height;
    });

    console.log(`[CanvasResize] width=${width}, height=${height}`);
}

// Matrix Rain Animation
function matrixRain(canvasId, { speedFactor = 0.9, color = "#0F0", opacity = 0.05, fontSize = 16, delayFactor = 2 }) {
    const canvas = document.getElementById(canvasId);
    const ctx = canvas.getContext("2d");

    // Set initial canvas size
    resizeMatrixCanvas(canvas);

    let frameCount = 0;
    const columns = Math.floor(canvas.width / fontSize);
    const drops = new Array(columns).fill(0);
    const delays = new Array(columns).fill(0); // Delay timers for each column
    const skipRates = new Array(columns).fill().map(() => Math.random() * 0.3 + 0.6); // Skip rates for glyph drawing
    const fontSizes = new Array(columns).fill().map(() => Math.floor(Math.random() * 4 + fontSize)); // fontSize to fontSize+4

    const drawMatrix = () => {
        frameCount++;
        if (frameCount % 2 !== 0) {
            requestAnimationFrame(drawMatrix);
            return;
        }

        // Clear the canvas with a trailing effect
        ctx.fillStyle = `rgba(0, 0, 0, ${opacity})`;
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Set text style
        ctx.fillStyle = color;
        ctx.font = `${fontSize}px monospace`;

        for (let i = 0; i < drops.length; i++) {
            if (Math.random() > skipRates[i]) continue;

            const text = characters[Math.floor(Math.random() * characters.length)];
            const x = i * fontSizes[i];
            const y = drops[i] * fontSizes[i];
            ctx.font = `${fontSizes[i]}px monospace`;

            const blurAmount = Math.random() > 0.85 ? Math.floor(Math.random() * 3 + 1) : 0;
            ctx.filter = blurAmount ? `blur(${blurAmount}px)` : "none";

            ctx.fillText(text, x, y);
            ctx.filter = "none";

            if (delays[i] <= 0) {
                drops[i] += 1;
                delays[i] = Math.random() * (delayFactor / speedFactor);
            } else {
                delays[i] -= 1;
            }

            if (y > canvas.height && Math.random() > 0.975) {
                drops[i] = 0;
            }
        }

        requestAnimationFrame(drawMatrix);
    };

    drawMatrix();
    return canvas;
}

// Start animations
matrixRain("matrixCanvasMain", {
    speedFactor: 0.8,
    fontSize: 18,
    delayFactor: 3,
    color: "#0F0",
    opacity: 0.075
});

// Initial resize and debounced resize on window resize
let resizeTimeout;
window.addEventListener('resize', () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(resizeMatrixCanvas, 100);
});

window.addEventListener('load', resizeMatrixCanvas);