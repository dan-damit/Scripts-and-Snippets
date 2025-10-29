document.addEventListener("DOMContentLoaded", () => {
    const canvas = document.getElementById("matrix");
    const ctx = canvas.getContext("2d");

    // Initial setup
    canvas.height = window.innerHeight;
    canvas.width = window.innerWidth;

    // Glyphs: Katakana + Latin + numerals
    const letters = "アァイィウヴエェオカガキギクグケゲコゴサザシジスズセゼソゾタダチッヂツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモヤユヨラリルレロワヲンABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    // Fixed font and spacing
    const fontSize = 14;
    const lineHeight = fontSize * 1.15;
    const columnSpacing = fontSize * 2;

    ctx.font = `${fontSize}px monospace`;

    // Columns and drops
    let columns = Math.floor(canvas.width / columnSpacing);
    let drops = Array(columns).fill(1);

    // Fixed speed
    const speedFactor = 1;

    function draw() {
        // Fade trail
        ctx.fillStyle = "rgba(0, 0, 0, 0.15)";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Glyph style
        ctx.fillStyle = "#0F0";
        ctx.font = `${fontSize}px monospace`;

        for (let i = 0; i < drops.length; i++) {
            const text = letters.charAt(Math.floor(Math.random() * letters.length));
            ctx.fillText(text, i * columnSpacing, drops[i] * lineHeight);

            if (drops[i] * lineHeight > canvas.height && Math.random() > 0.975) {
                drops[i] = 0;
            }

            drops[i] += speedFactor;
        }
    }

    setInterval(draw, 33); // ~30 FPS

    // Resize handler: preserve fixed sizing
    window.addEventListener("resize", () => {
        canvas.height = window.innerHeight;
        canvas.width = window.innerWidth;

        columns = Math.floor(canvas.width / columnSpacing);
        drops = Array(columns).fill(1);
    });
});