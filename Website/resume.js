document.addEventListener('DOMContentLoaded', () => {
    const pdfButtons = document.querySelectorAll('.pdf-btn');

    pdfButtons.forEach((btn) => {
        const id = btn.id;

        if (id === 'print-pdf') {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                console.log("> Printing Resume Artifact...");
                window.print();
            });
        }

        if (id === 'download-pdf') {
            btn.addEventListener('click', async () => {
                console.log("> Deploying Resume Artifact...");
                await generateResumePDF();
            });
        }
    });
});

export async function generateResumePDF() {
    const { jsPDF } = window.jspdf;
    const resume = document.getElementById('content');
    const qr = document.getElementById('qr-img');

    // Ensure QR image is loaded
    if (!qr.complete) {
        await new Promise(resolve => qr.onload = resolve);
    }

    // Render resume content
    const canvas = await html2canvas(resume, {
        scale: 2,
        useCORS: true
    });

    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'px',
        format: [canvas.width, canvas.height + 140] // extra space for QR + caption
    });

    pdf.addImage(imgData, 'PNG', 0, 0, canvas.width, canvas.height);

    // Render QR code
    const qrCanvas = await html2canvas(qr, {
        scale: 2,
        useCORS: true
    });

    pdf.save('Dan_Damit_Resume.pdf');
}