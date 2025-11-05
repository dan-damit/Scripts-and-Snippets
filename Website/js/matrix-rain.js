const canvas = document.getElementById('matrixCanvasMain');
const ctx = canvas.getContext('2d');

// Set canvas full screen
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const letters = 'アァイィウヴエェオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモヤユヨラリルレロワヲンABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const fontSize = 16;
const columns = Math.floor(canvas.width / fontSize);

// Array for drops (y positions for each column)
const drops = Array.from({ length: columns }, () => 1);

function draw() {
    // Semi-transparent background for trail effect
    ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.font = `${fontSize}px monospace`;
    ctx.fillStyle = '#0F0'; // matrix green

    // Draw each letter
    for (let i = 0; i < drops.length; i++) {
        const text = letters[Math.floor(Math.random() * letters.length)];
        ctx.fillText(text, i * fontSize, drops[i] * fontSize);

        // Randomly reset drop
        if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
            drops[i] = 0;
        }
        drops[i]++;
    }
}

// Optional: Adjust on resize
function resizeCanvasAndDrops() {
    canvas.width = window.innerWidth;
    canvas.height = Math.min(window.innerHeight, document.body.scrollHeight);

    const newColumns = Math.floor(canvas.width / fontSize);
    const newDrops = new Array(newColumns).fill(1);
    for (let i = 0; i < Math.min(drops.length, newColumns); i++) {
        newDrops[i] = drops[i];
    }

    drops.length = 0;
    drops.push(...newDrops);
}

// Debounce resize events
let resizeTimeout;
window.addEventListener('resize', () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(resizeCanvasAndDrops, 100);
});

// Start the animation
window.addEventListener('load', resizeCanvasAndDrops);
setInterval(draw, 50);